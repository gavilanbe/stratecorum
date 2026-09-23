# Stratecorum — Reglas v3 🃏

> Cambios sobre el [manual v2](MANUAL_V2.md). Todo lo que no aparece aquí sigue igual. La versión web permite elegir v2 o v3 en el menú; la versión LÖVE juega con v2.

**Por qué:** en v2, como el daño nunca se pierde, atacar con todo cada turno es casi siempre lo mejor, y el rival lo sabe todo de tus vidas en cuanto las golpea. v3 devuelve información oculta a la mesa y da al defensor decisiones propias.

## 1. Ocultar y reordenar

- **Ocultar** (10 de dinero + 1 movimiento): una vida revelada vuelve boca abajo. Los rayos que tenía debajo se descartan; **el daño se queda**, pero solo lo sabes tú. Si la vuelven a golpear, se revela con su daño.
- **Reordenar** (1 movimiento): cambias de sitio dos vidas tuyas boca abajo, con lo que tengan debajo. Solo tiene sentido después de ocultar: el rival vio dónde estaba la herida y la pierde de vista.

## 2. Bajo una vida: escudo (trébol) o trampa (rayo)

Puedes poner **una carta boca abajo bajo una vida tuya** (1 movimiento). Todos ven que hay algo debajo; nadie sabe qué es ni cuánto vale. Una por vida.

- **Trébol = escudo**: cuando ataquen esa vida, resta su valor al golpe y se descarta. No gasta tu bloqueo del turno: además puedes bloquear con un trébol de la mano.
- **Rayo = trampa**: cuando ataquen esa vida, el rayo **salta y golpea al atacante** con su valor, contra su vida revelada más débil (o una oculta, que se revela, si no tiene ninguna). El atacante puede bloquearlo con un trébol de su mano; el daño que entra se queda bajo su vida. Después el ataque original sigue su curso.
- El comodín negro no activa ni escudos ni trampas.
- Orden al atacar una vida: se revela → salta el escudo o la trampa → el defensor puede bloquear desde la mano → golpean los rayos.

## 3. Ataques

- **K acumulativa**: cualquier combo que incluya una K se puede **repartir entre dos vidas** (de uno o dos rivales) con el total del combo. Declaras el reparto sobre la suma de los rayos; los multiplicadores se aplican después, en proporción.
- **Los efectos de las figuras se suman**: en un combo con J, Q, K y A, cada una hace lo suyo (revela, desarma y roba, reparte, se queda la vida) sobre las vidas golpeadas.
- **Suerte 30**: el x3 se aplica **a todo el combo**, no solo a la carta más alta. Los x2 (suerte 10/20 y dinero 20) siguen aplicándose a la carta más alta.

## 4. Figuras de rayos

| Carta | v3 |
|---|---|
| **J (11), revela** | Al golpear una vida (mate o no), **revelas una vida oculta** de ese rival (para todos). Con una K repartida entre dos rivales, una de cada uno. |
| **Q (12), desarma** | Su golpe **ignora el escudo o la trampa** de la vida atacada (se descarta sin efecto). Si destruye la vida, roba las 2 mejores cartas del banco más rico del rival. |
| **K (13), reparte** | Ver arriba. |
| **A (14), roba** | Igual que en v2: si destruye la vida, te la llevas a la mano. |

## 5. Dinero

| Gastas | Efecto |
|---|---|
| 10 | Roba 2 cartas **y descarta 1**. |
| 10 | **Ocultar** una vida revelada. |
| 20 | x2 seguro a tu siguiente ataque. |
| 30 | Revive cualquier vida del cementerio. |

## 6. Datos de simulación

Miles de partidas de bots (`?selftest=300&rules=3`). Uso medio por partida a dos jugadores: 2–5 cartas bajo vidas, 1 escudo y 0,5–1 trampa que saltan, 1 ocultación con reordenación, 2 revelaciones de J, 0,4 repartos de K. Duración: 2 jugadores 12–13 rondas (mediana), 3 jugadores 9, 4 jugadores 9; asientos equilibrados (4 jugadores: 72/75/75/78 de 300).

Con la trampa como rayo que golpea, un bot que solo ataca y otro que además escuda, tiende trampas y oculta quedan igualados; la variante anterior (trampa que capturaba el rayo) daba ventaja clara al defensor. Es decir: las jugadas defensivas son opciones, no la estrategia dominante. Falta probarlas entre personas.

## 7. Apertura justa (septiembre de 2026, también con v2)

- **Quien no empieza recibe 1 carta más al repartir** (6 en vez de 5).
- Se quita «quien empieza solo tiene 1 movimiento»: todos tienen 3 desde el primer turno. La primera ronda sigue sin ataques.
- La CPU desempata al azar a quién ataca. Antes atacaba al siguiente en la mesa y se formaba un anillo que favorecía a quien empieza.

**Por qué** (miles de partidas de bots con el motor de la web, `?selftest` y un análisis propio): con todos rematando al más débil, quien empieza golpea primero, su víctima se convierte en el blanco de todos y él cobra el botín. No lo arreglaban ni quitar el botín, ni la adrenalina de 2 cartas, ni dos rondas sin ataques; la carta de más para los demás sí.

| Gana quien empieza | Antes | Ahora | Justo |
|---|---|---|---|
| 2 jugadores | 55 % | 50,6 % | 50 % |
| 3 jugadores | 55 % | 39,6 % | 33 % |
| 4 jugadores | 42 % | 28,4 % | 25 % |

Por asiento queda repartido (4 jugadores: 23,5 / 24,7 / 25,2 / 26,6 %) y la duración no cambia (13 / 9 / 8 rondas). A 4 jugadores la muerte súbita llega algo más a menudo (hay más cartas en mano y el mazo se agota antes). Las repeticiones compartidas antes del cambio y las partidas en línea con un anfitrión de la versión anterior se juegan con la apertura de entonces.

## 8. Qué no cambia

Robar 2, 3 movimientos, primera ronda sin ataques, mano 7, daño persistente, ataque combinado, bloqueo desde la mano (1 por turno rival), adrenalina, botín, duelo de suerte 10/20/30, comodines, rebarajes, muerte súbita y reloj.
