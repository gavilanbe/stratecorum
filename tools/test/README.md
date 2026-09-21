# Pruebas sin cabeza

Requiere Node y Google Chrome instalado. Instala el driver una vez:

```
cd tools/test && npm init -y >/dev/null && npm i puppeteer-core@22
```

**Motor y pantallas** (`drive.js`): abre `web/index.html` con parámetros, ejecuta pasos separados por `§` (`w:ms` espera, `c:x,y` clic en coordenadas del lienzo 384×216, `h:x,y` hover, `d:x1,y1,x2,y2` arrastre, `e:js` evalúa, `k:js` clic en las coordenadas que devuelve el js, `f:archivo` evalúa un archivo, `s:nombre` captura en `shots/`).

```
node drive.js "?selftest=300&players=2&mute=1" "w:20000§ e:document.getElementById('out').textContent"
node drive.js "?rivals=1&seed=11&warp=9&cheat=1&mute=1" "w:4500§ c:205,190§ w:300§ c:170,45§ w:2500§ s:ataque"
MOB=1 node drive.js "?mute=1" "w:1000§ s:movil"          # emulación de iPhone apaisado (MOB=p vertical)
```

**En línea** (`net.js`): dos pestañas (anfitrión + invitado) juegan una partida completa a través del servidor público de PeerJS, decidiendo con la IA por cada humano, y comparan el estado final.

```
node net.js                      # 2 jugadores
THREE=1 node net.js              # 3 jugadores + 1 CPU
LEAVE=1 node net.js              # el invitado cierra a los 25 s; la CPU ocupa su asiento
LEAVE=1 REJOIN=1 node net.js     # ... y vuelve a entrar 16 s después
FILE=https://gavilanbe.github.io/stratecorum/index.html node net.js   # contra la web publicada
```
