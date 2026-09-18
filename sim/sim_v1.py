"""Monte Carlo de Stratecorum. Supuestos donde el manual es ambiguo:
- Corazones y picas: 2-10, J=11, Q=12, K=13, A=14. Tréboles/diamantes: figuras = 10.
- El corazón que va al mazo se elige al azar. Se roba al inicio del turno.
- El daño se acumula sobre una vida solo dentro del mismo turno.
- Pagar de más se pierde (sin cambio). J/Q roban cartas del banco hasta llegar a 20.
"""
import random, itertools, sys
from collections import Counter

LIVES = {2: 6, 3: 4, 4: 3, 5: 2, 6: 2}

def bankval(c): return min(c[1], 10)
def total(bank): return sum(bankval(c) for c in bank)

def pay(bank, cost):
    """Quita del banco el subconjunto de menor suma >= cost. Devuelve cartas pagadas."""
    best = None
    for r in range(1, len(bank) + 1):
        for combo in itertools.combinations(range(len(bank)), r):
            s = sum(bankval(bank[i]) for i in combo)
            if s >= cost and (best is None or s < best[0]):
                best = (s, combo)
    paid = [bank[i] for i in best[1]]
    for i in sorted(best[1], reverse=True): bank.pop(i)
    return paid

class Game:
    def __init__(self, n, policies, reshuffle, rng):
        self.n, self.pol, self.reshuffle, self.rng = n, policies, reshuffle, rng
        hearts = [('H', r) for r in range(2, 15)]
        rng.shuffle(hearts)
        deck = [(s, r) for s in 'SCD' for r in range(2, 15)] + [('JB', 0), ('JR', 0)]
        self.lives = [[] for _ in range(n)]
        for p in range(n):
            for _ in range(LIVES[n]): self.lives[p].append([hearts.pop()[1], False])
        deck += hearts
        rng.shuffle(deck)
        self.deck, self.discard, self.cem = deck, [], []
        self.hand = [[self.deck.pop() for _ in range(5)] for _ in range(n)]
        self.luck = [[] for _ in range(n)]
        self.money = [[] for _ in range(n)]
        self.stats = Counter()
        self.turns_taken = [0] * n
        self.peak_money = [0] * n
        self.peak_luck = [0] * n
        self.money_drawn = [0] * n
        self.elim_before_first_turn = 0

    def alive(self, p): return bool(self.lives[p]) or any(c[0] == 'H' for c in self.hand[p])

    def draw(self, p, k=1):
        for _ in range(k):
            if not self.deck and self.reshuffle and self.discard:
                self.deck, self.discard = self.discard, []
                self.rng.shuffle(self.deck)
                self.stats['reshuffles'] += 1
            if not self.deck: return
            c = self.deck.pop()
            if c[0] == 'D': self.money_drawn[p] += bankval(c)
            self.hand[p].append(c)

    def drawcheck(self):
        if not self.deck and self.reshuffle and self.discard:
            self.deck, self.discard = self.discard, []; self.rng.shuffle(self.deck)
        if not self.deck: return None
        c = self.deck.pop(); self.discard.append(c); return c

    def kill(self, t, life, killer, steal=False):
        self.lives[t].remove(life)
        self.stats['kills'] += 1
        self.progress = True
        if steal: self.hand[killer].append(('H', life[0]))
        else: self.cem.append(life[0])
        if not self.alive(t) and self.turns_taken[t] == 0: self.elim_before_first_turn += 1

    def pick_target(self, p):
        opp = [q for q in range(self.n) if q != p and self.lives[q]]
        return self.rng.choice(opp) if opp else None

    def turn(self, p):
        self.turns_taken[p] += 1
        self.draw(p)
        H, moves, pol = self.hand[p], 3, self.pol[p]
        n_alive = sum(1 for q in range(self.n) if self.alive(q))
        passive = pol == 'tortuga' and n_alive > 2
        dmg = {}  # id(life) -> daño acumulado este turno
        while moves > 0:
            self.peak_money[p] = max(self.peak_money[p], total(self.money[p]))
            self.peak_luck[p] = max(self.peak_luck[p], total(self.luck[p]))
            hearts = [c for c in H if c[0] == 'H']
            if hearts:
                H.remove(hearts[0]); self.lives[p].append([hearts[0][1], False]); moves -= 1; continue
            if ('JR', 0) in H and self.cem:
                H.remove(('JR', 0)); self.discard.append(('JR', 0))
                v = max(self.cem); self.cem.remove(v); self.lives[p].append([v, False])
                self.stats['joker_rojo'] += 1; moves -= 1; continue
            m = total(self.money[p])
            if pol == 'ahorrador':
                if m >= 30 and self.cem and moves >= 1:
                    self.discard += pay(self.money[p], 30); H.append(('H', self.cem.pop()))
                    self.stats['vida_comprada'] += 1; moves -= 1; continue
            elif m >= 10 and (self.deck or (self.reshuffle and self.discard)):
                self.discard += pay(self.money[p], 10); self.draw(p, 3)
                self.stats['roba3'] += 1; moves -= 1; continue
            t = None if passive else self.pick_target(p)
            spades = sorted([c for c in H if c[0] == 'S' and c[1] != 14], key=lambda c: -c[1])
            if t is not None:
                L = self.lives[t]
                if ('JB', 0) in H:
                    H.remove(('JB', 0)); self.discard.append(('JB', 0))
                    k = ('S', 13) in H and moves >= 2 and len(L) >= 2
                    victims = sorted(L, key=lambda l: -l[0] if l[1] else -8)[:2 if k else 1]
                    if k: H.remove(('S', 13)); self.discard.append(('S', 13)); moves -= 1; self.stats['K+joker'] += 1
                    for v in victims: self.kill(t, v, p)
                    moves -= 1; continue
                if ('S', 14) in H:
                    H.remove(('S', 14)); self.discard.append(('S', 14))
                    v = max(L, key=lambda l: l[0] if l[1] else 8)
                    self.kill(t, v, p, steal=True); moves -= 1; continue
                if spades:
                    # 1) vida boca arriba matable con la combinación más barata
                    done = False
                    up = sorted([l for l in L if l[1]], key=lambda l: l[0] - dmg.get(id(l), 0))
                    for life in up:
                        need = life[0] - dmg.get(id(life), 0)
                        for r in range(1, min(moves, len(spades)) + 1):
                            combos = [c for c in itertools.combinations(spades, r) if sum(x[1] for x in c) >= need]
                            if combos:
                                combo = min(combos, key=lambda c: sum(x[1] for x in c))
                                for c in combo: H.remove(c); self.discard.append(c)
                                self.stats['overkill'] += sum(x[1] for x in combo) - need
                                self.stats['dmg_used'] += sum(x[1] for x in combo)
                                moves -= r
                                self.kill(t, life, p)
                                if any(c[1] == 11 for c in combo):
                                    while self.luck[t] and total(self.luck[p]) < 10**9 and sum(bankval(c) for c in self.luck[p][-3:]) < 20:
                                        self.luck[p].append(self.luck[t].pop())
                                        if total(self.luck[t]) == 0: break
                                if any(c[1] == 12 for c in combo):
                                    got = 0
                                    while self.money[t] and got < 20:
                                        c = self.money[t].pop(); got += bankval(c); self.money[p].append(c)
                                done = True; break
                        if done: break
                        # crítico con suerte: x2 si alcanza
                        if total(self.luck[p]) >= 10 and moves >= 2 and spades[0][1] * 2 >= need > spades[0][1]:
                            self.discard += pay(self.luck[p], 10); moves -= 2
                            c = spades[0]; H.remove(c); self.discard.append(c)
                            a, b = self.drawcheck(), self.drawcheck()
                            self.stats['crit_intentos'] += 1
                            if a and b and min(a[1], 10) > min(b[1], 10):
                                self.stats['crit_ok'] += 1; self.kill(t, life, p)
                            else: self.stats['dmg_wasted'] += c[1]
                            self.stats['dmg_used'] += c[1]
                            done = True; break
                    if done: continue
                    # 2) ataque a ciegas con la pica más alta
                    down = [l for l in L if not l[1]]
                    if down and (spades[0][1] >= 7 or len(H) >= 6):
                        life = self.rng.choice(down); c = spades[0]
                        H.remove(c); self.discard.append(c); moves -= 1
                        life[1] = True; self.stats['ciegos'] += 1; self.stats['dmg_used'] += c[1]
                        if c[1] >= life[0]:
                            self.stats['overkill'] += c[1] - life[0]; self.kill(t, life, p)
                        else:
                            dmg[id(life)] = c[1]; self.stats['ciegos_fallidos'] += 1
                        continue
            # 3) ahorrar
            bankable = [c for c in H if c[0] in 'CD']
            if bankable:
                c = max(bankable, key=bankval); H.remove(c)
                (self.luck if c[0] == 'C' else self.money)[p].append(c)
                self.played = True; moves -= 1; continue
            break
        self.stats['moves_sin_usar'] += moves
        self.stats['moves_total'] += 3
        for l_id, d in dmg.items(): self.stats['dmg_wasted'] += d

    def play(self, max_rounds=300):
        for rnd in range(max_rounds):
            self.progress = False
            cards_before = sum(len(h) for h in self.hand) + len(self.deck)
            for p in range(self.n):
                if not self.alive(p): continue
                self.turn(p)
                al = [q for q in range(self.n) if self.alive(q)]
                if len(al) == 1: return al[0], rnd + 1
            cards_after = sum(len(h) for h in self.hand) + len(self.deck)
            if not self.deck and not self.progress and cards_before == cards_after and not (self.reshuffle and self.discard):
                return None, rnd + 1
        return None, max_rounds

