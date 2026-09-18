"""Stratecorum: banco de pruebas de reglas (v1 del manual vs. variantes v2).
Valores: corazones/picas 2-10, J=11, Q=12, K=13, A=14; tréboles/diamantes: figuras = 10.
"""
import random, itertools
from collections import Counter

V1 = dict(reshuffle=False, persist=False, defense=False, luck_v2=False, tiers=(10, 20, 30), draw_n=3,
          draw_turn=1, first_moves=3, protect_first=False, hand_limit=None, loss_draw=False, bounty=False,
          ace_v2=False, kjoker='any', buy_any=False, decks=1, lives=None, def_mode='full', no_attack_r1=False, kill_draw=False)

def bv(c): return min(c[1], 10) if c[1] else 0
def total(bank): return sum(bv(c) for c in bank)
def duel(c): return 15 if c[0] in ('JB', 'JR') else c[1]

def pay(bank, cost):
    best = None
    for r in range(1, len(bank) + 1):
        for combo in itertools.combinations(range(len(bank)), r):
            s = sum(bv(bank[i]) for i in combo)
            if s >= cost and (best is None or s < best[0]): best = (s, combo)
    paid = [bank[i] for i in best[1]]
    for i in sorted(best[1], reverse=True): bank.pop(i)
    return paid

class Life:
    __slots__ = ('v', 'up', 'dmg', 'att')
    def __init__(self, v): self.v, self.up, self.dmg, self.att = v, False, 0, []
    @property
    def rem(self): return self.v - self.dmg

