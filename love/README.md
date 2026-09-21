# Stratecorum · versión de escritorio (Lua + LÖVE 11.5)

Pass-and-play para 2 a 6 personas en el mismo ordenador, con **reglas v3** (`docs/MANUAL_V3.md`, por defecto) o **v2** (`docs/MANUAL_V2.md`): se eligen en el menú principal.

```sh
cd love && love .          # jugar (ESC menú · F pantalla completa · M sonido · S velocidad · E fin de turno · clic derecho cancela)
love . --selftest 200      # autoprueba sin ventana: 200 partidas de bots (mitad v2, mitad v3; 2, 3 y 4 jugadores), imprime JSON y sale
love . --autoplay 4        # los bots juegan por todos los humanos con la interfaz real (para probar la pantalla); --rules 2 para v2
```

**Reglas v3 en tres líneas:** además de bloquear desde la mano, podés poner **una carta boca abajo bajo una vida tuya** (una por vida, 1 movimiento): un **trébol es escudo** (resta su valor al golpe) y un **rayo es trampa** (cuando atacan esa vida, salta y golpea al atacante con su valor contra su vida revelada con menos aguante, o su primera oculta, que se revela; el atacante puede bloquearlo con un trébol de la mano y el daño se queda bajo su vida; después sigue el ataque). Con 10 de dinero **ocultás** una vida revelada (el daño se conserva en secreto) y con 1 movimiento **reordenás** dos vidas ocultas.
La J **revela** (para todos) una vida oculta del rival golpeado a elección del atacante (con K repartida entre dos rivales, una de cada uno), la Q **desarma** escudo o trampa (y roba 2 del banco más rico si destruye), cualquier combo con K se **reparte** entre dos vidas, los efectos de las figuras se suman dentro del combo, la suerte 30 multiplica x3 a todo el combo y el dinero 10 roba 2 y descarta 1. El conmutador vive en `G.v3` (`E.newGame(n, hooks, { v3 = ... })`).
En la interfaz: un trébol de la mano abre el menú *banco / escudo*; un rayo seleccionado solo ofrece el botón *Trampa bajo una vida tuya* (o tocás directamente una vida tuya sin nada debajo). Los bots ponen de trampa su rayo más bajo (≤ 6; ≤ 8 con `AI.level = "hard"`) bajo una vida oculta de valor ≥ 8 cuando tienen al menos 2 rayos, y un trébol sobrante como escudo bajo una vida revelada que aguante ≥ 5.

**Reglas v2 en dos líneas:** robás 2 cartas y hacés 3 movimientos por turno (1 el primero; en la primera ronda nadie ataca), mano máxima 7; el daño de los rayos (♠) se acumula bajo la vida, se pueden combinar varios rayos en un golpe y el defensor puede bloquear una vez por turno rival con un trébol (♣) de su mano, salvo contra el joker negro.
Figuras ♥/♠ valen 11–14 (♣/♦ ahorran 10); J/Q roban banco, K reparte 13 entre dos vidas, A se lleva la vida a la mano; suerte 10/20/30 = duelo de 1/2/3 cartas (~52/69/77 %) por x2/x2/x3; dinero 10 roba 2, 20 x2 seguro, 30 revive; al perder una vida robás 1 y al eliminar a alguien te quedás sus bancos; el descarte se rebaraja (4.º: sin defensas, 7.º: gana quien tenga más vidas).

Baraja francesa con la tabla de equivalencias del manual: ♥ corazones = vidas · ♠ picas = rayos · ♣ tréboles = suerte y defensa · ♦ diamantes = monedas.

Estructura: `main.lua` (interfaz y driver por corrutinas) · `src/engine.lua` (motor de reglas, sin LÖVE, port del motor de `web/index.html`) · `src/ai.lua` (bots) · `src/selftest.lua` · `src/deck.lua`, `src/cardart.lua`, `src/particles.lua`, `src/audio.lua`, `lib/tween.lua`.
