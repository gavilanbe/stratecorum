-- IA de bots (port del bloque "IA" de web/index.html). Se usa en la autoprueba (--selftest).
local E = require("src.engine")
local bv, total, rem, isJoker = E.bv, E.total, E.rem, E.isJoker

local AI = {}

local function ri(G, n) return G.rnd(1, n) end   -- 1..n
local function lifeScore(L) return L.up and rem(L) or 8 end
local function filter(arr, f) local o = {}; for _, v in ipairs(arr) do if f(v) then o[#o + 1] = v end end; return o end
local function find(arr, f) for _, v in ipairs(arr) do if f(v) then return v end end end
local function bestBy(arr, score)
  local b = nil
  for _, v in ipairs(arr) do if not b or score(v) > score(b) then b = v end end
  return b
end

local function aiTarget(G, p)
  local P = G.players[p]
  local function ok(q) return q ~= p and G.players[q].alive and #G.players[q].lives > 0 end
  if P.tgt == nil or not ok(P.tgt) then
    local opp = {}
    for q = 1, G.n do if ok(q) then opp[#opp + 1] = q end end
    P.tgt = (#opp > 0) and opp[ri(G, #opp)] or nil
  end
  return P.tgt
end

local function aiPickAttack(G, p, forced)
  local P = G.players[p]; local H = P.hand
  local t = aiTarget(G, p)
  if t == nil then return nil end
  local Ls = G.players[t].lives
  local m, lk = total(P.money), total(P.luck)
  local jn = find(H, function(c) return c.s == "JN" end)
  if not forced and jn then
    local l1 = bestBy(Ls, lifeScore)
    local act = { type = "jokerBlack", card = jn, t1 = { p = t, life = l1 } }
    local k = find(H, function(c) return c.s == "R" and c.r == 13 end)
    if k and G.moves >= 2 then
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
  local rays = filter(H, function(c) return c.s == "R" end)
  table.sort(rays, function(a, b) return a.r < b.r end)
  if #rays == 0 then return nil end
  local up = filter(Ls, function(L) return L.up end)
  table.sort(up, function(a, b) return rem(a) < rem(b) end)
  local down = filter(Ls, function(L) return not L.up end)
  local best = rays[#rays]
  local function atk(card, life) return { type = "attack", cards = { card }, targets = { { p = t, life = life } } } end
  if forced then return atk(best, (#up > 0) and up[1] or down[ri(G, #down)]) end
  for _, L in ipairs(up) do
    local c = find(rays, function(c) return c.r >= rem(L) end)
    if c then return atk(c, L) end
  end
  if G.moves >= 2 and #up > 0 then
    local L = up[1]
    if best.r * 2 >= rem(L) then
      if m >= 20 then return { type = "money", tier = 2 } end
      if lk >= 10 then return { type = "luck", tier = (lk >= 30) and 3 or ((lk >= 20) and 2 or 1) } end
    elseif best.r * 3 >= rem(L) and lk >= 30 then
      return { type = "luck", tier = 3 }
    end
  end
  if #down > 0 and (best.r >= 8 or #up == 0) then return atk(best, down[ri(G, #down)]) end
  if #up > 0 then return atk(best, up[1]) end
  return nil
end

function AI.action(G, p)
  local P = G.players[p]; local H = P.hand; local m = total(P.money)
  if G.pendingMult then return aiPickAttack(G, p, true) or { type = "end" } end
  local heart = find(H, function(c) return c.s == "H" end)
  if heart then return { type = "place", card = heart } end
  local jr = find(H, function(c) return c.s == "JR" end)
  local function bestCem() return bestBy(G.cem, function(c) return c.r end) end
  if jr and #G.cem > 0 then return { type = "jokerRed", card = jr, pick = bestCem() } end
  if m >= 30 and #G.cem > 0 and #P.lives <= P.startLives / 2 then return { type = "money", tier = 3, pick = bestCem() } end
  if m >= 10 and #H <= 4 and (#G.deck + #G.discard) > 0 then return { type = "money", tier = 1 } end
  if E.canAttack(G, p) then
    local a = aiPickAttack(G, p, false)
    if a then return a end
  end
  if jr and #G.cem == 0 and #H <= 5 and (#G.deck + #G.discard) > 1 then return { type = "jokerRed", card = jr, pick = nil } end
  local clubs = filter(H, function(c) return c.s == "T" end)
  table.sort(clubs, function(a, b) return bv(a) < bv(b) end)
  if not G.sudden and #clubs > 0 then clubs[#clubs] = nil end   -- se guarda el mejor trébol como escudo
  local cand = filter(H, function(c) return c.s == "M" end)
  for _, c in ipairs(clubs) do cand[#cand + 1] = c end
  if #cand > 0 then return { type = "bank", card = bestBy(cand, bv) } end
  return { type = "end" }
end

function AI.defense(G, tp, val, L)
  if val < rem(L) then return nil end
  local clubs = filter(G.players[tp].hand, function(c) return c.s == "T" end)
  table.sort(clubs, function(a, b) return bv(a) < bv(b) end)
  return find(clubs, function(c) return val - bv(c) < rem(L) end)
end

function AI.discard(G, p)
  local function score(c) if isJoker(c) or c.s == "H" then return 99 end return c.r end
  local b = nil
  for _, c in ipairs(G.players[p].hand) do if not b or score(c) < score(b) then b = c end end
  return b
end

function AI.decide(G, p, kind, ctx)
  if kind == "turn" then return AI.action(G, p) end
  if kind == "defend" then return AI.defense(G, p, ctx.val, ctx.life) end
  return AI.discard(G, p)
end

return AI
