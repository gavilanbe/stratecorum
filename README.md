# Stratecorum 🃏

**Jugar:** https://gavilanbe.github.io/stratecorum/

Juego de cartas estratégico con baraja propia (corazón, rayo, trébol de cuatro hojas y moneda). Gana el último con vidas ♥ en la mesa. Todo el arte, la fuente, la música y los sonidos se generan por código.

Modos: **contra la CPU** (1–3 rivales, tres niveles), **reto diario** (misma semilla para todos, CPU difícil, racha), **pasar y jugar** (2–4 personas en el mismo aparato) y **en línea** (cada uno en su móvil). En español o inglés (botón en el menú). Funciona en móvil (apaisado, mano y botones grandes al tocar, instalable como app, también sin conexión) y en escritorio.

## Cómo se juega

Cada turno robas 2 cartas y haces **3 movimientos** (1 carta = 1 movimiento). En la primera ronda nadie ataca; **quien no empieza recibe 1 carta más al repartir** (6 en vez de 5). Mano máxima: 7.

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
- **Escudo o trampa**: una carta boca abajo bajo una vida tuya. Un trébol es un escudo (resta su valor al golpe); un rayo es una trampa (salta y golpea al atacante con su valor). Nadie sabe cuál es.
- **K acumulativa**: cualquier combo con K se reparte entre dos vidas. **Suerte 30**: el x3 va a todo el combo.
- **J revela** una vida oculta al golpear · **Q desarma** escudos y trampas y roba del banco más rico · **A** roba la vida. En un combo, los efectos se suman.
- **Dinero 10**: roba 2 y descarta 1, u ocultar.

## La máquina

Tres niveles, elegibles en el menú. **Fácil** elige rival al azar y no combina. **Normal** ataca al rival más cerca de caer, remata con el combo de menor desperdicio, reparte la K entre dos vidas, planifica multiplicadores y guarda un trébol para bloquear. **Difícil** además compra cartas en cuanto puede, paga más suerte por más probabilidad, deja margen contra un bloqueo cuando sale barato y bloquea golpes grandes a vidas valiosas. En simulación, difícil gana algo más que normal en mesas de tres; contra bots la diferencia es pequeña, contra personas se nota más.

## Pasar y jugar

Menú → `PASAR Y JUGAR` → 2, 3 o 4 personas. Entre turnos aparece una pantalla que tapa la mesa hasta que el siguiente toca; cuando atacan a alguien y puede bloquear, también se le pasa el aparato para que elija.

## Jugar en línea (varios móviles)

Botón `● ONLINE` en el menú. Uno **crea la sala** y comparte el código de 4 letras (o el enlace `?sala=CÓDIGO` con el botón Compartir); los demás **se unen con el código**. Hasta 4 jugadores; los asientos libres los juega la CPU. Cada uno puede ponerse un nombre; el anfitrión elige el nivel de la CPU y un **tiempo por turno** opcional (30/60/90 s: al agotarse, el turno termina solo). Sin cuentas ni servidor propio: los móviles se conectan directamente entre sí por WebRTC (PeerJS), y el anfitrión reenvía las acciones.

Cada dispositivo corre la misma partida con la misma semilla y solo viajan las acciones, así que el juego sigue siendo un único archivo estático. Si un invitado desaparece, a los 20 segundos la CPU ocupa su asiento y la partida continúa; si vuelve a abrir el juego (botón `VOLVER A XXXX` en el menú, o el mismo enlace), el anfitrión le reenvía la partida, se reproduce al instante y recupera su asiento en su siguiente turno. Si cae el **anfitrión**, el jugador humano con el asiento más bajo hereda la sala y los demás se reconectan a él solos; el antiguo anfitrión puede volver como cualquier otro.

## Tutorial

Botón `✦ TUTORIAL` en el menú (lleva la marca ¡NUEVO! hasta que lo haces). Es una partida real con mazo y rival amañados, guiada por **el Rey**: un cuadro con su retrato, que habla mientras el texto se escribe letra a letra (un toque lo completa). Va por **8 capítulos** con barra de progreso (la mesa, prepara tu mesa, ataca, defiéndete, trampas y escudos, oculta y reordena, suerte y remate, lo que falta); cada paso enfoca con un foco que se desplaza la zona de la mesa y solo permite la acción que toca, y **una mano animada enseña el gesto** (toca aquí, arrastra allá). Cada acierto se celebra (¡BIEN!, ¡ESO ES!…) y cada capítulo superado también. Termina con una victoria de verdad, rematando con el rayo 6 tras un crítico, y un repaso de dinero, figuras y comodines.

## Reto diario y repeticiones

`✦ RETO DIARIO`: cada día la misma partida para todos (semilla por fecha) contra la CPU difícil; se guarda si la ganaste, en cuántos turnos y la racha, y se puede compartir el resultado. Al acabar cualquier partida local, el botón `REPETICIÓN` copia un enlace que reproduce la partida entera (semilla más acciones; no necesita servidor).

## Controles

