-- IA de bots (port del nivel "normal" del bloque "IA" de web/index.html). Se usa en la
-- autoprueba (--selftest), en --autoplay y para las decisiones de v3 (revelar con la J, escudos, trampas).
local E = require("src.engine")
local bv, total, rem, isJoker = E.bv, E.total, E.rem, E.isJoker

local AI = {}
AI.level = "normal"   -- "normal" | "hard": en difícil la trampa admite un rayo más alto (≤ 8 en vez de ≤ 6)
local function aiHard() return AI.level == "hard" end

local function ri(G, n) return G.rnd(1, n) end   -- 1..n
-- una vida oculta que el rival ya vio (y que se ocultó después) se sigue conociendo (L.known)
local function lifeScore(L) return (L.up or L.known) and rem(L) or 8 end
local function filter(arr, f) local o = {}; for _, v in ipairs(arr) do if f(v) then o[#o + 1] = v end end; return o end
local function find(arr, f) for _, v in ipairs(arr) do if f(v) then return v end end end
local function some(arr, f) return find(arr, f) ~= nil end
local function has(arr, x) for _, v in ipairs(arr) do if v == x then return true end end; return false end
local function bestBy(arr, score)
  local b = nil
  for _, v in ipairs(arr) do if not b or score(v) > score(b) then b = v end end
  return b
end
local function sortBy(arr, key) table.sort(arr, function(a, b) return key(a) < key(b) end); return arr end

-- menor = más fácil de eliminar
local function oppScore(G, q)
  local X = G.players[q]
  local remTotal, ups = 0, 0
  for _, L in ipairs(X.lives) do remTotal = remTotal + lifeScore(L); if L.up then ups = ups + 1 end end
  return #X.lives * 20 + remTotal - ups * 3
end

local function aiTarget(G, p)
  local P = G.players[p]
  local function ok(q) return q ~= p and G.players[q].alive and #G.players[q].lives > 0 end
  local opp = {}
  for q = 1, G.n do if ok(q) then opp[#opp + 1] = q end end
  if #opp == 0 then P.tgt = nil; return nil end
  -- empates: el siguiente en la mesa; se queda con su objetivo salvo que otro esté claramente peor
  local function sc(q) return oppScore(G, q) + ((q - p + G.n) % G.n) * 2 - ((q == P.tgt) and 8 or 0) end
  local best = opp[1]
  for _, q in ipairs(opp) do if sc(q) < sc(best) then best = q end end
  P.tgt = best
  return best
end

-- mejor conjunto de rayos (hasta maxN cartas) cuya suma alcanza `need` con el menor desperdicio;
-- con `mult`, la carta más alta cuenta multiplicada
local function bestCombo(rays, need, maxN, mult)
  mult = mult or 1
  local n = #rays
  local best = nil
  for m = 1, (2 ^ n) - 1 do
    local k, sum, hi = 0, 0, 0
    for i = 1, n do
      if math.floor(m / 2 ^ (i - 1)) % 2 == 1 then k = k + 1; sum = sum + rays[i].r; if rays[i].r > hi then hi = rays[i].r end end
    end
    if k <= maxN then
      local v = sum + hi * (mult - 1)
      if v >= need then
        local waste = v - need
        if not best or waste < best.waste or (waste == best.waste and k < best.k) then best = { m = m, k = k, v = v, waste = waste } end
      end
    end
  end
  if not best then return nil end
  local cards = {}
  for i = 1, n do if math.floor(best.m / 2 ^ (i - 1)) % 2 == 1 then cards[#cards + 1] = rays[i] end end
  return { cards = cards, v = best.v, k = best.k, waste = best.waste }
end
AI.bestCombo = bestCombo

local function aiPickAttack(G, p, forced)
  local P = G.players[p]; local H = P.hand
  local t = aiTarget(G, p)
  if t == nil then return nil end
  local D = G.players[t]; local Ls = D.lives
  local m, lk = total(P.money), total(P.luck)
  local moves = G.moves
  local jn = find(H, function(c) return c.s == "JN" end)
  if not forced and jn then
    local l1 = bestBy(Ls, lifeScore)
    local act = { type = "jokerBlack", card = jn, t1 = { p = t, life = l1 } }
    local k = find(H, function(c) return c.s == "R" and c.r == 13 end)
    if k and moves >= 2 then
      local pool = {}
      if G.n == 2 or E.aliveCount(G) == 2 then
        for _, L in ipairs(Ls) do if L ~= l1 then pool[#pool + 1] = { p = t, life = L } end end
      else
        for q, X in ipairs(G.players) do
          if q ~= p and q ~= t and X.alive then for _, L in ipairs(X.lives) do pool[#pool + 1] = { p = q, life = L } end end
        end
      end
      if #pool > 0 then act.t2 = bestBy(pool, function(x) return lifeScore(x.life) end); act.k = k end
    end
    return act
  end
  local rays = sortBy(filter(H, function(c) return c.s == "R" end), function(c) return c.r end)
  if #rays == 0 then return nil end
  local up = sortBy(filter(Ls, function(L) return L.up or L.known end), rem)
  local down = filter(Ls, function(L) return not L.up and not L.known end)
  local low, high = rays[1], rays[#rays]
  local function atk(cards, life) return { type = "attack", cards = cards, targets = { { p = t, life = life } } } end
  local function pickDown() return down[1] end
  if forced then
    local need = (#up > 0) and rem(up[1]) or 8
    local mult = (G.pendingMult and G.pendingMult.kind == "money") and 2 or 1
    local c = bestCombo(rays, need, math.max(1, moves), mult)
    return atk(c and c.cards or { high }, (#up > 0) and up[1] or pickDown())
  end
  local K = find(rays, function(c) return c.r == 13 end)
  local function wardPen(L) return (G.v3 and L.ward) and 4 or 0 end
  -- 1) K repartida: dos vidas reveladas que caen a la vez (v3: con cualquier combo que incluya la K)
  if K and #up >= 2 then
    for i = 1, #up do for j = i + 1, #up do
      local a, b = rem(up[i]), rem(up[j])
      if a + b <= 13 then
        return { type = "attack", cards = { K }, targets = { { p = t, life = up[i], amount = a }, { p = t, life = up[j], amount = 13 - a } } }
      end
    end end
  end
  if G.v3 and K and #up >= 2 and moves >= 2 then
    for i = 1, #up do for j = i + 1, #up do
      local a, b = rem(up[i]) + wardPen(up[i]), rem(up[j]) + wardPen(up[j])
      local c = bestCombo(rays, a + b, moves)
      if c and has(c.cards, K) and c.k >= 2 then
        return { type = "attack", cards = c.cards, targets = { { p = t, life = up[i], amount = a }, { p = t, life = up[j], amount = c.v - a } } }
      end
    end end
  end
  -- 2) remate con el menor desperdicio (varias cartas si hay movimientos)
  local hasQ = some(rays, function(c) return c.r == 12 end)
  local kill = nil
  for _, L in ipairs(up) do
    local need = rem(L) + (hasQ and 0 or wardPen(L))
    local c = bestCombo(rays, need, moves)
    if c then
      local score = c.waste + c.k * 2
      if some(c.cards, function(x) return x.r == 14 end) then score = score - 6 end
      if some(c.cards, function(x) return x.r == 12 end) and (total(D.money) >= 10 or (G.v3 and L.ward)) then score = score - 3 end
      if some(c.cards, function(x) return x.r == 11 end) and (G.v3 and some(D.lives, function(X) return not X.up end) or (not G.v3 and total(D.luck) >= 10)) then score = score - 2 end
      if not kill or score < kill.score then kill = { L = L, c = c, score = score } end
    end
  end
  if kill then return atk(kill.c.cards, kill.L) end
  -- 3) multiplicador para rematar la vida más floja (dinero seguro antes que suerte)
  if moves >= 2 and #up > 0 then
    local L = up[1]; local need = rem(L)
    if high.r * 2 >= need then
      if m >= 20 then return { type = "money", tier = 2 } end
      if lk >= 10 then return { type = "luck", tier = (lk >= 20) and 2 or 1 } end
    elseif high.r * 3 >= need and lk >= 30 then
      return { type = "luck", tier = 3 }
    end
  end
  -- 4) sin remate: revela una vida oculta con un rayo bajo (evitando las que tienen algo debajo), o desgasta la más floja
  if #down > 0 then
    local safe = G.v3 and filter(down, function(L) return not L.ward end) or down
    local pool2 = (#safe > 0) and safe or down
    return atk({ (#rays > 1 and high.r >= 11) and low or high }, pool2[1])
  end
  if #up > 0 then return atk({ low }, up[1]) end
  return nil
end

-- v3: la J revela; elige la primera vida oculta del rival golpeado
function AI.peek(G, p, tp)
  local hid = filter(G.players[tp].lives, function(L) return not L.up end)
  if #hid == 0 then return nil end
  return hid[1]
end

-- jugadas propias de v3: ocultar, reordenar, escudo o trampa
local function aiV3(G, p)
  local P = G.players[p]; local H = P.hand; local m = total(P.money)
  local hidden = filter(P.lives, function(L) return not L.up end)
  local shown = filter(P.lives, function(L) return L.up end)
  -- reordenar justo después de ocultar, para que el rival pierda la pista
  if P.justHid and #hidden >= 2 and G.moves >= 1 and P.justHid.known and has(hidden, P.justHid) then
    local other = filter(hidden, function(L) return L ~= P.justHid end)
    local a = P.justHid; P.justHid = nil
    return { type = "swap", a = a, b = other[ri(G, #other)] }
  end
  P.justHid = nil
  -- ocultar una vida herida que aún vale la pena salvar
  if m >= 10 and G.moves >= 2 and #P.lives >= 2 and #hidden >= 1 then
    local cand = bestBy(filter(shown, function(L) return L.dmg > 0 and rem(L) >= 2 and rem(L) <= 6 and L.card.r >= 7 end), function(L) return L.card.r end)
    if cand then P.justHid = cand; return { type = "money", tier = 4, life = cand } end
  end
  -- bajo una vida: el rayo más bajo como trampa bajo una oculta gorda (si sobran rayos),
  -- un trébol sobrante como escudo bajo una revelada que aguanta
  local clubs = sortBy(filter(H, function(c) return c.s == "T" end), bv)
  local bolts = sortBy(filter(H, function(c) return c.s == "R" end), function(c) return c.r end)
  local keep = G.sudden and 0 or 1
  if G.moves >= 1 then
    local hv = bestBy(filter(hidden, function(L) return not L.ward and L.card.r >= 8 end), function(L) return L.card.r end)
    if hv and #bolts >= 2 and bolts[1].r <= (aiHard() and 8 or 6) then return { type = "ward", card = bolts[1], life = hv } end
    if #clubs > keep then
      local sv = bestBy(filter(shown, function(L) return not L.ward and rem(L) >= 5 end), rem)
      if sv then
        local c = find(clubs, function(c) return bv(c) >= 4 end) or clubs[#clubs]
        return { type = "ward", card = c, life = sv }
      end
    end
  end
  return nil
end

function AI.action(G, p)
  local P = G.players[p]; local H = P.hand; local m = total(P.money)
  if G.pendingMult then return aiPickAttack(G, p, true) or { type = "end" } end
  local heart = find(H, function(c) return c.s == "H" end)
  if heart then return { type = "place", card = heart } end
  local nrays = #filter(H, function(c) return c.s == "R" end)
  if G.v3 then
    local v = aiV3(G, p)
    if v and (v.type == "swap" or v.type == "money" or not E.canAttack(G, p) or nrays <= 1) then return v end
  end
  local jr = find(H, function(c) return c.s == "JR" end)
  local function bestCem() return bestBy(G.cem, function(c) return c.r end) end
  if jr and #G.cem > 0 then return { type = "jokerRed", card = jr, pick = bestCem() } end
  local danger = #P.lives <= math.max(2, P.startLives / 2)
  if m >= 30 and #G.cem > 0 and danger then return { type = "money", tier = 3, pick = bestCem() } end
  local pool = #G.deck + #G.discard
  if m >= 10 and pool > 0 and (#H <= 4 or (nrays == 0 and #H <= 6)) then return { type = "money", tier = 1 } end
  if E.canAttack(G, p) then
    local a = aiPickAttack(G, p, false)
    if a then return a end
  end
  if G.v3 then
    local v = aiV3(G, p)
    if v then return v end
  end
  if jr and #G.cem == 0 and #H <= 5 and pool > 1 then return { type = "jokerRed", card = jr, pick = nil } end
  local clubs = sortBy(filter(H, function(c) return c.s == "T" end), bv)
  local keep = G.sudden and 0 or 1   -- tréboles que se quedan en la mano como bloqueo
  if #clubs > keep then for _ = 1, keep do clubs[#clubs] = nil end else clubs = {} end
  local cand = filter(H, function(c) return c.s == "M" end)
  for _, c in ipairs(clubs) do cand[#cand + 1] = c end
  if #cand > 0 then return { type = "bank", card = bestBy(cand, bv) } end
  return { type = "end" }
end

function AI.defense(G, tp, val, L)
  local clubs = sortBy(filter(G.players[tp].hand, function(c) return c.s == "T" end), bv)
  if #clubs == 0 then return nil end
  local r = rem(L)
  if val >= r then return find(clubs, function(c) return val - bv(c) < r end) end   -- letal: el trébol más pequeño que la salve
  return nil
end

function AI.discard(G, p)
  local function w(c)
    if isJoker(c) or c.s == "H" then return 99 end
    if c.s == "M" then return bv(c) end
    if c.s == "T" then return bv(c) + 3 end
    return c.r + 6
  end
  local b = nil
  for _, c in ipairs(G.players[p].hand) do if not b or w(c) < w(b) then b = c end end
  return b
end

function AI.decide(G, p, kind, ctx)
  if kind == "turn" then return AI.action(G, p) end
  if kind == "defend" then return AI.defense(G, p, ctx.val, ctx.life) end
  if kind == "peek" then return AI.peek(G, p, ctx.tp) end
  return AI.discard(G, p)
end

return AI
