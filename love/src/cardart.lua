-- Dibujo procedural de cartas (frente, dorso, jokers) y palos vectoriales.
local CardArt = {}

local fonts = {}
local function F(sz)
  if not fonts[sz] then fonts[sz] = love.graphics.newFont(sz) end
  return fonts[sz]
end

local function rrect(mode, x, y, w, h, r) love.graphics.rectangle(mode, x, y, w, h, r or 8, r or 8) end

-- Polígono de corazón (centrado, apuntando hacia abajo).
local heartPts = {}
local function buildHeart()
  local steps = 44
  for i = 0, steps do
    local t = i / steps * math.pi * 2
    local x = 16 * math.sin(t) ^ 3
    local y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
    heartPts[#heartPts + 1] = x / 17
    heartPts[#heartPts + 1] = -y / 17
  end
end
buildHeart()

local function heartShape(cx, cy, s, flip)
  local out = {}
  for i = 1, #heartPts, 2 do
    out[#out + 1] = cx + heartPts[i] * s
    out[#out + 1] = cy + (flip and -heartPts[i + 1] or heartPts[i + 1]) * s
  end
  love.graphics.polygon("fill", out)
end

local function drawStar(cx, cy, s, rot, col, a)
  if col then love.graphics.setColor(col[1], col[2], col[3], a or 1) end
  local pts = {}
  for i = 0, 9 do
    local ang = (rot or 0) + i * math.pi / 5
    local r = (i % 2 == 0) and s or s * 0.45
    pts[#pts + 1] = cx + math.cos(ang) * r
    pts[#pts + 1] = cy + math.sin(ang) * r
  end
  love.graphics.polygon("fill", pts)
end

local function drawSuit(suit, cx, cy, s, col, a)
  love.graphics.setColor(col[1], col[2], col[3], a or 1)
  if suit == "hearts" then
    heartShape(cx, cy, s, false)
  elseif suit == "spades" then
    heartShape(cx, cy + s * 0.1, s, true)
    love.graphics.rectangle("fill", cx - s * 0.12, cy + s * 0.25, s * 0.24, s * 0.6)
    love.graphics.polygon("fill", cx - s * 0.35, cy + s * 0.95, cx + s * 0.35, cy + s * 0.95, cx, cy + s * 0.55)
  elseif suit == "diamonds" then
    love.graphics.polygon("fill", cx, cy - s * 1.15, cx + s * 0.82, cy, cx, cy + s * 1.15, cx - s * 0.82, cy)
  elseif suit == "clubs" then
    love.graphics.circle("fill", cx, cy - s * 0.5, s * 0.5)
    love.graphics.circle("fill", cx - s * 0.52, cy + s * 0.28, s * 0.5)
    love.graphics.circle("fill", cx + s * 0.52, cy + s * 0.28, s * 0.5)
    love.graphics.rectangle("fill", cx - s * 0.13, cy, s * 0.26, s * 0.9)
    love.graphics.polygon("fill", cx - s * 0.4, cy + s, cx + s * 0.4, cy + s, cx, cy + s * 0.45)
  end
end

local function jokerFace(card, w, h, a, col)
  love.graphics.setColor(col[1], col[2], col[3], a * 0.12)
  rrect("fill", -w / 2 + 5, -h / 2 + 5, w - 10, h - 10, 8)
  drawStar(0, -8, 24, love.timer and love.timer.getTime() * 1.5 or 0, col, a)
  drawStar(0, -8, 12, 0, { 1, 1, 1 }, a * 0.8)
  love.graphics.setFont(F(13))
  love.graphics.setColor(col[1], col[2], col[3], a)
  local lbl = "JOKER"
  love.graphics.print(lbl, -F(13):getWidth(lbl) / 2, h / 2 - 32)
  local sub = card.jokerColor == "red" and "ROJO" or "NEGRO"
  love.graphics.print(sub, -F(13):getWidth(sub) / 2, -h / 2 + 8)
end

local function frontFace(card, w, h, a)
  love.graphics.setColor(0.98, 0.97, 0.94, a)
  rrect("fill", -w / 2, -h / 2, w, h, 10)

  local col = card.red and { 0.85, 0.13, 0.2 } or { 0.12, 0.12, 0.16 }
  if card.isJoker then col = card.jokerColor == "red" and { 0.82, 0.1, 0.32 } or { 0.16, 0.16, 0.22 } end

  love.graphics.setColor(col[1], col[2], col[3], a)
  love.graphics.setLineWidth(2)
  rrect("line", -w / 2 + 2.5, -h / 2 + 2.5, w - 5, h - 5, 9)

  if card.isJoker then
    jokerFace(card, w, h, a, col)
    return
  end

  -- esquinas
  love.graphics.setFont(F(18))
  love.graphics.setColor(col[1], col[2], col[3], a)
  love.graphics.print(card.label, -w / 2 + 7, -h / 2 + 6)
  drawSuit(card.suit, -w / 2 + 15, -h / 2 + 40, 8, col, a)

  love.graphics.push()
  love.graphics.rotate(math.pi)
  love.graphics.setColor(col[1], col[2], col[3], a)
  love.graphics.print(card.label, -w / 2 + 7, -h / 2 + 6)
  drawSuit(card.suit, -w / 2 + 15, -h / 2 + 40, 8, col, a)
  love.graphics.pop()

  -- centro
  drawSuit(card.suit, 0, -26, 13, col, a)
  love.graphics.setFont(F(42))
  love.graphics.setColor(col[1], col[2], col[3], a)
  local fnt = F(42)
  love.graphics.print(card.label, -fnt:getWidth(card.label) / 2, -fnt:getHeight() / 2 + 8)
end

local function backFace(card, w, h, a)
  love.graphics.setColor(0.11, 0.15, 0.38, a); rrect("fill", -w / 2, -h / 2, w, h, 10)
  love.graphics.setColor(0.18, 0.26, 0.62, a); rrect("fill", -w / 2 + 6, -h / 2 + 6, w - 12, h - 12, 7)
  love.graphics.setColor(0.32, 0.42, 0.82, a); love.graphics.setLineWidth(2)
  rrect("line", -w / 2 + 12, -h / 2 + 12, w - 24, h - 24, 5)
  love.graphics.setColor(0.86, 0.78, 0.45, a); love.graphics.setLineWidth(2)
  love.graphics.circle("line", 0, 0, 18)
  love.graphics.setFont(F(24))
  love.graphics.setColor(0.92, 0.84, 0.5, a)
  love.graphics.print("S", -F(24):getWidth("S") / 2, -16)
end

function CardArt.draw(card)
  local w, h = card.w, card.h
  love.graphics.push()
  love.graphics.translate(card.x, card.y)
  love.graphics.rotate(card.rot or 0)
  local sc = card.scale or 1
  love.graphics.scale((card.flipScale or 1) * sc, sc)
  local a = card.alpha or 1

  love.graphics.setColor(0, 0, 0, 0.35 * a)
  rrect("fill", -w / 2 + 4, -h / 2 + 6, w, h, 10)

  if card.glow and card.glow > 0 then
    love.graphics.setColor(1, 0.95, 0.5, 0.55 * card.glow * a)
    rrect("fill", -w / 2 - 7, -h / 2 - 7, w + 14, h + 14, 14)
  end

  if card.faceUp then frontFace(card, w, h, a) else backFace(card, w, h, a) end

  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
end

CardArt.suit = drawSuit
CardArt.star = drawStar
return CardArt
