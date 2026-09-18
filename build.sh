#!/bin/sh
cd "$(dirname "$0")"

# Lee el index.html original y inyecta manifest + iconos antes de </head>
{
  # Lee desde el inicio hasta antes de </style>
  sed -n '1,/<\/style>/p' < web/index.html
  
  # Inyecta manifest, iconos y meta
  cat <<'H'

<link rel="manifest" href="manifest.webmanifest">
<link rel="icon" type="image/png" sizes="192x192" href="icons/icon-192.png">
<link rel="apple-touch-icon" sizes="180x180" href="icons/icon-180.png">
<meta name="apple-mobile-web-app-title" content="Stratecorum">
<meta name="description" content="Baraja estratégica de turnos: domina corazón, rayo, trébol y moneda. Juego de cartas táctico en pixel art para móvil y web.">
H
  
  # Lee desde </style> hasta </head>
  sed -n '/<\/style>/,/<\/head>/p' < web/index.html | tail -n +2
  
  # Lee el resto del body
  sed -n '/<\/head>/,$p' < web/index.html | tail -n +2
} > index.html
echo "index.html: $(wc -c < index.html) bytes"
