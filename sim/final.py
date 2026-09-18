import sim2
from sim2 import *
V2F = dict(V1, reshuffle=True, persist=True, luck_v2=True, ace_v2=True, kjoker='distinct', hand_limit=7, buy_any=True,
           bounty=True, defense=True, def_mode='once', no_attack_r1=True, loss_draw=True, draw_turn=2, draw_n=2,
           first_moves=1, tiers=(10, 20, 30), sudden=4, hard=7)
if __name__ == '__main__':
    print('##### v1 + rebarajar (referencia) vs V2 final')
    for n in (2, 3, 4, 5, 6):
        line(f'{n}j v1+rebarajar', run(n, ['mixto'] * n, dict(V1, reshuffle=True), N=3000))
        r = run(n, ['mixto'] * n, V2F, N=3000); line(f'{n}j V2 FINAL', r)
        rs = sorted(sim2.RESH); print(f"      rebarajes mediana {rs[len(rs)//2]} p90 {rs[int(len(rs)*.9)]} | acaban por reloj: {100*r['agg']['fin_por_reloj']/r['N']:.1f}% | K+joker {r['agg']['K+joker']/r['N']:.2f} | descartes por límite {r['agg']['descartes_limite']/r['N']:.1f}")
    print('\n##### Tortuga en 4j, V2 final')
    for seat in (0, 3):
        pol = ['mixto'] * 4; pol[seat] = 'tortuga'
        r = run(4, pol, V2F, N=2000); line(f'tortuga asiento {seat+1}', r)
        print(f"      acaban por reloj: {100*r['agg']['fin_por_reloj']/r['N']:.1f}%")
    pairs = [('vida', 'cartas'), ('x2', 'cartas'), ('mixto', 'cartas'), ('mixto', 'x2'), ('mixto', 'vida'), ('x2', 'vida')]
    print('\nduelo estrategias V2 final:', {f'{a}>{b}': round(matchup(V2F, a, b, N=2000)) for a, b in pairs})
