-- Cartas de Stratecorum v2 sobre baraja francesa.
-- Palos del motor: H (corazones = vidas), R (rayos = ♠ picas), T (tréboles = ♣ suerte/defensa),
-- M (monedas = ♦ dinero), JN (joker negro), JR (joker rojo).
-- `r` es el valor real: 2..10 y J/Q/K/A = 11/12/13/14 (en tréboles y monedas valen 10 al ahorrar).
local Deck = {}
local CARDW, CARDH = 86, 122

local LET = { [11] = "J", [12] = "Q", [13] = "K", [14] = "A" }
local SUITNAME = { H = "hearts", R = "spades", T = "clubs", M = "diamonds" }

local function defaults(c)
  c.x, c.y = 0, 0
  c.w, c.h = CARDW, CARDH
  c.rot, c.scale, c.flipScale, c.alpha = 0, 1, 1, 1
  c.faceUp, c.glow, c._lift = false, 0, 0
  c._z = 1
  return c
end

-- makeCard("R", 13, id) → K de rayos; makeCard("JN", 0, id) → joker negro.
function Deck.makeCard(s, r, id)
  if s == "JN" or s == "JR" then
    return defaults({
      id = id, s = s, r = 0, suit = "joker", label = "JOKER", value = 0,
      isJoker = true, jokerColor = (s == "JR") and "red" or "black", red = (s == "JR"),
    })
  end
  return defaults({
    id = id, s = s, r = r, suit = SUITNAME[s], label = LET[r] or tostring(r),
    value = math.min(r, 10), red = (s == "H" or s == "M"), isJoker = false,
  })
end

function Deck.shuffle(t, rnd)
  rnd = rnd or ((love and love.math) and love.math.random or math.random)
  for i = #t, 2, -1 do
    local j = rnd(1, i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end

Deck.LET = LET
Deck.CARDW, Deck.CARDH = CARDW, CARDH
return Deck
