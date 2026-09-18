#!/bin/sh
# Captura screenshot del juego para iconos y artifacts
cd "$(dirname "$0")/.."

# Chrome headless screenshot para icono (384x216, juego original)
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --headless=new \
  --screenshot=artifacts/screenshot.png \
  --window-size=384,216 \
  file://$(pwd)/index.html?auto=1&speed=4

# Genera iconos a partir de la screenshot
if command -v sips >/dev/null 2>&1; then
  # 192x192
  sips -z 192 192 artifacts/screenshot.png -o icons/icon-192.png >/dev/null 2>&1
  # 512x512
  sips -z 512 512 artifacts/screenshot.png -o icons/icon-512.png >/dev/null 2>&1
  # 512x512 maskable (igual que regular)
  sips -z 512 512 artifacts/screenshot.png -o icons/icon-maskable-512.png >/dev/null 2>&1
  echo "Iconos generados: icons/icon-{192,512}.png y icon-maskable-512.png"
else
  echo "sips no disponible; necesitas instalar macOS utils"
fi
