# Stratecorum · versión de escritorio (Lua + LÖVE 11.5)

Pass-and-play para 2 a 6 personas en el mismo ordenador, con **reglas v2** (`docs/MANUAL_V2.md`).

```sh
cd love && love .          # jugar (ESC menú · F pantalla completa · M sonido · S velocidad · E fin de turno · clic derecho cancela)
love . --selftest 200      # autoprueba sin ventana: 200 partidas de bots (2, 3 y 4 jugadores), imprime JSON y sale
love . --autoplay 4        # los bots juegan por todos los humanos con la interfaz real (para probar la pantalla)
```

**Reglas v2 en dos líneas:** robás 2 cartas y hacés 3 movimientos por turno (1 el primero; en la primera ronda nadie ataca), mano máxima 7; el daño de los rayos (♠) se acumula bajo la vida, se pueden combinar varios rayos en un golpe y el defensor puede bloquear una vez por turno rival con un trébol (♣) de su mano, salvo contra el joker negro.
Figuras ♥/♠ valen 11–14 (♣/♦ ahorran 10); J/Q roban banco, K reparte 13 entre dos vidas, A se lleva la vida a la mano; suerte 10/20/30 = duelo de 1/2/3 cartas (~52/69/77 %) por x2/x2/x3; dinero 10 roba 2, 20 x2 seguro, 30 revive; al perder una vida robás 1 y al eliminar a alguien te quedás sus bancos; el descarte se rebaraja (4.º: sin defensas, 7.º: gana quien tenga más vidas).

Baraja francesa con la tabla de equivalencias del manual: ♥ corazones = vidas · ♠ picas = rayos · ♣ tréboles = suerte y defensa · ♦ diamantes = monedas.

Estructura: `main.lua` (interfaz y driver por corrutinas) · `src/engine.lua` (motor de reglas, sin LÖVE, port del motor de `web/index.html`) · `src/ai.lua` (bots) · `src/selftest.lua` · `src/deck.lua`, `src/cardart.lua`, `src/particles.lua`, `src/audio.lua`, `lib/tween.lua`.