class Game:
    def __init__(self, n, pol, cfg, rng):
        self.n, self.pol, self.c, self.rng = n, pol, cfg, rng
        d = cfg['decks']
        hearts = [('H', r) for r in range(2, 15)] * d
        rng.shuffle(hearts)
        deck = ([(s, r) for s in 'SCD' for r in range(2, 15)] + [('JB', 0), ('JR', 0)]) * d
        nl = cfg['lives'] or {2: 6, 3: 4, 4: 3, 5: 2, 6: 2}[n]
        self.start_lives = nl
        self.lives = [[Life(hearts.pop()[1]) for _ in range(nl)] for _ in range(n)]
        deck += hearts; rng.shuffle(deck)
        self.deck, self.discard, self.cem = deck, [], []
        self.hand = [[self.deck.pop() for _ in range(5)] for _ in range(n)]
        self.luck = [[] for _ in range(n)]; self.money = [[] for _ in range(n)]
        for q in range(1, n):
            for _ in range(cfg.get('comp', 0)): self.hand[q].append(self.deck.pop())
        self.st = Counter(); self.turns = [0] * n; self.elim0 = 0
        self.first_kill_round = None; self.lead_changes = 0

    def alive(self, p): return bool(self.lives[p]) or any(c[0] == 'H' for c in self.hand[p])

    def _refill(self):
        if not self.deck and self.c['reshuffle'] and self.discard:
            self.deck, self.discard = self.discard, []; self.rng.shuffle(self.deck); self.st['rebarajes'] += 1

    def draw(self, p, k=1):
        for _ in range(k):
            self._refill()
            if not self.deck: return
            self.hand[p].append(self.deck.pop())

    def flip(self):
        self._refill()
        if not self.deck: return None
        c = self.deck.pop(); self.discard.append(c); return c

    def kill(self, t, life, killer, steal=False):
        self.lives[t].remove(life); self.discard += life.att; life.att = []
        self.st['kills'] += 1; self.progress = True
        if steal: self.hand[killer].append(('H', life.v))
        else: self.cem.append(life.v)
        if self.c['loss_draw'] and self.alive(t): self.draw(t)
        if self.c['kill_draw']: self.draw(killer)
        if not self.alive(t):
            if self.turns[t] == 0: self.elim0 += 1
            if self.c['bounty']:
                self.luck[killer] += self.luck[t]; self.money[killer] += self.money[t]
                self.luck[t], self.money[t] = [], []
            self.discard += self.hand[t]; self.hand[t] = []

    def hit(self, p, t, life, card, mult=1):
        """Resuelve una carta de ataque contra una vida. Devuelve True si muere."""
        c = self.c
        self.hand[p].remove(card)
        val = card[1] * mult
        was_down = not life.up; life.up = True
        self.st['dmg_jugado'] += val
        if c['defense'] and self.st['rebarajes'] < c.get('sudden', 99):
            clubs = sorted([x for x in self.hand[t] if x[0] == 'C'], key=bv)
            red = (lambda x: (bv(x) + 1) // 2) if c['def_mode'] == 'half' else bv
            if val >= life.rem and not (c['def_mode'] == 'once' and t in self.defended):
                for cl in clubs:
                    if val - red(cl) < life.rem:
                        self.hand[t].remove(cl); self.discard.append(cl); self.defended.add(t)
                        val = max(0, val - red(cl)); self.st['defensas'] += 1; break
        if val >= life.rem:
            self.st['overkill'] += val - life.rem
            self.discard.append(card)
            steal = card[1] == 14 and c['ace_v2']
            self.kill(t, life, p, steal)
            if card[1] == 11: self.steal_bank(self.luck, p, t)
            if card[1] == 12: self.steal_bank(self.money, p, t)
            return True
        if was_down: self.st['ciegos_fallidos'] += 1
        life.dmg += val
        if c['persist']: life.att.append(card)
        else: self.discard.append(card); self.touched.append(life)
        return False

    def steal_bank(self, banks, p, t):
        got = 0
        banks[t].sort(key=bv)
        while banks[t] and got < 20:
            x = banks[t].pop(); got += bv(x); banks[p].append(x)

    def crit(self, p, t, tier):
        """tier 1..3. Devuelve multiplicador."""
        if not self.c['luck_v2']:
            a, b = self.flip(), self.flip()
            ok = a and b and min(a[1] or 15, 10) > min(b[1] or 15, 10)
            return (tier + 1) if ok else 1
        mine = [self.flip() for _ in range(tier)]; theirs = self.flip()
        mine = [duel(x) for x in mine if x]
        ok = mine and theirs and max(mine) >= duel(theirs)
        return (3 if tier == 3 else 2) if ok else 1

    def turn(self, p, first):
        c, H, pol = self.c, self.hand[p], self.pol[p]
        self.draw(p, c['draw_turn'])
        moves = c['first_moves'] if first else 3
        self.st['mov_total'] += moves
        self.touched = []; self.defended = set()
        n_alive = sum(self.alive(q) for q in range(self.n))
        t1, t2, t3 = c['tiers']
        target = None
        while moves > 0:
            hearts = [x for x in H if x[0] == 'H']
            if hearts:
                H.remove(hearts[0]); self.lives[p].append(Life(hearts[0][1])); moves -= 1; continue
            if ('JR', 0) in H and self.cem:
                H.remove(('JR', 0)); self.discard.append(('JR', 0))
                v = max(self.cem); self.cem.remove(v); self.lives[p].append(Life(v))
                self.st['joker_rojo'] += 1; moves -= 1; continue
            m = total(self.money[p])
            can_draw = self.deck or (c['reshuffle'] and self.discard)
            want_life = m >= t3 and self.cem and (pol == 'vida' or (pol == 'mixto' and len(self.lives[p]) <= self.start_lives / 2))
            if want_life:
                self.discard += pay(self.money[p], t3)
                v = max(self.cem) if c['buy_any'] else self.cem[-1]
                self.cem.remove(v)
                if c['buy_any']: self.lives[p].append(Life(v))
                else: H.append(('H', v))
                self.st['vida_comprada'] += 1; moves -= 1; continue
            want_draw = m >= t1 and can_draw and (
                pol == 'cartas' or (pol == 'mixto' and len(H) <= 4) or (pol == 'x2' and len(H) <= 2)
                or (pol == 'vida' and (len(H) <= 1 or (m >= t3 and not self.cem))))
            if want_draw:
                self.discard += pay(self.money[p], t1); self.draw(p, c['draw_n'])
                self.st['roba'] += 1; moves -= 1; continue
            # --- ataque
            if target is None or not self.lives[target]:
                opp = [q for q in range(self.n) if q != p and self.lives[q] and not (c['protect_first'] and self.turns[q] == 0 and self.n > 2)]
                target = self.rng.choice(opp) if opp else None
            t = target
            if t is not None and not (pol == 'tortuga' and n_alive > 2) and not (c['no_attack_r1'] and self.round == 0):
                L = self.lives[t]
                if ('JB', 0) in H:
                    H.remove(('JB', 0)); self.discard.append(('JB', 0))
                    key = lambda l: -(l.rem if l.up else 8)
                    victims = [min(L, key=key)]
                    if ('S', 13) in H and moves >= 2 and c['kjoker'] != 'off':
                        if c['kjoker'] == 'any' or self.n == 2:
                            pool = [(t, l) for l in L if l is not victims[0]]
                        else:
                            pool = [(q, l) for q in range(self.n) if q not in (p, t) for l in self.lives[q]]
                        if pool:
                            q, l2 = min(pool, key=lambda x: key(x[1]))
                            H.remove(('S', 13)); self.discard.append(('S', 13)); moves -= 1
                            self.kill(q, l2, p); self.st['K+joker'] += 1
                    self.kill(t, victims[0], p); moves -= 1; continue
                if ('S', 14) in H and not c['ace_v2']:
                    H.remove(('S', 14)); self.discard.append(('S', 14))
                    self.kill(t, max(L, key=lambda l: l.v if l.up else 8), p, steal=True); moves -= 1; continue
                sp = sorted([x for x in H if x[0] == 'S'], key=lambda x: x[1])
                if sp:
                    up = sorted([l for l in L if l.up], key=lambda l: l.rem)
                    down = [l for l in L if not l.up]
                    act = None
                    for life in up:  # remate directo con la pica más barata
                        ok = [x for x in sp if x[1] >= life.rem]
                        if ok: act = (life, ok[0], 0); break
                    if act is None and not c['persist']:
                        for life in up:  # combo dentro del turno
                            for r in range(2, min(moves, len(sp)) + 1):
                                cs = [k for k in itertools.combinations(sp, r) if sum(x[1] for x in k) >= life.rem]
                                if cs: act = (life, min(cs, key=lambda k: sum(x[1] for x in k))[0], 0); break
                            if act: break
                    if act is None and moves >= 2 and up:  # multiplicador
                        life, best = up[0], sp[-1]
                        if best[1] * 2 >= life.rem:
                            if pol in ('x2', 'mixto') and m >= t2: act = (life, best, 'money')
                            elif total(self.luck[p]) >= 10: act = (life, best, 'luck')
                        elif best[1] * 3 >= life.rem and total(self.luck[p]) >= 30 and c['luck_v2']:
                            act = (life, best, 'luck')
                    if act is None:
                        if down and (sp[-1][1] >= 8 or not up): act = (self.rng.choice(down), sp[-1], 0); self.st['ciegos'] += 1
                        elif up and c['persist']: act = (up[0], sp[-1], 0)
                        elif down and len(H) >= 6: act = (self.rng.choice(down), sp[-1], 0); self.st['ciegos'] += 1
                    if act:
                        life, card, boost = act; mult = 1
                        if boost == 'money':
                            self.discard += pay(self.money[p], t2); mult = 2; moves -= 1; self.st['x2_dinero'] += 1
                        elif boost == 'luck':
                            lk = total(self.luck[p]); tier = 3 if lk >= 30 else 2 if lk >= 20 else 1
                            if not c['luck_v2']:  # en v1 solo compensa pagar el tier necesario
                                tier = 1
                            self.discard += pay(self.luck[p], tier * 10); moves -= 1
                            mult = self.crit(p, t, tier); self.st['crit_intentos'] += 1; self.st['crit_ok'] += mult > 1
                        self.hit(p, t, life, card, mult); moves -= 1; continue
            # --- ahorrar
            clubs = sorted([x for x in H if x[0] == 'C'], key=bv)
            if c['defense'] and clubs: clubs = clubs[:-1]  # guarda el trébol más alto para defender
            cap = c.get('bank_cap') or 99
            bank = ([x for x in H if x[0] == 'D'] if len(self.money[p]) < cap else []) + (clubs if len(self.luck[p]) < cap else [])
            if bank:
                x = max(bank, key=bv); H.remove(x)
                (self.luck if x[0] == 'C' else self.money)[p].append(x); moves -= 1; continue
            break
        self.st['mov_sin_usar'] += moves
        for l in self.touched:
            self.st['dmg_perdido'] += l.dmg; l.dmg = 0
        if c['hand_limit']:
            while len(H) > c['hand_limit']:
                x = min(H, key=lambda x: 99 if x[0] in ('H', 'JB', 'JR') else x[1]); H.remove(x); self.discard.append(x)
                self.st['descartes_limite'] += 1

    def play(self, max_rounds=200):
        leader = None
        for rnd in range(max_rounds):
            self.round = rnd
            for p in range(self.n):
                if not self.alive(p): continue
                self.turn(p, first=(rnd == 0 and p == 0)); self.turns[p] += 1
                al = [q for q in range(self.n) if self.alive(q)]
                if len(al) == 1: return al[0], rnd + 1
                if self.st['rebarajes'] >= self.c.get('hard', 999):
                    self.st['fin_por_reloj'] += 1
                    best = max(al, key=lambda q: (len(self.lives[q]), sum(l.rem for l in self.lives[q]), self.rng.random()))
                    return best, rnd + 1
            if self.n == 2:
                a, b = len(self.lives[0]), len(self.lives[1])
                ld = 0 if a > b else 1 if b > a else leader
                if leader is not None and ld != leader: self.lead_changes += 1
                leader = ld
            if not self.deck and not (self.c['reshuffle'] and self.discard) and not any(
                    x[0] in ('S', 'JB') for h in self.hand for x in h):
                return None, rnd + 1
        return None, max_rounds

RESH = []
def run(n, pol, cfg, N=3000, seed=7):
    RESH.clear()
    rng = random.Random(seed); wins = Counter(); rounds = []; agg = Counter(); stall = elim0 = lc = 0
    for _ in range(N):
        g = Game(n, pol, cfg, rng); w, r = g.play()
        if w is None: stall += 1
        else: wins[w] += 1; rounds.append(r)
        agg.update(g.st); elim0 += g.elim0; lc += g.lead_changes; RESH.append(g.st['rebarajes'])
    return dict(wins=wins, rounds=sorted(rounds), agg=agg, stall=stall, N=N, elim0=elim0, lc=lc, n=n)

def line(title, r):
    N, a, n = r['N'], r['agg'], r['n']; rs = r['rounds']; fin = sum(r['wins'].values()) or 1
    seats = '/'.join(f"{100*r['wins'][p]/fin:.0f}" for p in range(n))
    med = rs[len(rs)//2] if rs else '-'; p90 = rs[int(len(rs)*.9)] if rs else '-'
    waste = 100 * (a['overkill'] + a['dmg_perdido']) / max(1, a['dmg_jugado'])
    print(f"{title:<46} atasc {100*r['stall']/N:4.1f}% | rondas {med}/{p90} | asientos {seats} | daño perdido {waste:3.0f}% | "
          f"mov sin usar {100*a['mov_sin_usar']/max(1,a['mov_total']):3.0f}% | elim0 {r['elim0']/N:.2f} | por partida: roba {a['roba']/N:.1f} "
          f"x2$ {a['x2_dinero']/N:.2f} vida$ {a['vida_comprada']/N:.2f} crit {a['crit_intentos']/N:.2f}({100*a['crit_ok']/max(1,a['crit_intentos']):.0f}%) "
          f"def {a['defensas']/N:.1f} cambios líder {r['lc']/N:.2f}")

def matchup(cfg, a, b, N=2000):
    r1 = run(2, [a, b], cfg, N, seed=11); r2 = run(2, [b, a], cfg, N, seed=12)
    w = r1['wins'][0] + r2['wins'][1]; tot = sum(r1['wins'].values()) + sum(r2['wins'].values())
    return 100 * w / max(1, tot)

