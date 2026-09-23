# Stratecorum — Manual v2 🃏

> Propuesta de revisión del manual original. Todo lo marcado **[v2]** es cambio o añadido mío; el resto es tu diseño original. Las reglas base están probadas con simulación (miles de partidas de bots, ver `sim/`); los módulos opcionales del final **no** están probados.

**Objetivo:** ser el último jugador con vidas (❤️ corazones) en la mesa. 🎯
**Jugadores:** 2 a 6. 👥
**Material:** la baraja propia del juego: 54 cartas, 4 palos de 13 y 2 comodines (dos barajas para 5–6 jugadores, ver abajo).

---

## 0. La baraja

Cuatro palos con símbolo y color propios. Cada símbolo dice para qué sirve la carta.

| Palo | Símbolo | Función | Color | Equivale en baraja francesa |
|---|---|---|---|---|
| **Corazones** | ❤️ corazón | Vidas | carmesí | ♥ corazones |
| **Rayos** | ⚡ rayo | Ataque | azul noche | ♠ picas |
| **Tréboles** | 🍀 trébol de cuatro hojas | Suerte (y defensa) | verde | ♣ tréboles |
| **Monedas** | 🪙 moneda | Dinero | ámbar | ♦ diamantes |

- Cada palo tiene 13 cartas: del 2 al 10 y cuatro figuras (J, Q, K, A; nombres propios pendientes).
- Las cartas llevan **impreso su valor real** (en corazones y rayos las figuras valen 11–14) y las figuras y comodines llevan **su efecto escrito**.
- Dos comodines: el **negro** y el **rojo** (nombres propios pendientes).
- Mientras no exista la baraja física se puede jugar con una baraja francesa usando la tabla de equivalencias.
- Dibujos de los símbolos: `docs/baraja/simbolos.html` (corazón V1, rayo A3, moneda D1) y `docs/baraja/simbolos_suerte.html` (trébol S4).

---

## 1. Valor de las cartas

| Carta | En ❤️ corazones y ⚡ rayos | En 🍀 tréboles y 🪙 monedas |
|---|---|---|
| 2–10 | su número | su número |
| J / Q / K / A | **11 / 12 / 13 / 14** [v2] | 10 |

[v2] Esto sustituye a "las figuras valen 10 con orden de prioridad": mismo resultado (una J no mata a una Q, un As mata a un K), pero sin casos dudosos (un 10 **no** mata a una J; un 5+6 **sí**).

En duelos de cartas (críticos): 2 < … < 10 < J < Q < K < A < Joker.

## 2. Preparación

1. Separa los 13 corazones y barájalos. Reparte vidas boca abajo según la tabla. Los corazones sobrantes se mezclan, sin mirarlos, en el mazo.
2. Cada jugador **puede mirar sus propias vidas** cuando quiera. [v2]
3. Reparte 5 cartas a cada jugador. El resto es el mazo de robo.
4. Jugador inicial al azar (carta más alta).

| Jugadores | Vidas por jugador | Barajas |
|---|---|---|
| 2 | 6 | 1 |
| 3 | 4 | 1 |
| 4 | 3 | 1 |
| 5–6 | 3 | **2** [v2] (los corazones sobrantes van al mazo) |

> Partida rápida de 5–6 con una sola baraja: 2 vidas cada uno. Funciona, pero es corta y brutal (~5 rondas) y el mazo se rebaraja casi cada ronda.

Zonas de cada jugador: vidas delante, **banco de suerte** a la izquierda, **banco de dinero** a la derecha. En el centro: mazo, descarte y **cementerio boca arriba** [v2].

## 3. El turno

1. **Roba 2 cartas.** [v2, antes 1]
2. Haz hasta **3 movimientos** (en cualquier orden, repitiendo si quieres):
   - ⚡ Atacar con una carta de rayos (o Joker negro).
   - 🍀 Ahorrar suerte: un trébol de tu mano a tu banco de suerte.
   - 🌟 Usar suerte (crítico).
   - 🪙 Ahorrar dinero: una moneda de tu mano a tu banco de dinero.
   - 💸 Usar dinero.
   - ❤️ Colocar una vida (corazón de tu mano, boca abajo). Al hacerlo puedes barajar tus vidas boca abajo para que nadie sepa cuál es cuál. [v2]
   - 🃏 Jugar el Joker rojo.
3. **Límite de mano: 7.** Si al acabar tienes más, descarta hasta 7. [v2]

**Arranque** [v2]:

> Desde septiembre de 2026 la web y la versión LÖVE usan la **apertura justa** también con v2: quien no empieza recibe 1 carta más y quien empieza tiene 3 movimientos desde el primer turno (ver [manual v3, §7](MANUAL_V3.md)).

- En su primer turno, el jugador inicial solo tiene **1 movimiento**.
- **Ronda de preparación:** durante la primera ronda nadie puede atacar.

**Mazo agotado** [v2]: se baraja el descarte y forma el nuevo mazo.

