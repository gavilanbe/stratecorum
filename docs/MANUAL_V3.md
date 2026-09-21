# Stratecorum — Reglas v3 🃏

> Cambios sobre el [manual v2](MANUAL_V2.md). Todo lo que no aparece aquí sigue igual. La versión web permite elegir v2 o v3 en el menú; la versión LÖVE juega con v2.

**Por qué:** en v2, como el daño nunca se pierde, atacar con todo cada turno es casi siempre lo mejor, y el rival lo sabe todo de tus vidas en cuanto las golpea. v3 devuelve información oculta a la mesa y da al defensor decisiones propias.

## 1. Ocultar y reordenar

- **Ocultar** (10 de dinero + 1 movimiento): una vida revelada vuelve boca abajo. Los rayos que tenía debajo se descartan; **el daño se queda**, pero solo lo sabes tú. Si la vuelven a golpear, se revela con su daño.
- **Reordenar** (1 movimiento): cambias de sitio dos vidas tuyas boca abajo, con lo que tengan debajo. Solo tiene sentido después de ocultar: el rival vio dónde estaba la herida y la pierde de vista.

## 2. Tréboles: escudo o trampa

Además de bloquear desde la mano (igual que en v2) y de ahorrarse como suerte, un trébol se puede poner **boca abajo bajo una vida tuya** (1 movimiento), declarando en secreto qué es. Una por vida. Todos ven que hay algo debajo; nadie sabe qué.

- **Escudo**: cuando ataquen esa vida, resta su valor al golpe y se descarta. No gasta tu bloqueo del turno; puedes bloquear además con un trébol de la mano.
- **Trampa**: captura el **rayo más alto** del ataque **antes de que golpee**: ese rayo pasa a tu mano y no hace daño. El resto del ataque entra. Se descarta al saltar.
- El comodín negro no activa ni escudos ni trampas.
- Orden al atacar una vida: se revela → salta el escudo o la trampa → el defensor puede bloquear desde la mano → golpean los rayos.

## 3. Ataques

- **K acumulativa**: cualquier combo que incluya una K se puede **repartir entre dos vidas** (de uno o dos rivales) con el total del combo. Declaras el reparto sobre la suma de los rayos; los multiplicadores se aplican después, en proporción.
- **Suerte 30**: el x3 se aplica **a todo el combo**, no solo a la carta más alta. Los x2 (suerte 10/20 y dinero 20) siguen aplicándose a la carta más alta.

## 4. Figuras de rayos

| Carta | v3 |
|---|---|
| **J (11), espía** | Al golpear una vida (mate o no), miras **una vida oculta** de ese rival. Solo tú la ves; queda marcada para ti hasta que la oculten o reordenen. |
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

Miles de partidas de bots por configuración (`?selftest=300&rules=3`). Uso medio por partida a dos jugadores: 4–7 tréboles bajo vidas, 2–3 trampas que saltan, 1 escudo, 1 ocultación con reordenación, 2 espionajes de J, 0,3 repartos de K. Duración: 2 jugadores 12–13 rondas (mediana), 3 jugadores 9, 4 jugadores 8; asientos equilibrados.

Lo importante: un bot que solo ataca pierde 7 de cada 10 partidas contra uno que escuda, tiende trampas y oculta. En v2 empataban. **Atacar a ciegas ya tiene precio**, y el contrajuego existe: sondear con rayos bajos para hacer saltar trampas, espiar con la J, desarmar con la Q, y elegir vidas sin nada debajo.

## 7. Qué no cambia

Robar 2, 3 movimientos, primera ronda sin ataques, 1 movimiento para quien empieza, mano 7, daño persistente, ataque combinado, bloqueo desde la mano (1 por turno rival), adrenalina, botín, duelo de suerte 10/20/30, comodines, rebarajes, muerte súbita y reloj.
