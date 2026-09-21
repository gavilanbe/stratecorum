# Stratecorum 🃏

**Jugar:** https://gavilanbe.github.io/stratecorum/

Juego de cartas estratégico con baraja propia (corazón, rayo, trébol de cuatro hojas y moneda). Gana el último con vidas ♥ en la mesa. Todo el arte, la fuente, la música y los sonidos se generan por código.

Modos: **contra la CPU** (1–3 rivales, tres niveles), **pasar y jugar** (2–4 personas en el mismo aparato) y **en línea** (cada uno en su móvil). Funciona en móvil (apaisado, instalable como app, también sin conexión) y en escritorio.

## Cómo se juega

Cada turno robas 2 cartas y haces **3 movimientos** (1 carta = 1 movimiento). En la primera ronda nadie ataca; quien empieza solo tiene 1 movimiento. Mano máxima: 7.

- **♥ Corazón**: colócalo boca abajo como vida nueva. El rival no sabe cuánto aguanta hasta golpearla.
- **⚡ Rayo**: elige uno o varios y luego una vida rival. **El daño se acumula**: el rayo se queda bajo la vida. Varios rayos a la vez = un solo golpe combinado.
  - **J (11)**: si destruye, roba las 2 mejores cartas de suerte del rival.
  - **Q (12)**: si destruye, roba las 2 mejores cartas de dinero.
  - **K (13)**: sola, reparte su daño entre dos vidas.
  - **A (14)**: si destruye, la vida es tuya (a la mano).
- **♣ Trébol**: en la mesa es **suerte**; en la mano **bloquea** un ataque restando su valor (1 bloqueo por turno rival).
- **● Moneda**: en la mesa es **dinero**.
- **Suerte** 10 / 20 / 30: duelo de cartas (volteas 1 / 2 / 3 y te quedas la mejor; el rival voltea 1). Si ganas, el siguiente rayo hace **x2** (x3 con 30). Probabilidad ~52 / 69 / 77 %.
- **Dinero** 10: roba 2 · 20: rayo x2 seguro · 30: revive cualquier vida del cementerio.
- **Comodín negro**: destruye una vida sin bloqueo posible (con una K, dos vidas de rivales distintos). **Comodín rojo**: revive una vida; si el cementerio está vacío, roba 2.
- Pierdes una vida: robas 1 carta. Eliminas a alguien: te quedas sus bancos.
- 4.º rebaraje del mazo: se acaban los bloqueos. 7.º: gana quien tenga más vidas.

Reglas completas y datos de simulación en [`docs/MANUAL_V2.md`](docs/MANUAL_V2.md).

### Reglas v3 (por defecto en la web; conmutable en el menú)

Añaden información oculta y decisiones para el defensor. Detalle en [`docs/MANUAL_V3.md`](docs/MANUAL_V3.md).

- **Ocultar** (10 de dinero): una vida revelada vuelve boca abajo; su daño se queda pero solo lo sabes tú. **Reordenar** (1 mov): cambias dos vidas ocultas de sitio.
- **Escudo o trampa**: un trébol boca abajo bajo una vida, en secreto. El escudo resta su valor; la trampa captura el rayo más alto del ataque antes de que golpee y te lo llevas a la mano.
- **K acumulativa**: cualquier combo con K se reparte entre dos vidas. **Suerte 30**: el x3 va a todo el combo.
- **J espía** una vida oculta al golpear · **Q desarma** escudos y trampas y roba del banco más rico · **A** roba la vida.
- **Dinero 10**: roba 2 y descarta 1, u ocultar.

## La máquina

Tres niveles, elegibles en el menú. **Fácil** elige rival al azar y no combina. **Normal** ataca al rival más cerca de caer, remata con el combo de menor desperdicio, reparte la K entre dos vidas, planifica multiplicadores y guarda un trébol para bloquear. **Difícil** además compra cartas en cuanto puede, paga más suerte por más probabilidad, deja margen contra un bloqueo cuando sale barato y bloquea golpes grandes a vidas valiosas. En simulación, difícil gana algo más que normal en mesas de tres; contra bots la diferencia es pequeña, contra personas se nota más.

## Pasar y jugar

Menú → `PASAR Y JUGAR` → 2, 3 o 4 personas. Entre turnos aparece una pantalla que tapa la mesa hasta que el siguiente toca; cuando atacan a alguien y puede bloquear, también se le pasa el aparato para que elija.

