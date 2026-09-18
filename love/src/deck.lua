-- Construcción del mazo francés + jokers, y reparto de vidas (corazones).
local Deck = {}
local CARDW, CARDH = 86, 122

local function rankInfo(rank)
  if rank == 1 then return "A", 10, 14
  elseif rank == 11 then return "J", 10, 11
  elseif rank == 12 then return "Q", 10, 12
  elseif rank == 13 then return "K", 10, 13
  else return tostring(rank), rank, rank end
end

local function defaults(c)
  c.x, c.y = 0, 0
  c.w, c.h = CARDW, CARDH
  c.rot, c.scale, c.flipScale, c.alpha = 0, 1, 1, 1
  c.faceUp, c.glow, c._lift = false, 0, 0
  c._z = 1
  return c
end

function Deck.makeCard(suit, rank)
  local label, value, priority = rankInfo(rank)
  return defaults({
    suit = suit, rank = rank, label = label, value = value, priority = priority,
    red = (suit == "hearts" or suit == "diamonds"), isJoker = false,
  })
end

function Deck.makeJoker(color)
  return defaults({
    suit = "joker", rank = 99, label = "JOKER", value = 999, priority = 999,
    isJoker = true, jokerColor = color, red = (color == "red"),
  })
end

local function rnd(a, b)
  if love and love.math then return love.math.random(a, b) end
  return math.random(a, b)
end

function Deck.shuffle(t)
  for i = #t, 2, -1 do
    local j = rnd(1, i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end

-- Devuelve (mazoDeRobo, vidasCorazon)
function Deck.build(numPlayers, livesEach)
  local hearts = {}
  for r = 1, 13 do hearts[#hearts + 1] = Deck.makeCard("hearts", r) end
  Deck.shuffle(hearts)

  local need = numPlayers * livesEach
  local lifeHearts = {}
  for _ = 1, need do
    local c = table.remove(hearts)
    if c then lifeHearts[#lifeHearts + 1] = c end
  end

  local draw = {}
  for _, suit in ipairs({ "spades", "diamonds", "clubs" }) do
    for r = 1, 13 do draw[#draw + 1] = Deck.makeCard(suit, r) end
  end
  for _, h in ipairs(hearts) do draw[#draw + 1] = h end  -- corazones sobrantes al mazo
  draw[#draw + 1] = Deck.makeJoker("red")
  draw[#draw + 1] = Deck.makeJoker("black")
  Deck.shuffle(draw)

  return draw, lifeHearts
end

Deck.CARDW, Deck.CARDH = CARDW, CARDH
return Deck