## 4. ⚡ Rayos: atacar

Juegas un rayo contra una vida rival. Si estaba boca abajo, se revela (y ya queda boca arriba).

- **El daño persiste** [v2]: si el ataque no la mata, el rayo **se queda debajo de esa vida** como daño acumulado. La vida muere cuando el daño total ≥ su valor. Al morir, la vida va al cementerio y las cartas que tenía debajo al descarte.
- Cada carta de ataque es un movimiento. Puedes repartir tus ataques entre varias vidas o rivales.
- **Ataque combinado** [v2]: puedes lanzar **varios rayos a la vez contra la misma vida**. Cuesta 1 movimiento por carta, sus valores se suman en un solo golpe y el defensor solo puede responder una vez, contra el total. Un multiplicador (suerte o dinero) se aplica **solo a la carta más alta** del combo. Los efectos de J, Q y A se activan si están en el combo y la vida cae; la K solo puede repartir su daño si se juega sola. Si la vida sobrevive, todas las cartas del combo se quedan debajo.

### 🛡️ Defensa con tréboles [v2]
Cuando atacan una vida tuya (después de revelarla), puedes **descartar un trébol de tu mano** para restar su valor al ataque (figuras = 10). El trébol se queda debajo de la vida, cruzado, restando daño al rayo que bloqueó.
- Máximo **una defensa por turno rival**.
- Se aplica después de los multiplicadores (un 8 con x2 = 16; con un trébol 6 entra 10).
- El Joker negro no se puede defender.

Esto crea el dilema central del trébol: ¿lo guardas en la mano como escudo o lo ahorras para críticos?

### Figuras de rayos
- **J (11):** si elimina la vida, roba las **2 cartas más altas** del banco de suerte de ese rival. [v2: antes "20 de suerte", que no cuadraba con cartas indivisibles]
- **Q (12):** igual, con el banco de dinero.
- **K (13):** puedes **repartir su daño como quieras entre dos vidas** (de uno o dos rivales). Declara el reparto antes de revelar. Un multiplicador se aplica antes de repartir.
- **A (14)** [v2]: es un ataque de 14. Si elimina la vida, **te la llevas a la mano** en lugar de ir al cementerio. (Antes mataba y robaba cualquier vida sin condiciones y sin respuesta; ahora se puede defender.)

### 🩸 Adrenalina y botín [v2]
- **Adrenalina:** cada vez que pierdes una vida, robas 1 carta.
- **Botín:** si eliminas la última vida de un jugador, te quedas sus dos bancos. Su mano va al descarte.

## 5. 🍀 Tréboles (de cuatro hojas): suerte

Ahorrar: 1 movimiento por carta, al banco de suerte. Usar suerte: 1 movimiento, y el siguiente movimiento debe ser el ataque al que se aplica.

**Crítico [v2]:** más suerte = más probabilidad, no un multiplicador inútil. Gastas suerte, volteas cartas del mazo y te quedas la mejor; el **defensor** voltea 1. Si tu mejor carta es **mayor o igual**, hay crítico. Las cartas volteadas van al descarte.

| Gastas | Volteas | Probabilidad | Efecto |
|---|---|---|---|
| 10 | 1 carta | ~52 % | x2 |
| 20 | 2 cartas | ~69 % | x2 |
| 30 | 3 cartas | ~77 % | **x3** |

Si fallas, la suerte se pierde y el ataque sale normal. Marca un rayo multiplicado que quede bajo una vida girándolo 90° (x2); para x3, añade debajo una carta cualquiera del descarte boca abajo como marcador.

## 6. 🪙 Monedas: dinero

Ahorrar y usar funcionan igual que la suerte (1 movimiento cada cosa).

| Gastas | Efecto |
|---|---|
| 10 | Roba **2** cartas. [v2, antes 3] |
| 20 | x2 seguro a tu siguiente ataque. |
| 30 | Elige **cualquier** vida del cementerio y colócala directamente en tu mesa, boca abajo. [v2, antes solo la última y a la mano] |

**Sin cambio** (suerte y dinero): pagas con cartas enteras de tu banco; si te pasas del precio, el exceso se pierde. No se pueden combinar dos multiplicadores sobre la misma carta.

## 7. 🃏 Comodines (jokers)

- **Joker negro:** elimina una vida cualquiera. No se puede defender. Con una **K** (2 movimientos): elimina **dos** vidas, pero de **rivales distintos** [v2] (con 2 jugadores, del mismo). Así no borra de golpe a un jugador con 2–3 vidas.
- **Joker rojo:** coge cualquier vida del cementerio y la coloca en tu mesa. Si el cementerio está vacío, puedes descartarlo para robar 2 cartas [v2], así nunca es carta muerta.

## 8. ⏳ Final de partida y reloj [v2]

Quedas eliminado cuando no te quedan vidas en la mesa. Gana el último en pie.

