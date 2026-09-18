# Stratecorum

**Jugar:** https://gavilanbe.github.io/stratecorum/

Baraja estratégica de turnos: domina corazón, rayo, trébol de cuatro hojas y moneda. Juego de cartas táctico en pixel art para móvil y web. Todo el arte, la fuente y los sonidos se generan por código.

## Reglas

Tú contra 1–3 rivales controlados por la máquina. Cada turno robas 1 carta y tienes **3 movimientos**.

- **♥ Corazones (Vida)**: colocas una nueva vida boca abajo en tu zona.
- **⚡ Rayos (Ataque)**: elige la carta y luego una vida rival. El daño se acumula; si ≥ al valor de la vida, va al cementerio.
  - **J**: si elimina, roba 20 de suerte al rival.
  - **Q**: si elimina, roba 20 de dinero al rival.
  - **K**: divide el ataque entre 2 vidas.
  - **A**: elimina y roba la vida a tu mano.
- **♣ Trébol (Suerte)**: suma su valor al banco de suerte (izquierda). Intenta crítico (J+Q+K+A: x2, x3, x4, x5). Si tu carta es mayor que la del rival, se aplica.
- **💰 Moneda (Dinero)**: suma su valor al banco de dinero (derecha). Gastos: 10 → roba 3 cartas, 20 → x2 a tu próximo ataque, 30 → compra última vida del cementerio.
- **Comodines**: Negro = ataque sin valor (elimina cualquiera); Rojo = recupera vida del cementerio.

## Controles

- **Clic o arrastrar cartas**: a la mesa para ahorrar/colocar, a una vida rival para atacar.
- **Varios rayos** + clic en vida = ataque combinado.
- **ESC** / clic derecho: cancela.
- **E**: fin de turno.
- **M**: sonido.
- **F**: pantalla completa.
- **H**: ayuda.
- Botón `1X/2X/4X`: velocidad.
- **Tutorial** (botón en menú): partida amañada que enseña cada mecánica paso a paso.

## Juice

- **Lenguaje visual**: barra de vida con previsualización (trozo que cae parpadea; ☠ si letal), contador de daño, mira roja de anticipación, sellos en vez de rótulos (☠ ✦ ♥ ⛨).
- **Animaciones**: repartir, robar, flips de cartas, squash de impacto, golpe de cámara y cámara lenta al destruir, explosiones, partículas, monedas.
- **Sonidos**: sintetizados en tiempo real (música, efectos de cartas, impactos, críticos).
- **Lienzo**: 384×216 escalado a múltiplos enteros; soporta móvil con rotación y AudioContext tras gesto.

## Parámetros de prueba (URL)

- `?rivals=1&seed=11`: salta menú con semilla fija.
- `?auto=1&speed=4`: la máquina juega sola.
- `?selftest=200&players=2`: partidas de bots sin gráficos (comprueba integridad).
- `?warp=9&cheat=1&mute=1`: salta turnos, dinero/suerte, sin sonido.

---

**Diseño del juego:** gavilanbe · **Código, arte y UX de la versión web con Claude Fable 5.1**