- **Título**: el logo cae letra a letra y lo golpea un rayo; tocar durante la intro la salta. Las cartas del abanico se dan la vuelta al tocarlas. Con teclado: **flechas** para moverse por el menú y **Enter** para pulsar.
- **Toca una carta** y se levanta mostrando sus acciones (colocar, ahorrar, escudo, guardar...); o **arrástrala** a tu mesa, a una vida tuya (escudo o trampa) o a una vida rival (atacar).
- Varios rayos y luego una vida = ataque combinado.
- Al apuntar, la **barra de la vida** enseña el trozo que caería; ☠ si es letal.
- **ESC** / clic derecho / botón `X`: cancela · **E**: fin de turno · **M**: sonido · **F**: pantalla completa · **H**: reglas · botón `1X/2X/4X`: velocidad.
- **Con una carta levantada, toca su destino**: tu mesa (♥ vida nueva), tu banco (♣ suerte, ● dinero) o, con un trébol, una vida tuya (⛨ escudo). Sigue valiendo el menú de la carta.
- **Reglas** (`REGLAS` en el menú, botón `?` o tecla **H**): 7 páginas ilustradas; flechas o tocar para pasar, ESC para cerrar.
- **Toca tu montón de suerte o de dinero** para abrir su menú; al señalar una opción se levantan las cartas que pagarías.
- **Mantén pulsado** (o **Espacio**) mientras juegan los demás: todo va a x3 hasta que sueltas.
- **1–9**: toca esa carta de tu mano · **Enter** con una carta levantada: su acción principal.
- En móvil las figuras y comodines piden dos toques: el primero muestra su efecto.

## Efectos

**Cartas**: cabecera del color del palo con el valor en cifras gruesas y la ficha del palo; ventana teñida con el dibujo sombreado (corazón, rayo, trébol y moneda con volumen y brillo); figuras con retratos de 16×16 y marco dorado (las de rayo llevan la insignia ✦ de efecto especial); comodines propios (calavera de bufón y llama) y dorso con celosía y medallón dorado. Figuras y comodines destellan de vez en cuando. **Gastar suerte o dinero**: las cartas pagadas vuelan al centro en abanico, se funden con un destello y su poder viaja a su destino (los rayos, que quedan cargados y brillan hasta lanzarlos; el mazo; el cementerio; la vida que ocultas). Cruzar 10, 20 o 30 en tu banco se celebra.

**Movimiento fluido**: el lienzo se dibuja a la resolución de la pantalla (hasta 4 píxeles por píxel de arte), así el arte sigue nítido en su rejilla mientras las cartas se mueven y giran a sub-píxel. La mano va en abanico y respira; las cartas se inclinan al volar y hacia el ratón, brillan al robarlas, revelarlas o pasar por encima, y aterrizan con peso (aplastan y levantan polvo). Las monedas y tréboles ahorrados vuelan hasta el contador del banco; las casillas de movimiento se encienden una a una; el menú de la carta sube al aparecer; transición tramada entre pantallas; el cartel final cae con rebote (fuegos artificiales si ganas, ceniza si pierdes); los botones se hunden y destellan al pulsarlos; temblor de cámara continuo. La máquina piensa menos entre jugadas y tus cartas llegan mientras pasa el cartel de turno.

**Ataque por fases**: el rayo se carga (vibra, chisporrotea y absorbe chispas mientras un foco oscurece la mesa alrededor de la vida apuntada), toma impulso y golpea con un rayo ramificado; los golpes fuertes traen además un rayo del cielo, fotograma de impacto, líneas de velocidad y empujón de cámara hacia el golpe. La vida golpeada se tambalea y suelta astillas y humo; cada carta de un combo muestra COMBO X2, X3... El crítico pinta los rayos de oro y la trampa de rojo. **Destrucción**: la carta se parte en trozos que giran, explosión de píxeles, brasas, franjas de cine y ¡DESTRUIDA! (o ¡ROBADA! con la A). El escudo es una burbuja que desvía el rayo en chispas. Las vidas muy tocadas humean; los rayos elegidos chisporrotean y un arco eléctrico une la mano con la vida apuntada. Mesa con luz central y rayos que caen sobre el título.

Retratos de píxel para J, Q, K y A. Contador de daño que sube golpe a golpe (con fichas +N por carta) y baja con el bloqueo ⛨, mira de anticipación, cartas que saltan en arco al cambiar de zona y se inclinan al tocarlas o arrastrarlas, zona de destino iluminada al arrastrar, squash del impacto, chispa doble, viñeta roja al recibir daño, golpe de cámara y cámara lenta al destruir, sellos (☠ ✦ ♥ ⛨ ◎), cartas que se deshacen en píxeles, duelo de críticos, partículas, vibración en móvil, sonidos sintetizados y una música ambiente generada por código que se tensa cuando te queda una vida (tecla **N** o botón ♪ para apagarla). Sonido, velocidad, nivel, nombre y estadísticas (partidas, victorias, racha) se guardan en el dispositivo.

## Parámetros de prueba (URL)

- `?rivals=1&seed=11`: salta el menú con semilla fija. `&ai=hard` fija el nivel; `&rules=2` juega con v2; `&lang=en` en inglés; `?replay=…` reproduce una partida compartida; `?icon=1` dibuja el icono de la app.
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
love/                   versión de escritorio en Lua + LÖVE 11, pass-and-play, reglas v2 y v3 (`cd love && love .`)
docs/                   manual v2 y diseños de los símbolos de la baraja
sim/                    simulaciones en Python usadas para equilibrar las reglas
tools/shot.sh           capturas e iconos
tools/test/             pruebas sin cabeza (drive.js, net.js)
```

Para publicar un cambio: edita `web/index.html`, ejecuta `sh build.sh` y haz push.

---

**Diseño del juego:** gavilanbe · **Código, arte y UX de la versión web con Claude Fable 5.1** · Licencia MIT