Para que ninguna partida se eternice (y para castigar al que acapara cartas):
- **Muerte súbita:** a partir del **4.º rebaraje** del mazo ya no se puede defender con tréboles.
- **Reloj:** si hay que rebarajar por **7.ª vez**, la partida termina: gana quien tenga más vidas; si hay empate, quien sume más valor restante en sus vidas.
- Si alguien debe robar y no hay cartas ni en mazo ni en descarte, se aplica el reloj en ese momento.

(Con 5–6 jugadores y una sola baraja usa 8.º y 16.º rebaraje.)

---

## 9. Qué cambia respecto a v1 y por qué (datos de simulación)

> v1 se jugaba con baraja francesa; aquí "rayos" son las antiguas picas y "monedas" los diamantes.

Miles de partidas por configuración con bots de estrategia razonable pero simple. Son órdenes de magnitud, no verdades exactas.

| Problema en v1 | Dato | Arreglo v2 | Resultado |
|---|---|---|---|
| El mazo se agota y no hay regla | 89–100 % de partidas no pueden terminar | Rebarajar descarte + reloj | 0 % atascadas |
| Daño desperdiciado (fallos a ciegas + exceso) | ~55 % del valor de los rayos no hace nada | Daño persistente | ~26 % |
| 3 movimientos pero 1 carta por turno | "10 → roba 3" obligatorio (8 usos/partida); el resto del dinero casi sin uso | Robar 2 por turno; 10 → roba 2; vida a elegir | Comprar vida pasa de 0,2 a 1,8 usos/partida (2j); 0–1 % de movimientos sin usar |
| x3 / x4 redundantes; crítico ~37 % sin importar lo invertido | Un 7 con x2 ya mata cualquier vida | Suerte = probabilidad (52/69/77 %) | Crítico ~65 % de éxito medio |
| El defensor no decide nada | 0 decisiones fuera de tu turno | Defensa con tréboles (1 por turno rival) | 10–13 defensas por partida |
| Jugadores eliminados antes de jugar | 0,18 (4j), 0,52 (5j), 0,91 (6j) por partida | Ronda de preparación | 0 |
| Ventaja del que empieza | 51/49 a 56/44 en 2j según el bot (el primero puede atacar 3 veces antes de que el otro juegue) | Primer turno con 1 movimiento + ronda de preparación + adrenalina | 51/49 (2j), 24–27 % por asiento (4j) |
| Partidas que no acaban si alguien acapara rayos | Muy dependiente del bot: de ~0 % a 29 % con un jugador pasivo en 4j (y el daño persistente lo empeora, porque deja rayos atrapados bajo las vidas) | Límite de mano + muerte súbita + reloj | Siempre termina; el pasivo gana ~10 % (de un 25 % justo) |
| As / K+Joker sin contrajuego | K+Joker elimina a un jugador entero en 4–6j | As = ataque 14 defendible; K+Joker a rivales distintos | — |

**Duración (rondas, mediana / percentil 90):** 2j 12/16 · 3j 9/12 · 4j 7/9 · 5j (2 barajas) 16/20 · 6j (2 barajas) 14/18.

**Lo que NO queda resuelto del todo:** robar cartas sigue siendo el mejor uso *puro* del dinero. Bots que solo hacen una cosa contra el que solo compra cartas: solo-vidas gana 35 %, solo-x2 28 %; el bot mixto queda en 41 % contra el de cartas, pero gana 55–67 % contra los otros dos. Es decir: ya no hay una estrategia tramposa, pero las cartas siguen mandando un poco. Si en mesa se nota, el siguiente ajuste sería 10 → roba 2 **y descarta 1**.

La defensa alarga la partida: en las pruebas con robo de 1 carta, 2j pasaba de 10 rondas sin defensa a 17 con defensa ilimitada. El tope de una por turno rival, el robo de 2 y la adrenalina la dejan en 12.

---

## 10. Módulos opcionales (ideas, **sin probar**)

**A. Guardianes** — las figuras de corazón tienen un poder la primera vez que se revelan y sobreviven:
- J de corazones, Centinela: robas 1 carta.
- Q de corazones, Tesorera: ahorras gratis 1 moneda o trébol de tu mano.
- K de corazones, Baluarte: los tréboles que la defienden valen +3.
- A de corazones, Mártir: cuando muere, quien la mató descarta 1 carta al azar.

**B. Torneo (2 jugadores)** — al mejor de 3, alternando quién empieza; el perdedor de cada partida elige quién empieza la siguiente. Desempate de torneo: vidas restantes acumuladas del ganador.

**C. Equipos 2v2** — compañeros sentados en alterno. Puedes gastar tu defensa de trébol en una vida de tu compañero. Gana el equipo que elimina a los dos rivales. El botín va al que da el golpe final.

**D. Mercado** — 3 cartas boca arriba junto al mazo. Por 10 de dinero, en vez de robar 2 a ciegas, te llevas 1 del mercado a elegir (se repone del mazo). Menos azar, más planificación.