def run(n, policies, reshuffle, N=4000, seed=1):
    rng = random.Random(seed)
    wins, rounds, agg, stalled = Counter(), [], Counter(), 0
    pk_m, pk_l, md, elim0 = [], [], [], 0
    for _ in range(N):
        g = Game(n, policies, reshuffle, rng)
        w, r = g.play()
        if w is None: stalled += 1
        else: wins[w] += 1; rounds.append(r)
        agg.update(g.stats); pk_m += g.peak_money; pk_l += g.peak_luck; md += g.money_drawn
        elim0 += g.elim_before_first_turn
    return dict(wins=wins, rounds=rounds, agg=agg, stalled=stalled, N=N, pk_m=pk_m, pk_l=pk_l, md=md, elim0=elim0)

def report(title, r, n):
    N, a = r['N'], r['agg']
    print(f'\n=== {title} ===')
    print(f"  partidas atascadas (sin ganador): {100*r['stalled']/N:.1f}%")
    if r['rounds']:
        rs = sorted(r['rounds'])
        print(f"  rondas hasta ganador: media {sum(rs)/len(rs):.1f}, mediana {rs[len(rs)//2]}, p90 {rs[int(len(rs)*.9)]}")
    fin = sum(r['wins'].values()) or 1
    print('  victorias por asiento: ' + ', '.join(f"J{p+1} {100*r['wins'][p]/fin:.1f}%" for p in range(n)))
    print(f"  movimientos sin usar: {100*a['moves_sin_usar']/a['moves_total']:.1f}%")
    print(f"  ataques a ciegas fallidos: {100*a['ciegos_fallidos']/max(1,a['ciegos']):.1f}%  | daño desperdiciado (fallos+overkill): {100*(a['dmg_wasted']+a['overkill'])/max(1,a['dmg_used']):.1f}%")
    print(f"  críticos: {a['crit_intentos']/N:.2f}/partida, éxito {100*a['crit_ok']/max(1,a['crit_intentos']):.1f}%")
    print(f"  por partida: roba3 {a['roba3']/N:.2f}, vidas compradas {a['vida_comprada']/N:.3f}, joker rojo {a['joker_rojo']/N:.2f}, K+joker {a['K+joker']/N:.3f}, rebarajes {a['reshuffles']/N:.2f}")
    print(f"  dinero robado del mazo por jugador: media {sum(r['md'])/len(r['md']):.1f} | pico banco dinero >=20: {100*sum(x>=20 for x in r['pk_m'])/len(r['pk_m']):.1f}%, >=30: {100*sum(x>=30 for x in r['pk_m'])/len(r['pk_m']):.1f}%")
    print(f"  pico banco suerte >=20: {100*sum(x>=20 for x in r['pk_l'])/len(r['pk_l']):.1f}%, >=30: {100*sum(x>=30 for x in r['pk_l'])/len(r['pk_l']):.1f}%")
    print(f"  jugadores eliminados antes de su primer turno: {r['elim0']/N:.3f}/partida")

if __name__ == '__main__':
    for n in (2, 3, 4, 6):
        report(f'{n} jugadores, SIN rebarajar (manual literal)', run(n, ['normal'] * n, False), n)
        report(f'{n} jugadores, rebarajando descarte', run(n, ['normal'] * n, True), n)
    report('2j: ahorrador (J1) vs normal (J2), con rebaraje', run(2, ['ahorrador', 'normal'], True), 2)
    report('2j: normal (J1) vs ahorrador (J2), con rebaraje', run(2, ['normal', 'ahorrador'], True), 2)
    for seat in (0, 3):
        pol = ['normal'] * 4; pol[seat] = 'tortuga'
        report(f'4j: tortuga en asiento {seat+1} vs 3 normales, con rebaraje', run(4, pol, True), 4)