## Jugar en línea (varios móviles)

Botón `● ONLINE` en el menú. Uno **crea la sala** y comparte el código de 4 letras (o el enlace `?sala=CÓDIGO` con el botón Compartir); los demás **se unen con el código**. Hasta 4 jugadores; los asientos libres los juega la CPU. Cada uno puede ponerse un nombre; el anfitrión elige el nivel de la CPU y un **tiempo por turno** opcional (30/60/90 s: al agotarse, el turno termina solo). Sin cuentas ni servidor propio: los móviles se conectan directamente entre sí por WebRTC (PeerJS), y el anfitrión reenvía las acciones.

Cada dispositivo corre la misma partida con la misma semilla y solo viajan las acciones, así que el juego sigue siendo un único archivo estático. Si un invitado desaparece, a los 12 segundos la CPU ocupa su asiento y la partida continúa; si vuelve a abrir el juego (botón `VOLVER A XXXX` en el menú, o el mismo enlace), el anfitrión le reenvía la partida, se reproduce al instante y recupera su asiento en su siguiente turno. Si se va el anfitrión, la partida termina.

## Tutorial

Botón `✦ TUTORIAL` en el menú. Es una partida real con mazo y rival amañados: cada paso enfoca una zona de la mesa y solo permite la acción que toca (colocar vida, ahorrar, bloquear con trébol, ataque combinado, crítico con suerte). Termina con una victoria de verdad y un repaso de dinero, figuras y comodines.

## Controles

- **Toque / clic** en una carta para jugarla, o **arrástrala** a tu mesa (ahorrar, colocar) o a una vida rival (atacar).
- Varios rayos y luego una vida = ataque combinado.
- Al apuntar, la **barra de la vida** enseña el trozo que caería; ☠ si es letal.
- **ESC** / clic derecho / botón `X`: cancela · **E**: fin de turno · **M**: sonido · **F**: pantalla completa · **H**: reglas · botón `1X/2X/4X`: velocidad.
- En móvil las figuras y comodines piden dos toques: el primero muestra su efecto.

## Efectos

Contador de daño que sube golpe a golpe y baja con el bloqueo ⛨, mira de anticipación, squash del impacto, golpe de cámara y cámara lenta al destruir, sellos (☠ ✦ ♥ ⛨), cartas que se deshacen en píxeles, duelo de críticos, partículas, vibración en móvil, sonidos sintetizados y una música ambiente generada por código que se tensa cuando te queda una vida (tecla **N** o botón ♪ para apagarla). Sonido, velocidad, nivel, nombre y estadísticas (partidas, victorias, racha) se guardan en el dispositivo.

## Parámetros de prueba (URL)

- `?rivals=1&seed=11`: salta el menú con semilla fija. `&ai=hard` fija el nivel; `&rules=2` juega con v2.
- `?rivals=1&seed=11&warp=9&cheat=1&mute=1`: salta 9 turnos y te da suerte y rayos para probar críticos.
- `?auto=1&speed=4`: la máquina juega por ti.
- `?selftest=200&players=2`: partidas de bots sin gráficos; imprime JSON con errores y comprueba que siempre hay 54 cartas. `&aimix=easy,hard` enfrenta niveles por asiento.
- `tools/test/`: arnés sin cabeza (capturas, emulación de móvil y partidas en línea reales entre dos pestañas). Ver su README.

## Estructura del repo

```
web/index.html          fuente del juego web (un solo archivo, sin dependencias)
index.html              versión publicada, generada por build.sh (añade manifest e iconos)
build.sh                genera index.html a partir de web/index.html
manifest.webmanifest    PWA: pantalla completa, apaisado
sw.js                   service worker: el juego abre sin conexión
icons/                  iconos de la app
love/                   versión de escritorio en Lua + LÖVE 11, pass-and-play (`cd love && love .`)
docs/                   manual v2 y diseños de los símbolos de la baraja
sim/                    simulaciones en Python usadas para equilibrar las reglas
tools/shot.sh           capturas e iconos
tools/test/             pruebas sin cabeza (drive.js, net.js)
```

Para publicar un cambio: edita `web/index.html`, ejecuta `sh build.sh` y haz push.

---

**Diseño del juego:** gavilanbe · **Código, arte y UX de la versión web con Claude Fable 5.1** · Licencia MIT
