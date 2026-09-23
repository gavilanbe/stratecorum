-- STRATECORUM — juego de cartas, reglas v2 y v3 (LÖVE 11.x)
-- 2 a 6 jugadores, pass-and-play. Todo dibujado por código. El menú elige las reglas (S.rules → G.v3).
-- El motor de reglas vive en src/engine.lua y corre en una corrutina: cede el control
-- con {wait}, {decide} y {pass}; la vista sincroniza la posición de cada carta desde el estado lógico.

local flux  = require("lib.tween")
local Deck  = require("src.deck")
local Card  = require("src.cardart")
local PFX   = require("src.particles")
local Audio = require("src.audio")
local E     = require("src.engine")

local CW, CH = Deck.CARDW, Deck.CARDH
local VW, VH = 1280, 800

local DECK_POS    = { x = VW / 2 - 230, y = VH / 2 - 6 }
local DISCARD_POS = { x = VW / 2,        y = VH / 2 - 6 }
local GRAVE_POS   = { x = VW / 2 + 230,  y = VH / 2 - 6 }

local LEFT_X, RIGHT_X, BTN_W, BTN_H = 30, VW - 230, 200, 38
local BTN_Y1, BTN_Y2 = VH - 118, VH - 72
local PROB = { "~52%", "~69%", "~77%" }

local bv, total, rem = E.bv, E.total, E.rem

-- Estado de la aplicación (S) y de la partida (G, lo crea el motor)
local S = { state = "boot", scale = 1, offx = 0, offy = 0, t = 0, speed = 1, viewer = 1, log = {}, floats = {}, shake = 0, rules = 3 }
local G = nil
local UI = { mode = "none", selList = {}, t1 = nil, t2 = nil, alloc = 7, menu = nil, ctx = nil, hoverLife = nil }

----------------------------------------------------------------------
-- Utilidades
----------------------------------------------------------------------
local fonts = {}
local function F(sz)
  if not fonts[sz] then fonts[sz] = love.graphics.newFont(sz) end
  return fonts[sz]
end
local function lerp(a, b, t) return a + (b - a) * t end
local function clamp(v, a, b) return v < a and a or (v > b and b or v) end
local function rrect(m, x, y, w, h, r) love.graphics.rectangle(m, x, y, w, h, r or 8, r or 8) end
local function pointIn(px, py, x, y, w, h) return px >= x and px <= x + w and py >= y and py <= y + h end
local function toVirtual(mx, my) return (mx - S.offx) / S.scale, (my - S.offy) / S.scale end
local function printC(text, y, w) love.graphics.printf(text, 0, y, w or VW, "center") end
local function has(arr, x) for _, v in ipairs(arr) do if v == x then return true end end return false end
local function rmv(arr, x) for i, v in ipairs(arr) do if v == x then table.remove(arr, i) return true end end return false end

-- El log del motor usa símbolos que la fuente por defecto no tiene: se traducen a palabras.
local SYM = { ["⚡"] = "ataca", ["♣"] = "trébol", ["●"] = "moneda", ["♥"] = "", ["☠"] = "", ["✦"] = "", ["►"] = "->", ["⛨"] = "", ["◎"] = "" }
local function plain(s)
  for k, v in pairs(SYM) do s = s:gsub(k, v) end
  return (s:gsub("^%s+", ""):gsub("%s%s+", " "))
end

local function say(msg, color, t)
  S.message = msg; S.messageColor = color or { 1, 1, 1 }; S.messageT = t or 2.6
end

local function addLog(s)
  S.log[#S.log + 1] = s
  if #S.log > 7 then table.remove(S.log, 1) end
end

local function float(x, y, text, color, big)
  S.floats[#S.floats + 1] = { x = x, y = y, text = text, color = color or { 1, 1, 1 }, t = 1.3, big = big }
end

local function moveCard(card, x, y, t, opts)
  opts = opts or {}
  if card._mv then flux.stop(card._mv) end
  local tw = flux.to(card, t or 0.4, { x = x, y = y, rot = opts.rot or card.rot, scale = opts.scale or card.scale })
  tw:ease(opts.ease or "quadout")
  if opts.delay then tw:delay(opts.delay) end
  if opts.oncomplete then tw:oncomplete(opts.oncomplete) end
  card._mv = tw
  return tw
end

local function flip(card, faceUp, t)
  t = t or 0.13
  if card._fl then flux.stop(card._fl) end
  card._fl = flux.to(card, t, { flipScale = 0 }):ease("quadin"):oncomplete(function()
    card.faceUp = faceUp
    card._fl = flux.to(card, t, { flipScale = 1 }):ease("quadout")
  end)
end

local function afterDelay(t, fn)
  local d = { v = 0 }
  flux.to(d, t, { v = 1 }):oncomplete(fn)
end

local function lifePos(L) return L.card._tgt or L.card end
local function cardHit(c, x, y)
  local w, h = c.w * (c.scale or 1), c.h * (c.scale or 1)
  return x >= c.x - w / 2 and x <= c.x + w / 2 and y >= c.y - h / 2 and y <= c.y + h / 2
end

----------------------------------------------------------------------
-- Layout: asientos según quién mira la pantalla (S.viewer)
----------------------------------------------------------------------
local function computeSeats()
  local v = S.viewer or 1
  local opp = {}
  for k = 1, G.n do if k ~= v then opp[#opp + 1] = k end end
  G.players[v]._lay = {
    owner = "me", cx = VW / 2, handY = VH - 78, livesY = VH - 226, handScale = 1, width = 800, dir = -1,
    luckX = 110, luckY = VH - 152, moneyX = VW - 110, moneyY = VH - 152, bankW = 160, bankScale = 0.4, bankDy = -54,
    nameX = 170, nameY = VH - 266, nameW = 330,
  }
  local slotW = VW / #opp
  for i, pi in ipairs(opp) do
    local cx = slotW * (i - 0.5)
    local bw = clamp(slotW / 2 - 10, 90, 160)
    G.players[pi]._lay = {
      owner = "opp", cx = cx, handY = 52, livesY = 214, handScale = 0.5, width = slotW - 20, dir = 1,
      luckX = cx - bw / 2 - 4, luckY = 112, moneyX = cx + bw / 2 + 4, moneyY = 112, bankW = bw, bankScale = 0.28, bankDy = 0,
      nameX = cx, nameY = 4, nameW = slotW, slotW = slotW,
    }
  end
end

local function handTargets(P)
  local lay = P._lay
  local n = #P.hand
  if n == 0 then return {} end
  local sc = lay.handScale
  local spacing = math.min(CW * sc + 14, lay.width / n)
  local startx = lay.cx - (n - 1) * spacing / 2
  local out = {}
  for i = 1, n do out[i] = { x = startx + (i - 1) * spacing, y = lay.handY } end
  return out
end

local function liveTargets(P)
  local lay = P._lay
  local n = #P.lives
  if n == 0 then return {} end
  local spacing = math.min(CW + 12, lay.width / n)
  local startx = lay.cx - (n - 1) * spacing / 2
  local out = {}
  for i = 1, n do out[i] = { x = startx + (i - 1) * spacing, y = lay.livesY } end
  return out
end

local function cemGrid(i, n)
  local perRow = 9
  local rows = math.ceil(n / perRow)
  local row = math.floor((i - 1) / perRow)
  local inRow = math.min(perRow, n - row * perRow)
  local col = (i - 1) % perRow
  local spacing = 96
  local x = VW / 2 - (inRow - 1) * spacing / 2 + col * spacing
  local y = VH / 2 - 10 - (rows - 1) * 66 + row * 132
  return x, y
end

-- Sincroniza la posición/cara/z de cada carta con el estado lógico del motor.
local syncStagger = nil
local function put(c, x, y, o)
  local scale, rot = o.scale or 1, o.rot or 0
  c._z = o.z or c._z
  c._overlay = o.overlay or false
  local tg = c._tgt
  if not tg or math.abs(tg.x - x) > 0.5 or math.abs(tg.y - y) > 0.5 or tg.scale ~= scale or tg.rot ~= rot then
    c._tgt = { x = x, y = y, scale = scale, rot = rot }
    if S.animate then
      local delay = nil
      if syncStagger and (math.abs(c.x - x) + math.abs(c.y - y) > 20) then delay = syncStagger.n * 0.045; syncStagger.n = syncStagger.n + 1 end
      moveCard(c, x, y, o.t or 0.38, { scale = scale, rot = rot, delay = delay, ease = o.ease })
    else
      if c._mv then flux.stop(c._mv) end
      c.x, c.y, c.scale, c.rot = x, y, scale, rot
    end
  end
  local fu = o.faceUp and true or false
  if c._faceTgt ~= fu then
    c._faceTgt = fu
    if S.animate then flip(c, fu) else c.faceUp = fu; c.flipScale = 1 end
  end
end

local function syncBoard()
  if not G then return end
  computeSeats()
  local reveal = (S.state == "playing" or S.state == "gameover")
  for i, c in ipairs(G.deck) do
    local k = math.min(i, 40)
    put(c, DECK_POS.x - k * 0.25, DECK_POS.y - k * 0.25, { faceUp = false, z = 1 + i * 0.001 })
  end
  for i, c in ipairs(G.discard) do
    if not c._jx then c._jx = (love.math.random() - 0.5) * 12; c._jy = (love.math.random() - 0.5) * 10; c._jr = (love.math.random() - 0.5) * 0.45 end
    put(c, DISCARD_POS.x + c._jx, DISCARD_POS.y + c._jy, { faceUp = true, z = 9 + i * 0.001, rot = c._jr })
  end
  local cemOverlay = (UI.mode == "cem")
  for i, c in ipairs(G.cem) do
    if cemOverlay then
      local x, y = cemGrid(i, #G.cem)
      put(c, x, y, { faceUp = true, z = 60 + i * 0.01, overlay = true })
    else
      local k = math.min(i, 12)
      put(c, GRAVE_POS.x + (k - 1) * 3, GRAVE_POS.y - (k - 1) * 1.5, { faceUp = true, z = 8 + i * 0.001 })
    end
  end
  for p, P in ipairs(G.players) do
    local lay = P._lay
    local ht = handTargets(P)
    local showHand = (p == S.viewer) and reveal
    for i, c in ipairs(P.hand) do
      put(c, ht[i].x, ht[i].y, { faceUp = showHand, z = 20 + i * 0.01, scale = lay.handScale })
    end
    local lt = liveTargets(P)
    for i, L in ipairs(P.lives) do
      put(L.card, lt[i].x, lt[i].y, { faceUp = L.up or ((p == S.viewer) and reveal), z = 14 + i * 0.001 })
      if L.ward then   -- carta boca abajo asomando por debajo de la vida (todos la ven; qué es, solo el dueño)
        put(L.ward.card, lt[i].x - 16, lt[i].y + lay.dir * 4, { faceUp = false, z = 13.5 + i * 0.001, rot = -0.14 })
      end
      for j, a in ipairs(L.att) do
        local peek = (j <= 3) and 14 * j or (42 + (j - 3) * 5)   -- las primeras asoman 14 px; el resto se comprime
        put(a, lt[i].x, lt[i].y + lay.dir * peek, { faceUp = true, z = 13.9 - j * 0.01 })
      end
    end
    for _, bank in ipairs({ { P.luck, lay.luckX, lay.luckY }, { P.money, lay.moneyX, lay.moneyY } }) do
      local list, bx, by = bank[1], bank[2], bank[3]
      local n = #list
      for i, c in ipairs(list) do
        if lay.owner == "me" then
          put(c, bx + (i - (n + 1) / 2) * 9, by + lay.bankDy, { faceUp = true, z = 15 + i * 0.01, scale = lay.bankScale })
        else
          local fan = (lay.bankW >= 130) and math.min(7, 60 / math.max(n, 1)) or 0
          local x0 = (lay.bankW >= 130) and (bx - lay.bankW / 2 + 92) or bx
          put(c, x0 + (i - 1) * fan, by, { faceUp = true, z = 15 + i * 0.01, scale = lay.bankScale })
        end
      end
    end
  end
  for _, c in ipairs(G.limbo) do
    local L = c._life
    if L then
      local lp = lifePos(L)
      local owner = G.players[c._tp]
      local dir = owner and owner._lay.dir or 1
      local n, slot = c._n or 1, c._slot or 0
      put(c, lp.x + (slot - (n - 1) / 2) * 34, lp.y + dir * 46, { faceUp = true, z = 40 + slot * 0.01, scale = 1.08, rot = (slot - (n - 1) / 2) * 0.08, t = 0.3 })
    else
      put(c, DISCARD_POS.x, DISCARD_POS.y, { faceUp = true, z = 40 })
    end
  end
  if G.duel then
    local D = G.duel
    for i, c in ipairs(D.a) do
      put(c, VW / 2 - 160 - (D.tier - 1) * 50 + (i - 1) * 100, VH / 2 - 20, { faceUp = c._shown, z = 61 + i * 0.01, scale = 1.15, overlay = true })
    end
    for i, c in ipairs(D.d) do
      put(c, VW / 2 + 160, VH / 2 - 20, { faceUp = c._shown, z = 61.5, scale = 1.15, overlay = true })
    end
  end
end

----------------------------------------------------------------------
-- Corrutina del juego: hooks del motor
----------------------------------------------------------------------
local fxQueue = {}
local function queueFx(fn) fxQueue[#fxQueue + 1] = fn end
local function runFxQueue()
  local q = fxQueue; fxQueue = {}
  for _, fn in ipairs(q) do fn() end
end

local hooks = {}
function hooks.wait(s) coroutine.yield({ kind = "wait", t = s }) end
local function pass(p, why) coroutine.yield({ kind = "pass", p = p, why = why }) end
function hooks.decide(p, kind, ctx)
  if kind == "defend" and p ~= G.cur then   -- una trampa la bloquea el atacante, que ya tiene el equipo: sin pasar
    pass(p, "defend")
    local a = coroutine.yield({ kind = "decide", dkind = "defend", p = p, ctx = ctx })
    pass(ctx.from, "back")
    return a
  end
  return coroutine.yield({ kind = "decide", dkind = kind, p = p, ctx = ctx })
end
function hooks.log(s) addLog(plain(s)); say(plain(s), { 1, 1, 1 }, 2.2) end

local SFX = { play = "attack", duel = "select", draw = "deal" }
hooks.fx = {
  sfx = function(name) Audio.play(SFX[name] or name) end,
  banner = function(text, p, dur) S.banner = { text = plain(text), t = dur or 1.2, total = dur or 1.2 }; Audio.play(text:find("ELIMINADO") and "destroy" or "turn") end,
  fxShuffle = function() Audio.play("deal"); PFX.deal(DECK_POS.x, DECK_POS.y); say("Rebaraje " .. G.reshuffles .. "/7", { 1, 0.9, 0.6 }) end,
  fxDraw = function(c, p) Audio.play("deal"); PFX.deal(DECK_POS.x, DECK_POS.y) end,
  fxKill = function(L, steal) local c = L.card; PFX.destroy(c.x, c.y); Audio.play("destroy"); S.shake = 10; S.hit = nil end,
  fxElim = function(tp) Audio.play("destroy") end,
  fxReveal = function(c) Audio.play("select") end,
  fxSuspense = function() end,
  fxCrit = function(ok) if ok then PFX.crit(VW / 2, VH / 2 - 20); Audio.play("crit") else Audio.play("error") end end,
  fxAim = function(L) S.aim = { L = L, t = 0.6 } end,
  hitIncoming = function(L, val) S.incoming = { L = L, val = val } end,
  hitStart = function(L, mult) S.hit = { L = L, v = 0, t = 1.4, mult = mult } end,
  fxStrike = function(card, L, contrib, i, nonzero, joker)
    local c = L.card
    PFX.hit(c.x, c.y); Audio.play(joker and "destroy" or "hit"); S.shake = math.max(S.shake, joker and 8 or 5)
    if S.hit and S.hit.L == L then S.hit.v = S.hit.v + (contrib or 0); S.hit.t = 1.4 end
    if joker then float(c.x, c.y - 40, "X", { 1, 0.3, 0.3 }, true) end
  end,
  fxShield = function(L, blocked, val)
    local c = L.card; PFX.luck(c.x, c.y); Audio.play("luck")
    float(c.x, c.y - 60, "Bloqueo -" .. blocked, { 0.5, 1, 0.6 }, true)
    if S.hit and S.hit.L == L then S.hit.v = val; S.hit.t = 1.4 end
  end,
  fxDamage = function(L, val) local c = L.card; float(c.x + 30, c.y - 20, "-" .. val, { 1, 0.5, 0.4 }, true) end,
  fxSteal = function(p, kind, k)
    local lay = G.players[p]._lay
    if kind == "T" then PFX.luck(lay.luckX, lay.luckY) else PFX.coins(lay.moneyX, lay.moneyY) end
    Audio.play("coin")
  end,
  fxPlace = function(card) queueFx(function() local t = card._tgt or card; PFX.heal(t.x, t.y); Audio.play("life") end) end,
  fxBank = function(card, streak)
    queueFx(function()
      local t = card._tgt or card
      if card.s == "T" then PFX.luck(t.x, t.y); Audio.play("luck") else PFX.coins(t.x, t.y); Audio.play("coin") end
    end)
  end,
  fxPay = function(cards) Audio.play("coin"); PFX.coins(DISCARD_POS.x, DISCARD_POS.y) end,
  fxRevive = function(card) queueFx(function() local t = card._tgt or card; PFX.heal(t.x, t.y); Audio.play("life") end) end,
  fxTurn = function(p) Audio.play("turn") end,
  -- v3
  fxWardPlace = function(L) queueFx(function() local t = L.card._tgt or L.card; PFX.luck(t.x - 16, t.y + 10); Audio.play("luck") end) end,
  fxWard = function(L, kind, n, wardCard, attacker)
    local c = L.card
    if kind == "shield" then
      PFX.luck(c.x, c.y); Audio.play("luck"); float(c.x, c.y - 70, "Escudo -" .. n, { 0.5, 1, 0.6 }, true)
      if S.hit and S.hit.L == L then S.hit.v = math.max(0, S.hit.v - n); S.hit.t = 1.4 end
      if S.autoplay then S.autoShotWant = "escudo" end
    elseif kind == "trap" then   -- el rayo de debajo salta y golpea al atacante
      PFX.destroy(c.x, c.y); Audio.play("destroy"); S.shake = 8
      local A = G.players[attacker]
      float(c.x, c.y - 70, "¡TRAMPA! El rayo " .. E.cname(wardCard) .. " salta", { 1, 0.4, 0.35 }, true)
      S.trap = { card = wardCard, t = 3.2, txt = "trampa: golpea a " .. A.name }
      say("¡Trampa! El rayo " .. E.cname(wardCard) .. " (" .. n .. ") salta contra " .. A.name, { 1, 0.55, 0.45 }, 3.2)
      if S.autoplay then S.autoShotWant = "trampa" end
    else
      Audio.play("click"); float(c.x, c.y - 70, "La Q desarma " .. (wardCard.s == "R" and "la trampa" or "el escudo"), { 0.85, 0.85, 0.9 }, true)
      if S.autoplay then S.autoShotWant = "desarma" end
    end
  end,
  fxHide = function(L) local c = L.card; PFX.deal(c.x, c.y); Audio.play("select"); float(c.x, c.y - 70, "Oculta (daño " .. L.dmg .. ")", { 0.6, 0.75, 1 }, true); if S.autoplay then S.autoShotWant = "ocultar" end end,
  fxSwap = function(a, b) Audio.play("deal"); PFX.deal(a.card.x, a.card.y); PFX.deal(b.card.x, b.card.y); if S.autoplay then S.autoShotWant = "reordenar" end end,
  fxPeek = function(L, p)   -- la J revela la vida para todos
    local c = L.card; PFX.crit(c.x, c.y); Audio.play("crit")
    float(c.x, c.y - 70, "J revela: vida " .. c.r, { 1, 0.9, 0.4 }, true)
    if S.autoplay then S.autoShotWant = "revela" end
  end,
}

local function turnHint()
  local P = G.players[G.cur]
  if P.turns == 0 and G.cur == G.first and not G.fair then return "Primer turno: solo 1 movimiento. En la primera ronda no se ataca." end
  if P.turns == 0 then return G.fair and "Primera ronda: no se ataca. Quien no empieza recibió 1 carta más." or "Primera ronda: no se puede atacar todavía." end
  return nil
end

local function setupDecision(req)
  UI.selList = {}; UI.t1 = nil; UI.t2 = nil; UI.menu = nil; UI.ctx = req.ctx; UI.alloc = 7
  if req.dkind == "turn" then
    UI.mode = "idle"
    if not S.hinted or S.hinted ~= (G.cur .. ":" .. G.players[G.cur].turns) then
      S.hinted = G.cur .. ":" .. G.players[G.cur].turns
      local h = turnHint()
      if h then say(h, { 1, 0.9, 0.6 }, 3.5) end
    end
  elseif req.dkind == "defend" then
    UI.mode = "defend"; Audio.play("select")
  elseif req.dkind == "peek" then
    UI.mode = "peek"; Audio.play("select")
    say("J revela: tocá una vida oculta de " .. G.players[req.ctx.tp].name .. " para darle la vuelta (la ven todos)", { 1, 0.9, 0.5 }, 4)
  else
    UI.mode = "discard"
    if req.ctx and req.ctx.why == "pay" then say("Dinero 10: robaste 2, ahora tocá la carta que descartás", { 1, 0.85, 0.6 }, 4)
    else say("Límite de mano 7: tocá una carta para descartarla", { 1, 0.85, 0.6 }, 4) end
  end
end

local function pump()
  local co = S.co
  if not co or coroutine.status(co) == "dead" then return end
  while true do
    local ok, req = coroutine.resume(co, S.resumeValue)
    S.resumeValue = nil
    if not ok then error(tostring(req) .. "\n" .. debug.traceback(co)) end
    if coroutine.status(co) == "dead" then S.req = nil; syncBoard(); runFxQueue(); return end
    S.req = req
    if req.kind == "pass" then S.state = "passing" end
    if req.kind == "decide" then S.state = "playing"; setupDecision(req) end
    syncBoard(); runFxQueue()
    if req.kind == "wait" then
      if req.t > 0 then S.waitT = req.t; return end
    else
      return
    end
  end
end

local function answer(a)
  if not S.req or S.req.kind ~= "decide" then return end
  S.resumeValue = a
  S.req = nil
  UI.mode = "none"; UI.selList = {}; UI.t1 = nil; UI.t2 = nil; UI.menu = nil
  pump()
end

local function runGame()
  hooks.wait(1.1 + G.n * 0.35)
  while not G.over do
    local p = G.cur
    pass(p, "turn")
    E.playTurn(G, p)
    if G.over then break end
    E.nextPlayer(G)
  end
  hooks.wait(1.6)
  S.state = "gameover"; S.banner = nil; S.message = nil
  Audio.play("win"); PFX.crit(VW / 2, VH / 2)
end

local function startNewGame(n)
  flux.clear(); PFX.clear()
  S.log = {}; S.floats = {}; S.message = nil; S.banner = nil; S.hit = nil; S.aim = nil; S.incoming = nil; S.hinted = nil; S.trap = nil
  G = E.newGame(n, hooks, { v3 = (S.rules == 3) })
  for _, c in ipairs(G.allCards) do
    c.x, c.y = DECK_POS.x, DECK_POS.y; c.faceUp = false; c._faceTgt = false; c._tgt = nil; c.scale = 1; c.rot = 0
  end
  S.viewer = G.first
  S.state = "dealing"
  S.animate = true
  syncStagger = { n = 0 }
  syncBoard()
  syncStagger = nil
  afterDelay(0.3, function() Audio.play("deal") end)
  S.co = coroutine.create(runGame)
  pump()
end

----------------------------------------------------------------------
-- Interfaz: reglas de qué se puede tocar
----------------------------------------------------------------------
local function me() return G.players[S.viewer] end
local function selSum() local s = 0; for _, c in ipairs(UI.selList) do s = s + c.r end; return s end
local function selTotal()
  local hi = 0
  for _, c in ipairs(UI.selList) do if c.r > hi then hi = c.r end end
  local m = (G.pendingMult and G.pendingMult.kind == "money") and 2 or 1
  return selSum() + hi * (m - 1)
end
local function validTargets()
  local out = {}
  if not E.canAttack(G, S.viewer) then return out end   -- (v3: un rayo seleccionado solo para trampa no tiene objetivos rivales)
  for p, P in ipairs(G.players) do
    if p ~= S.viewer and P.alive then for _, L in ipairs(P.lives) do out[#out + 1] = { p = p, life = L } end end
  end
  return out
end
local function secondTargets(first, forJoker)
  local out = {}
  for _, t in ipairs(validTargets()) do
    if t.life ~= first.life and (not forJoker or (E.aliveCount(G) == 2 or t.p ~= first.p)) then out[#out + 1] = t end
  end
  return out
end
local function handHas(P, s) for _, c in ipairs(P.hand) do if c.s == s then return c end end end
local function findK(P) for _, c in ipairs(P.hand) do if c.s == "R" and c.r == 13 then return c end end end

local function deciding(kind) return S.req and S.req.kind == "decide" and (not kind or S.req.dkind == kind) end

local function luckOptions()
  local P = me(); local lk = total(P.luck)
  local ok = E.canAttack(G, S.viewer) and G.moves >= 2 and handHas(P, "R") and not G.pendingMult
  local out = {}
  for t = 1, 3 do
    out[t] = { tier = t, label = (t * 10) .. " · voltea " .. t .. (t > 1 and " cartas" or " carta") .. " · x" .. (t == 3 and 3 or 2) .. " · " .. PROB[t],
               en = ok and lk >= t * 10 }
  end
  return out
end
local function moneyOptions()
  local P = me(); local m = total(P.money)
  local atk = E.canAttack(G, S.viewer) and G.moves >= 2 and handHas(P, "R") and not G.pendingMult
  local out = {
    { tier = 1, label = G.v3 and "10 · robar 2 cartas y descartar 1" or "10 · robar 2 cartas", en = m >= 10 and not G.pendingMult },
  }
  if G.v3 then
    local anyUp = false
    for _, L in ipairs(P.lives) do if L.up then anyUp = true end end
    out[#out + 1] = { tier = 4, label = "10 · ocultar una vida revelada (el daño se conserva en secreto)", en = m >= 10 and not G.pendingMult and anyUp }
  end
  out[#out + 1] = { tier = 2, label = "20 · próximo rayo x2 seguro", en = m >= 20 and atk }
  out[#out + 1] = { tier = 3, label = "30 · revivir una vida del cementerio", en = m >= 30 and #G.cem > 0 and not G.pendingMult }
  return out
end
-- v3: cualquier combo con K se reparte entre dos vidas sobre la suma de los rayos; v2: solo la K sola (13)
local function selHasK() for _, c in ipairs(UI.selList) do if c.s == "R" and c.r == 13 then return true end end return false end
local function kTotal() return G.v3 and selSum() or 13 end
local function canSplit() return #UI.selList > 0 and UI.selList[1].s ~= "JN" and (G.v3 and selHasK() or (#UI.selList == 1 and UI.selList[1].r == 13)) end
local function selCards() local out = {}; for i, c in ipairs(UI.selList) do out[i] = c end; return out end
-- vidas propias que aceptan un trébol debajo / que se pueden ocultar / ocultas (para reordenar)
local function ownLives(f) local out = {}; for _, L in ipairs(me().lives) do if f(L) then out[#out + 1] = L end end; return out end
local function wardable() return ownLives(function(L) return not L.ward end) end
-- v3: se puede poner un rayo como trampa (1 movimiento, sin multiplicador pendiente, alguna vida sin nada debajo)
local function canTrap() return G.v3 and G.moves >= 1 and not G.pendingMult and #wardable() > 0 end
-- v3: el rayo seleccionado (solo) que se podría poner de trampa
local function trapCard() if canTrap() and #UI.selList == 1 and UI.selList[1].s == "R" then return UI.selList[1] end end
local function hiddenOwn() return ownLives(function(L) return not L.up end) end
local function peekable()
  local out = {}
  if UI.mode ~= "peek" or not UI.ctx then return out end
  for _, L in ipairs(G.players[UI.ctx.tp].lives) do if not L.up then out[#out + 1] = L end end
  return out
end

local function playable(c)
  if UI.mode == "defend" then return c.s == "T" end
  if UI.mode == "discard" then return true end
  if UI.mode ~= "idle" and UI.mode ~= "target" then return false end
  if G.pendingMult then return c.s == "R" end
  if c.s == "R" or c.s == "JN" then
    if E.canAttack(G, S.viewer) and (has(UI.selList, c) or #UI.selList < G.moves) then return true end
    return c.s == "R" and canTrap() and (has(UI.selList, c) or #UI.selList == 0)   -- v3: solo para ponerlo de trampa
  end
  return G.moves >= 1
end
local function whyNot(c)
  if G.pendingMult and c.s ~= "R" then return "Ahora toca lanzar un rayo" end
  if c.s == "R" or c.s == "JN" then
    if me().turns == 0 then return "En la primera ronda no se ataca" end
    if not E.canAttack(G, S.viewer) then return "No hay objetivos" end
    return "No te quedan movimientos para más cartas"
  end
  return "Ahora no"
end

local function clearSel() UI.selList = {}; UI.t1 = nil; UI.t2 = nil end
local function cancel()
  if UI.mode == "defend" or UI.mode == "peek" then return answer(nil) end
  if UI.mode == "none" or UI.mode == "discard" then return end
  UI.mode = "idle"; clearSel(); UI.menu = nil; UI.ctx = nil
  syncBoard()
end

local function selectRay(c)
  if c.s == "JN" then UI.selList = { c }
  else
    for i = #UI.selList, 1, -1 do if UI.selList[i].s == "JN" then table.remove(UI.selList, i) end end
    UI.selList[#UI.selList + 1] = c
  end
  UI.mode = "target"; UI.t1 = nil; UI.t2 = nil
  Audio.play("select")
end

local function clickHand(c)
  if UI.mode == "defend" then
    if c.s == "T" then Audio.play("luck"); return answer(c) end
    Audio.play("error"); return say("Elegí un trébol (o pasá)", { 1, 0.7, 0.6 })
  end
  if UI.mode == "discard" then Audio.play("deal"); return answer(c) end
  if UI.mode ~= "idle" and UI.mode ~= "target" then return end
  if c.s == "R" or c.s == "JN" then
    if has(UI.selList, c) then
      rmv(UI.selList, c); Audio.play("click")
      if #UI.selList == 0 then UI.mode = "idle" end
      return
    end
    if not playable(c) then Audio.play("error"); return say(whyNot(c), { 1, 0.7, 0.6 }) end
    return selectRay(c)
  end
  if not playable(c) then Audio.play("error"); return say(whyNot(c), { 1, 0.7, 0.6 }) end
  Audio.play("click")
  if c.s == "H" then return answer({ type = "place", card = c }) end
  if c.s == "T" and G.v3 and #wardable() > 0 then   -- v3: al banco, o escudo bajo una vida
    UI.mode = "club"; UI.ctx = { card = c }; UI.selList = { c }; return
  end
  if c.s == "T" or c.s == "M" then return answer({ type = "bank", card = c }) end
  if c.s == "JR" then
    if #G.cem > 0 then UI.mode = "cem"; clearSel(); UI.ctx = { why = "jr", card = c }; syncBoard()
    else answer({ type = "jokerRed", card = c, pick = nil }) end
  end
end

local function clickLife(t)
  if UI.mode == "target" then
    local c = UI.selList[1]
    if not c then return end
    if not E.canAttack(G, S.viewer) then Audio.play("error"); return say(whyNot(c), { 1, 0.7, 0.6 }) end
    if c.s == "JN" then
      local k = findK(me())
      if k and G.moves >= 2 and #secondTargets(t, true) > 0 then UI.t1 = t; UI.mode = "jk"; UI.ctx = { k = k }; Audio.play("click"); return end
      return answer({ type = "jokerBlack", card = c, t1 = t })
    end
    if canSplit() and kTotal() >= 2 and #secondTargets(t, false) > 0 then UI.t1 = t; UI.mode = "ksplit"; Audio.play("click"); return end
    return answer({ type = "attack", cards = selCards(), targets = { t } })
  elseif UI.mode == "jk" then
    for _, x in ipairs(secondTargets(UI.t1, true)) do
      if x.life == t.life then return answer({ type = "jokerBlack", card = UI.selList[1], t1 = UI.t1, t2 = t, k = UI.ctx.k }) end
    end
    Audio.play("error"); say("Elegí una vida de otro rival", { 1, 0.7, 0.6 })
  elseif UI.mode == "ksplit" then
    if t.life == UI.t1.life then return end
    UI.t2 = t; UI.alloc = math.max(1, math.floor(kTotal() / 2)); UI.mode = "kalloc"; Audio.play("click")
  elseif UI.mode == "peek" then
    if has(peekable(), t.life) then Audio.play("crit"); return answer(t.life) end
    Audio.play("error"); say("Elegí una vida oculta de " .. G.players[UI.ctx.tp].name, { 1, 0.7, 0.6 })
  end
end

-- v3: toques sobre vidas propias (trébol debajo, ocultar, reordenar)
local function clickOwnLife(L)
  if UI.mode == "wardpick" then
    if L.ward then Audio.play("error"); return say("Esa vida ya tiene una carta debajo", { 1, 0.7, 0.6 }) end
    Audio.play("luck"); return answer({ type = "ward", card = UI.ctx.card, life = L })
  elseif UI.mode == "target" and trapCard() then   -- v3: un rayo solo sobre una vida propia = trampa
    if L.ward then Audio.play("error"); return say("Esa vida ya tiene una carta debajo", { 1, 0.7, 0.6 }) end
    Audio.play("luck"); return answer({ type = "ward", card = trapCard(), life = L })
  elseif UI.mode == "hidepick" then
    if not L.up then Audio.play("error"); return say("Esa vida ya está oculta", { 1, 0.7, 0.6 }) end
    Audio.play("select"); return answer({ type = "money", tier = 4, life = L })
  elseif UI.mode == "swap" then
    if L == UI.t1 then return cancel() end
    if L.up then Audio.play("error"); return say("Solo se reordenan vidas ocultas", { 1, 0.7, 0.6 }) end
    Audio.play("deal"); return answer({ type = "swap", a = UI.t1, b = L })
  elseif UI.mode == "idle" and G.v3 and not L.up then
    if #hiddenOwn() < 2 then Audio.play("error"); return say("Para reordenar hacen falta dos vidas ocultas", { 1, 0.7, 0.6 }) end
    if G.moves < 1 then Audio.play("error"); return say("Sin movimientos", { 1, 0.7, 0.6 }) end
    UI.mode = "swap"; UI.t1 = L; Audio.play("click")
    say("Reordenar (1 mov): tocá otra vida oculta tuya para intercambiarlas", { 0.7, 0.85, 1 }, 3.5)
  end
end

----------------------------------------------------------------------
-- Botones
----------------------------------------------------------------------
local function addBtn(list, label, x, y, w, h, enabled, onclick, color)
  list[#list + 1] = { label = label, x = x, y = y, w = w, h = h, enabled = enabled ~= false, onclick = onclick, color = color, hover = false }
end

local COL = { green = { 0.2, 0.6, 0.3 }, gold = { 0.7, 0.55, 0.15 }, blue = { 0.3, 0.35, 0.5 }, red = { 0.7, 0.3, 0.3 }, grey = { 0.45, 0.45, 0.5 } }
local PANEL = { x = VW / 2 - 300, y = VH / 2 - 150, w = 600, h = 300 }

local function buildButtons()
  local b = {}
  if not deciding() then S.buttons = b; return end
  local P = me()
  if UI.mode == "idle" then
    local anyLuck, anyMoney = false, false
    for _, o in ipairs(luckOptions()) do if o.en then anyLuck = true end end
    for _, o in ipairs(moneyOptions()) do if o.en then anyMoney = true end end
    addBtn(b, "Usar suerte (" .. total(P.luck) .. ")", LEFT_X, BTN_Y1, BTN_W, BTN_H, anyLuck, function() UI.mode = "menu"; UI.menu = "luck" end, COL.green)
    addBtn(b, "Ver cementerio (" .. #G.cem .. ")", LEFT_X, BTN_Y2, BTN_W, BTN_H, #G.cem > 0, function() UI.mode = "cem"; UI.ctx = { why = "view" }; syncBoard() end, COL.grey)
    addBtn(b, "Usar dinero (" .. total(P.money) .. ")", RIGHT_X, BTN_Y1, BTN_W, BTN_H, anyMoney, function() UI.mode = "menu"; UI.menu = "money" end, COL.gold)
    addBtn(b, "Terminar turno", RIGHT_X, BTN_Y2, BTN_W, BTN_H, true, function() answer({ type = "end" }) end, COL.blue)
  elseif UI.mode == "target" then
    if trapCard() then   -- v3: un solo rayo seleccionado: también puede ir boca abajo bajo una vida propia como trampa
      local c = trapCard()
      addBtn(b, "Trampa bajo vida (" .. E.cname(c) .. ")", LEFT_X, BTN_Y1, BTN_W, BTN_H, true, function()
        UI.mode = "wardpick"; UI.ctx = { card = c }
        say("Trampa (1 mov): tocá una vida tuya sin nada debajo. Saltará contra quien la ataque.", { 1, 0.75, 0.65 }, 3.5)
      end, COL.red)
    end
    addBtn(b, "Cancelar", LEFT_X, BTN_Y2, BTN_W, BTN_H, true, cancel, COL.red)
    addBtn(b, "Terminar turno", RIGHT_X, BTN_Y2, BTN_W, BTN_H, true, function() answer({ type = "end" }) end, COL.blue)
  elseif UI.mode == "jk" then
    addBtn(b, "Cancelar", LEFT_X, BTN_Y2, BTN_W, BTN_H, true, cancel, COL.red)
    addBtn(b, "Solo esta vida", RIGHT_X, BTN_Y2, BTN_W, BTN_H, true, function() answer({ type = "jokerBlack", card = UI.selList[1], t1 = UI.t1 }) end, COL.blue)
  elseif UI.mode == "ksplit" then
    addBtn(b, "Cancelar", LEFT_X, BTN_Y2, BTN_W, BTN_H, true, cancel, COL.red)
    addBtn(b, "Todo a esta vida", RIGHT_X, BTN_Y2, BTN_W, BTN_H, true, function() answer({ type = "attack", cards = selCards(), targets = { UI.t1 } }) end, COL.blue)
  elseif UI.mode == "kalloc" then
    local px, py = PANEL.x, PANEL.y
    local tot = kTotal()
    addBtn(b, "-", px + 60, py + 150, 70, 50, UI.alloc > 1, function() UI.alloc = UI.alloc - 1 end, COL.blue)
    addBtn(b, "+", px + 150, py + 150, 70, 50, UI.alloc < tot - 1, function() UI.alloc = UI.alloc + 1 end, COL.blue)
    addBtn(b, "Atacar", px + 300, py + 150, 130, 50, true, function()
      answer({ type = "attack", cards = selCards(), targets = {
        { p = UI.t1.p, life = UI.t1.life, amount = UI.alloc }, { p = UI.t2.p, life = UI.t2.life, amount = tot - UI.alloc } } })
    end, COL.green)
    addBtn(b, "Cancelar", px + 450, py + 150, 110, 50, true, cancel, COL.red)
  elseif UI.mode == "club" then   -- v3: qué hacer con el trébol (bajo una vida siempre es escudo)
    local c = UI.ctx.card
    local labels = { { "Al banco de suerte (+" .. bv(c) .. ")", "bank", COL.green },
                     { "Escudo bajo una vida (boca abajo): resta " .. bv(c) .. " al golpe", "shield", COL.blue } }
    for i, o in ipairs(labels) do
      addBtn(b, o[1], PANEL.x + 40, PANEL.y + 70 + (i - 1) * 54, PANEL.w - 80, 44, true, function()
        if o[2] == "bank" then return answer({ type = "bank", card = c }) end
        UI.mode = "wardpick"; UI.ctx = { card = c }
        say("Escudo: tocá una vida tuya sin nada debajo", { 0.7, 0.85, 1 }, 3.5)
      end, o[3])
    end
    addBtn(b, "Cancelar", PANEL.x + PANEL.w / 2 - 80, PANEL.y + PANEL.h - 52, 160, 38, true, cancel, COL.grey)
  elseif UI.mode == "wardpick" or UI.mode == "hidepick" or UI.mode == "swap" then
    addBtn(b, "Cancelar", LEFT_X, BTN_Y2, BTN_W, BTN_H, true, cancel, COL.red)
  elseif UI.mode == "peek" then
    addBtn(b, "No revelar", RIGHT_X, BTN_Y2, BTN_W, BTN_H, true, function() answer(nil) end, COL.blue)
  elseif UI.mode == "menu" then
    local opts = (UI.menu == "luck") and luckOptions() or moneyOptions()
    for i, o in ipairs(opts) do
      addBtn(b, o.label, PANEL.x + 40, PANEL.y + 70 + (i - 1) * 54, PANEL.w - 80, 44, o.en, function()
        if UI.menu == "luck" then return answer({ type = "luck", tier = o.tier }) end
        if o.tier == 3 then UI.mode = "cem"; UI.ctx = { why = "buy" }; UI.menu = nil; syncBoard(); return end
        if o.tier == 4 then UI.mode = "hidepick"; UI.menu = nil; say("Ocultar (10 + 1 mov): tocá una vida tuya revelada", { 0.7, 0.85, 1 }, 3.5); return end
        answer({ type = "money", tier = o.tier })
      end, UI.menu == "luck" and COL.green or COL.gold)
    end
    addBtn(b, "Cancelar", PANEL.x + PANEL.w / 2 - 80, PANEL.y + PANEL.h - 52, 160, 38, true, cancel, COL.grey)
  elseif UI.mode == "cem" then
    addBtn(b, "Cerrar", VW / 2 - 80, VH - 60, 160, 38, true, function()
      if UI.ctx and UI.ctx.why == "buy" then UI.mode = "menu"; UI.menu = "money" else UI.mode = "idle" end
      UI.ctx = nil; syncBoard()
    end, COL.grey)
  elseif UI.mode == "defend" then
    addBtn(b, "No defender", RIGHT_X, BTN_Y2, BTN_W, BTN_H, true, function() answer(nil) end, COL.blue)
  end
  S.buttons = b
end

----------------------------------------------------------------------
-- Hover / update
----------------------------------------------------------------------
local function handCardAt(x, y, P)
  local found
  for _, c in ipairs(P.hand) do if cardHit(c, x, y) then found = c end end
  return found
end
local function lifeAt(x, y)
  for p, P in ipairs(G.players) do
    for _, L in ipairs(P.lives) do if cardHit(L.card, x, y) then return p, L end end
  end
end
local function cemCardAt(x, y)
  for _, c in ipairs(G.cem) do if cardHit(c, x, y) then return c end end
end

local function updateHover(dt)
  local mx, my = toVirtual(love.mouse.getPosition())
  local P = me()
  local canTouch = deciding() and (UI.mode == "idle" or UI.mode == "target" or UI.mode == "defend" or UI.mode == "discard")
  local hovered = canTouch and handCardAt(mx, my, P) or nil
  if hovered and not playable(hovered) and UI.mode ~= "discard" then hovered = nil end
  for _, c in ipairs(P.hand) do
    local target = 0
    if has(UI.selList, c) then target = 28 elseif c == hovered then target = 20 end
    c._lift = lerp(c._lift or 0, target, math.min(1, dt * 14))
  end
  for _, pl in ipairs(G.players) do
    for _, c in ipairs(pl.hand) do if pl ~= P then c._lift = lerp(c._lift or 0, 0, math.min(1, dt * 14)) end end
    for _, L in ipairs(pl.lives) do L.card.glow = 0 end
  end
  UI.hoverLife = nil
  if deciding("turn") and (UI.mode == "target" or UI.mode == "jk" or UI.mode == "ksplit") then
    local pulse = 0.3 + 0.3 * math.abs(math.sin(S.t * 5))
    local pool
    if UI.mode == "target" then pool = validTargets()
    elseif UI.mode == "jk" then pool = secondTargets(UI.t1, true)
    else pool = secondTargets(UI.t1, false) end
    for _, t in ipairs(pool) do t.life.card.glow = pulse end
    if UI.t1 then UI.t1.life.card.glow = 1 end
    local op, L = lifeAt(mx, my)
    if op and op ~= S.viewer then
      for _, t in ipairs(pool) do if t.life == L then UI.hoverLife = L; L.card.glow = 1 end end
    end
  end
  if UI.mode == "kalloc" then UI.t1.life.card.glow = 1; UI.t2.life.card.glow = 1 end
  -- v3: vidas propias (o del espiado) que se pueden tocar en estos modos
  if deciding("turn") and (UI.mode == "wardpick" or UI.mode == "hidepick" or UI.mode == "swap" or (UI.mode == "target" and trapCard())) then
    local pulse = 0.3 + 0.3 * math.abs(math.sin(S.t * 5))
    local pool = (UI.mode == "wardpick" or UI.mode == "target") and wardable() or (UI.mode == "hidepick") and ownLives(function(L) return L.up end) or hiddenOwn()
    for _, L in ipairs(pool) do if L ~= UI.t1 then L.card.glow = pulse end end
    if UI.mode == "swap" and UI.t1 then UI.t1.card.glow = 1 end
    local op, L = lifeAt(mx, my)
    if op == S.viewer and L and has(pool, L) then L.card.glow = 1 end
  elseif deciding("peek") then
    local pulse = 0.3 + 0.3 * math.abs(math.sin(S.t * 5))
    local pool = peekable()
    for _, L in ipairs(pool) do L.card.glow = pulse end
    local op, L = lifeAt(mx, my)
    if L and has(pool, L) then L.card.glow = 1 end
  end
  if UI.mode == "defend" and UI.ctx then UI.ctx.life.card.glow = 0.7 + 0.3 * math.sin(S.t * 6) end
  if S.aim then S.aim.t = S.aim.t - dt; if S.aim.t > 0 then S.aim.L.card.glow = 1 else S.aim = nil end end
  for _, c in ipairs(P.hand) do c.glow = has(UI.selList, c) and 1 or 0 end
  for _, btn in ipairs(S.buttons or {}) do btn.hover = pointIn(mx, my, btn.x, btn.y, btn.w, btn.h) end
end

----------------------------------------------------------------------
-- LÖVE callbacks
----------------------------------------------------------------------
local function computeScale()
  local w, h = love.graphics.getDimensions()
  S.scale = math.min(w / VW, h / VH)
  S.offx = (w - VW * S.scale) / 2
  S.offy = (h - VH * S.scale) / 2
end

function love.resize() computeScale() end

local function initMenu()
  S.menuBtns = {}
  local nums = { 2, 3, 4, 5, 6 }
  local bw, bh, gap = 96, 96, 22
  local totalW = #nums * bw + (#nums - 1) * gap
  local sx = VW / 2 - totalW / 2
  for i, n in ipairs(nums) do S.menuBtns[i] = { n = n, x = sx + (i - 1) * (bw + gap), y = 450, w = bw, h = bh } end
  -- conmutador de reglas (v3 por defecto)
  S.rulesBtns = { { rules = 2, x = VW / 2 - 250, y = 288, w = 240, h = 48 }, { rules = 3, x = VW / 2 + 10, y = 288, w = 240, h = 48 } }
end

local function runSelftest(n)
  local ST = require("src.selftest")
  local out = ST.run(n)
  io.write(ST.json(out), "\n"); io.flush()
  love.event.quit(out.ok and 0 or 1)
end

function love.load(args)
  args = args or {}
  for i, a in ipairs(args) do
    if a == "--selftest" then S.selftest = tonumber(args[i + 1]) or 200 end
    if a == "--autoplay" then S.autoplay = tonumber(args[i + 1]) or 3 end
    if a == "--rules" then S.rules = (tonumber(args[i + 1]) == 2) and 2 or 3 end   -- --rules 2 | 3 (para --autoplay)
  end
  if S.selftest then return runSelftest(S.selftest) end
  love.graphics.setDefaultFilter("linear", "linear")
  love.graphics.setBackgroundColor(0.04, 0.07, 0.05)
  Audio.load()
  if S.autoplay then Audio.enabled = false; S.speed = 4; io.stdout:setvbuf("line") end   -- log inmediato aunque se corte el proceso
  computeScale()
  initMenu()
  S.state = "menu"
  if S.autoplay then startNewGame(S.autoplay) end
end

-- Los errores de runtime también van a stderr (la pantalla azul de LÖVE solo usa stdout).
local origErr = love.errorhandler
function love.errorhandler(msg)
  io.stderr:write("ERROR: " .. tostring(msg) .. "\n" .. debug.traceback() .. "\n"); io.stderr:flush()
  return origErr(msg)
end

-- --autoplay: los bots juegan por todos los humanos (para probar la interfaz sin tocar nada).
-- Imprime el progreso por stdout y guarda capturas en el directorio de guardado de LÖVE.
local function autoplayStep()
  if not G then return end
  if S.state == "passing" and S.req and S.req.kind == "pass" then
    S.autoPass = S.autoPass or {}
    if not S.autoPass[S.req.why] then
      S.autoPass[S.req.why] = 1; return   -- un paso en la pantalla intermedia para capturarla
    elseif S.autoPass[S.req.why] == 1 then
      S.autoPass[S.req.why] = 2
      S.autoShots = (S.autoShots or 0) + 1
      love.graphics.captureScreenshot(string.format("shot_%02d_pass_%s_%dj.png", S.autoShots, S.req.why, G.n)); return
    end
    print(string.format("[auto] pass -> J%d (%s) ronda %d mazo %d descarte %d cem %d rebarajes %d", S.req.p, S.req.why, E.round(G), #G.deck, #G.discard, #G.cem, G.reshuffles))
    S.viewer = S.req.p; S.req = nil; S.state = "playing"; S.floats = {}; S.trap = nil; syncBoard(); pump(); return
  end
  if deciding() then
    -- la decisión se responde un paso más tarde para que la captura muestre la interfaz de la decisión
    local function shot(tag)
      S.autoShots = (S.autoShots or 0) + 1
      local name = string.format("shot_%02d_%s.png", S.autoShots, tag)
      love.graphics.captureScreenshot(name); print("[auto] captura " .. love.filesystem.getSaveDirectory() .. "/" .. name)
    end
    if not S.autoPending then
      local AI = require("src.ai")
      local a = AI.decide(G, S.req.p, S.req.dkind, S.req.ctx)
      S.autoPending = { a = a, step = 0 }
      local desc = "nil"
      if a then desc = a.type or (a.s and (a.s .. a.r)) or (a.card and ("vida " .. a.card.r)) or "?" end
      print(string.format("[auto] decide %s J%d -> %s", S.req.dkind, S.req.p, desc))
      S.autoTour = S.autoTour or {}
      if S.req.dkind == "turn" and (a.type == "attack" or a.type == "jokerBlack") and not S.autoTour.target then
        S.autoTour.target = true; UI.mode = "target"; UI.selList = a.cards or { a.card }
        UI.hoverLife = (a.targets and a.targets[1] or a.t1).life
      elseif S.req.dkind == "turn" and not S.autoTour.luck and total(me().luck) >= 10 then S.autoTour.luck = true; UI.mode = "menu"; UI.menu = "luck"
      elseif S.req.dkind == "turn" and not S.autoTour.money and total(me().money) >= 10 then S.autoTour.money = true; UI.mode = "menu"; UI.menu = "money"
      elseif S.req.dkind == "turn" and not S.autoTour.cem and #G.cem >= 3 then S.autoTour.cem = true; UI.mode = "cem"; UI.ctx = { why = "view" }; syncBoard()
      elseif S.req.dkind == "turn" and not S.autoTour.kalloc and a.type == "attack" and #a.targets == 2 then
        S.autoTour.kalloc = true; UI.selList = a.cards; UI.t1 = a.targets[1]; UI.t2 = a.targets[2]; UI.alloc = a.targets[1].amount; UI.mode = "kalloc"
      elseif S.req.dkind == "turn" and not S.autoTour.kalloc2 and a.type == "attack" and #a.cards == 1 and a.cards[1].r == 13 and #secondTargets(a.targets[1], false) > 0 then
        S.autoTour.kalloc2 = true; UI.selList = { a.cards[1] }; UI.t1 = a.targets[1]; UI.t2 = secondTargets(a.targets[1], false)[1]; UI.mode = "kalloc"
      -- v3: menú del trébol, elección de vida para escudo/trampa, ocultar y reordenar
      elseif S.req.dkind == "turn" and a.type == "ward" and a.card.s == "T" and not S.autoTour.club then
        S.autoTour.club = true; UI.mode = "club"; UI.ctx = { card = a.card }; UI.selList = { a.card }
      elseif S.req.dkind == "turn" and a.type == "ward" and a.card.s == "R" and not S.autoTour.raytrap then
        S.autoTour.raytrap = true; UI.mode = "target"; UI.selList = { a.card }   -- menú del rayo con el botón de trampa
      elseif S.req.dkind == "turn" and a.type == "ward" and not S.autoTour.wardpick then
        S.autoTour.wardpick = true; UI.mode = "wardpick"; UI.ctx = { card = a.card }; UI.selList = { a.card }
      elseif S.req.dkind == "turn" and a.type == "money" and a.tier == 4 and not S.autoTour.hidepick then
        S.autoTour.hidepick = true; UI.mode = "hidepick"
      elseif S.req.dkind == "turn" and a.type == "swap" and not S.autoTour.swap then
        S.autoTour.swap = true; UI.mode = "swap"; UI.t1 = a.a
      end
      return
    end
    local ap = S.autoPending
    ap.step = ap.step + 1
    if ap.step == 1 then
      local v3mode = (UI.mode == "club" or UI.mode == "wardpick" or UI.mode == "hidepick" or UI.mode == "swap" or S.req.dkind == "peek")
      if ((S.autoShots or 0) < 40 or (v3mode and (S.autoShots or 0) < 60)) and (S.req.dkind ~= "turn" or UI.mode ~= "idle" or love.math.random() < 0.2) then shot(S.req.dkind .. "_" .. UI.mode .. "_" .. G.n .. "j") end
      return
    end
    S.autoPending = nil
    if UI.mode ~= "idle" and UI.mode ~= "defend" and UI.mode ~= "discard" and UI.mode ~= "peek" then UI.mode = "idle"; UI.selList = {}; UI.t1 = nil; UI.t2 = nil; UI.ctx = nil; syncBoard() end
    answer(ap.a)
  end
  if S.state == "gameover" then
    if not S.autoGO then
      S.autoGO = true
      print(string.format("[auto] FIN: gana J%d reloj=%s rondas=%d", G.winner, tostring(G.byClock), E.round(G)))
      love.graphics.captureScreenshot(string.format("shot_gameover_%dj.png", G.n))
      return
    end
    S.autoGO = nil
    startNewGame(S.autoplay)
  end
end

function love.update(dt)
  if S.selftest then return end
  if dt > 0.1 then dt = 0.1 end
  S.t = S.t + dt
  flux.update(dt)
  PFX.update(dt)
  if S.messageT and S.messageT > 0 then S.messageT = S.messageT - dt end
  if S.banner then S.banner.t = S.banner.t - dt; if S.banner.t <= 0 then S.banner = nil end end
  if S.hit then S.hit.t = S.hit.t - dt; if S.hit.t <= 0 then S.hit = nil end end
  if S.trap then S.trap.t = S.trap.t - dt; if S.trap.t <= 0 then S.trap = nil end end
  S.shake = math.max(0, S.shake - dt * 30)
  for i = #S.floats, 1, -1 do
    local f = S.floats[i]; f.t = f.t - dt; f.y = f.y - dt * 28
    if f.t <= 0 then table.remove(S.floats, i) end
  end
  if G and S.req and S.req.kind == "wait" then
    S.waitT = S.waitT - dt * S.speed
    if S.waitT <= 0 then pump() end
  end
  if S.autoplay then
    if G and G.duel and G.duel.res and not S.autoDuelShot then S.autoDuelShot = true; love.graphics.captureScreenshot(string.format("shot_duel_%dj.png", G.n)) end
    -- capturas de los efectos de v3 (trampa, escudo, ocultar, reordenar, J revela): un poco después del efecto, tres por tipo
    if G and S.autoShotWant then
      local tag = S.autoShotWant; S.autoShotWant = nil
      S.autoFxShots = S.autoFxShots or {}
      S.autoFxShots[tag] = (S.autoFxShots[tag] or 0) + 1
      if S.autoFxShots[tag] <= 3 then
        S.autoFxDelay = { tag = tag, t = (tag == "trampa") and 0.55 or 0.35 }   -- trampa: con el rayo ya golpeando al atacante
      end
    end
    if S.autoFxDelay then
      S.autoFxDelay.t = S.autoFxDelay.t - dt
      if S.autoFxDelay.t <= 0 then
        local name = string.format("shot_fx_%s_%d_%dj.png", S.autoFxDelay.tag, S.autoFxShots[S.autoFxDelay.tag], G.n)
        love.graphics.captureScreenshot(name); print("[auto] captura fx " .. name)
        S.autoFxDelay = nil
      end
    end
    S.autoT = (S.autoT or 0) + dt
    if S.autoT > 0.12 then S.autoT = 0; autoplayStep() end
  end
  if G and (S.state == "playing" or S.state == "dealing") then
    buildButtons()
    updateHover(dt)
  else
    S.buttons = {}
  end
end

function love.mousepressed(mx, my, button)
  if S.selftest then return end
  local x, y = toVirtual(mx, my)
  if button == 2 then
    if G and deciding() then cancel() end
    return
  end
  if button ~= 1 then return end

  if S.state == "menu" then
    for _, btn in ipairs(S.rulesBtns or {}) do
      if pointIn(x, y, btn.x, btn.y, btn.w, btn.h) then Audio.play("click"); S.rules = btn.rules; return end
    end
    for _, btn in ipairs(S.menuBtns) do
      if pointIn(x, y, btn.x, btn.y, btn.w, btn.h) then Audio.play("click"); startNewGame(btn.n); return end
    end
    return
  end
  if S.state == "gameover" then
    if S.goBtn and pointIn(x, y, S.goBtn.x, S.goBtn.y, S.goBtn.w, S.goBtn.h) then Audio.play("click"); G = nil; S.state = "menu" end
    return
  end
  if S.state == "passing" then
    if S.req and S.req.kind == "pass" then
      Audio.play("turn")
      S.viewer = S.req.p; S.req = nil; S.state = "playing"
      S.floats = {}; S.trap = nil; S.message = nil   -- nada del jugador anterior se filtra al siguiente
      syncBoard(); pump()
    end
    return
  end
  if not deciding() then return end

  for _, btn in ipairs(S.buttons or {}) do
    if pointIn(x, y, btn.x, btn.y, btn.w, btn.h) then
      if btn.enabled then Audio.play("click"); btn.onclick() else Audio.play("error"); say("Ahora no se puede", { 1, 0.7, 0.6 }) end
      return
    end
  end

  if UI.mode == "cem" then
    local c = cemCardAt(x, y)
    if c and UI.ctx then
      if UI.ctx.why == "jr" then return answer({ type = "jokerRed", card = UI.ctx.card, pick = c }) end
      if UI.ctx.why == "buy" then return answer({ type = "money", tier = 3, pick = c }) end
    end
    return
  end
  if UI.mode == "menu" or UI.mode == "kalloc" then return end
  if UI.mode == "club" then return cancel() end

  if UI.mode == "target" or UI.mode == "jk" or UI.mode == "ksplit" or UI.mode == "peek" then
    local op, L = lifeAt(x, y)
    if op and op ~= S.viewer and G.players[op].alive then return clickLife({ p = op, life = L }) end
  end
  if UI.mode == "wardpick" or UI.mode == "hidepick" or UI.mode == "swap" or (UI.mode == "idle" and G.v3) or (UI.mode == "target" and trapCard()) then
    local op, L = lifeAt(x, y)
    if op == S.viewer and L then return clickOwnLife(L) end
    if UI.mode ~= "idle" and UI.mode ~= "target" then return cancel() end
  end
  local c = handCardAt(x, y, me())
  if c then return clickHand(c) end
  if UI.mode == "target" then cancel() end
end

function love.keypressed(key)
  if S.selftest then return end
  if key == "escape" then
    if G and deciding() and UI.mode ~= "idle" then cancel()
    elseif S.state ~= "menu" then G = nil; S.state = "menu" end
  elseif key == "f" then
    love.window.setFullscreen(not love.window.getFullscreen()); computeScale()
  elseif key == "m" then
    Audio.enabled = not Audio.enabled
  elseif key == "s" then
    S.speed = (S.speed == 1) and 2 or ((S.speed == 2) and 4 or 1)
    say("Velocidad x" .. S.speed, { 0.8, 0.9, 1 }, 1.2)
  elseif key == "e" and G and deciding("turn") and (UI.mode == "idle" or UI.mode == "target") then
    answer({ type = "end" })
  elseif key == "return" or key == "space" then
    if S.state == "passing" then love.mousepressed(S.offx, S.offy, 1) end
  end
end

----------------------------------------------------------------------
-- Render
----------------------------------------------------------------------
local function drawBackground()
  love.graphics.setColor(0.05, 0.09, 0.06); love.graphics.rectangle("fill", -40, -40, VW + 80, VH + 80)
  love.graphics.setColor(0.10, 0.20, 0.14)
  love.graphics.ellipse("fill", VW / 2, VH / 2, VW * 0.62, VH * 0.52)
  love.graphics.setColor(0.07, 0.14, 0.10)
  love.graphics.ellipse("line", VW / 2, VH / 2, VW * 0.62, VH * 0.52)
  local suits = { "spades", "hearts", "diamonds", "clubs" }
  for i = 1, 10 do
    local t = S.t * 0.25 + i
    local x = (VW * (0.05 + 0.1 * i) + math.sin(t) * 40) % VW
    local y = (VH * 0.5 + math.cos(t * 0.8 + i) * 260)
    local col = (i % 2 == 0) and { 1, 1, 1 } or { 0.7, 0.85, 0.7 }
    Card.suit(suits[(i % 4) + 1], x, y, 26, col, 0.04)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

local function drawPilePlaceholder(pos, label, count)
  love.graphics.setColor(1, 1, 1, 0.10)
  rrect("line", pos.x - CW / 2, pos.y - CH / 2, CW, CH, 10)
  love.graphics.setFont(F(14))
  love.graphics.setColor(1, 1, 1, 0.55)
  love.graphics.printf(label, pos.x - 70, pos.y + CH / 2 + 6, 140, "center")
  if count and count > 0 then
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf(tostring(count), pos.x - 70, pos.y - CH / 2 - 22, 140, "center")
  end
end

local function drawBank(x, y, w, kind, list, glowAmt, small)
  local h = small and 44 or 48
  love.graphics.setColor(0, 0, 0, 0.5); rrect("fill", x - w / 2, y - h / 2, w, h, 10)
  local c = (kind == "luck") and { 0.3, 0.8, 0.4 } or { 0.9, 0.72, 0.25 }
  if glowAmt and glowAmt > 0 then
    love.graphics.setColor(c[1], c[2], c[3], 0.3 * glowAmt)
    rrect("fill", x - w / 2 - 4, y - h / 2 - 4, w + 8, h + 8, 12)
  end
  love.graphics.setColor(c[1], c[2], c[3], 1); love.graphics.setLineWidth(2)
  rrect("line", x - w / 2, y - h / 2, w, h, 10)
  Card.suit((kind == "luck") and "clubs" or "diamonds", x - w / 2 + 18, y - 2, 9, c, 1)
  love.graphics.setFont(F(small and 22 or 26)); love.graphics.setColor(1, 1, 1, 1)
  local numW = (w >= 130) and 44 or (w - 36)
  love.graphics.printf(tostring(total(list)), x - w / 2 + 32, y - (small and 13 or 16), numW, "center")
  if not small then
    love.graphics.setFont(F(12)); love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.printf(#list .. (#list == 1 and " carta" or " cartas"), x - w / 2 + 80, y - 8, w - 86, "center")
  end
end

local function drawBoard()
  drawPilePlaceholder(DECK_POS, "Mazo", #G.deck)
  drawPilePlaceholder(DISCARD_POS, "Descarte", #G.discard)
  drawPilePlaceholder(GRAVE_POS, "Cementerio", #G.cem)

  for p, P in ipairs(G.players) do
    local lay = P._lay
    local active = (p == G.cur and S.state == "playing") and (0.5 + 0.5 * math.sin(S.t * 3)) or 0
    local small = lay.owner == "opp"
    drawBank(lay.luckX, lay.luckY, lay.bankW, "luck", P.luck, active, small)
    drawBank(lay.moneyX, lay.moneyY, lay.bankW, "money", P.money, active, small)
    love.graphics.setFont(F(18))
    if not P.alive then love.graphics.setColor(0.6, 0.4, 0.4, 0.7)
    elseif p == G.cur and S.state == "playing" then love.graphics.setColor(1, 0.95, 0.6)
    else love.graphics.setColor(1, 1, 1, 0.6) end
    local label = P.name
    if not P.alive then label = label .. " · ELIMINADO"
    else label = label .. " · " .. #P.lives .. (#P.lives == 1 and " vida" or " vidas") .. " · " .. #P.hand .. (#P.hand == 1 and " carta" or " cartas") end
    if p == S.viewer and S.state ~= "passing" then label = label .. " (vos)" end
    love.graphics.printf(label, lay.nameX - lay.nameW / 2, lay.nameY, lay.nameW, "center")
  end
end

local function drawLifeBars()
  for p, P in ipairs(G.players) do
    for _, L in ipairs(P.lives) do
      local c = L.card
      local visible = c.faceUp and (L.up or p == S.viewer)
      if visible and (L.dmg > 0 or UI.hoverLife == L or (S.hit and S.hit.L == L)) then
        local sc = c.scale or 1
        local bx, by, bw, bh = c.x - (CW / 2 - 7) * sc, c.y + (CH / 2 - 18) * sc, (CW - 14) * sc, 9 * sc
        love.graphics.setColor(0, 0, 0, 0.7); rrect("fill", bx - 2, by - 2, bw + 4, bh + 4, 3)
        local frac = clamp(L.dmg / c.r, 0, 1)
        love.graphics.setColor(0.85, 0.25, 0.2, 1); rrect("fill", bx, by, bw * frac, bh, 2)
        if UI.hoverLife == L and #UI.selList > 0 then
          local extra = clamp(selTotal() / c.r, 0, 1 - frac)
          local lethal = selTotal() >= rem(L)
          love.graphics.setColor(1, lethal and 0.9 or 0.75, 0.3, 0.6 + 0.3 * math.abs(math.sin(S.t * 6)))
          rrect("fill", bx + bw * frac, by, bw * extra, bh, 2)
        end
        love.graphics.setFont(F(12)); love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.printf(L.dmg .. " / " .. c.r .. ((not L.up and p == S.viewer and L.dmg > 0) and "  (oculto)" or ""), c.x - 40, by - 15 * sc, 80, "center")
      end
      -- v3: icono de escudo/trampa, SOLO para el dueño y nunca en la pantalla de paso
      if L.ward and p == S.viewer and S.state ~= "passing" and c.faceUp then
        local sc = c.scale or 1
        local ix, iy = c.x - (CW / 2 - 15) * sc, c.y + 6 * sc
        local trap = (L.ward.kind == "trap")
        love.graphics.setColor(0, 0, 0, 0.75); love.graphics.circle("fill", ix, iy, 12 * sc)
        if trap then
          love.graphics.setColor(1, 0.4, 0.35, 1); love.graphics.setLineWidth(2.5 * sc)
          love.graphics.circle("line", ix, iy, 8 * sc); love.graphics.circle("fill", ix, iy, 3 * sc)
        else
          love.graphics.setColor(0.5, 1, 0.6, 1)
          love.graphics.polygon("fill", ix - 7 * sc, iy - 7 * sc, ix + 7 * sc, iy - 7 * sc, ix + 7 * sc, iy + 1 * sc, ix, iy + 8 * sc, ix - 7 * sc, iy + 1 * sc)
        end
        love.graphics.setFont(F(11)); love.graphics.setColor(trap and { 1, 0.6, 0.55 } or { 0.6, 1, 0.7 })
        love.graphics.printf(trap and "trampa" or "escudo", ix - 30, iy + 13 * sc, 60, "center")
      end
    end
  end
  -- v3: trampa saltada: se señala el rayo que salta contra el atacante
  if S.trap and S.trap.card then
    local c = S.trap.card
    local a = clamp(S.trap.t / 0.5, 0, 1)
    love.graphics.setColor(1, 0.35, 0.3, 0.9 * a); love.graphics.setLineWidth(3)
    rrect("line", c.x - (c.w * (c.scale or 1)) / 2 - 5, c.y - (c.h * (c.scale or 1)) / 2 - 5, c.w * (c.scale or 1) + 10, c.h * (c.scale or 1) + 10, 12)
    if S.trap.txt then
      love.graphics.setFont(F(13)); love.graphics.setColor(1, 0.7, 0.6, a)
      love.graphics.printf(S.trap.txt, c.x - 80, c.y - (c.h * (c.scale or 1)) / 2 - 24, 160, "center")
    end
  end
end

local function drawCardWithLift(c)
  local lift = c._lift or 0
  if lift > 0.5 then
    local oy, os = c.y, c.scale
    c.y = c.y - lift; c.scale = (c.scale or 1) * (1 + lift / 28 * 0.08)
    Card.draw(c)
    c.y, c.scale = oy, os
  else
    Card.draw(c)
  end
end

local function drawCards()
  table.sort(G.allCards, function(a, b) return (a._z or 0) < (b._z or 0) end)
  for _, c in ipairs(G.allCards) do if not c._overlay then drawCardWithLift(c) end end
  drawLifeBars()
end

local function drawOverlayCards()
  for _, c in ipairs(G.allCards) do if c._overlay then Card.draw(c) end end
end

local function drawButton(btn)
  local col = btn.color or COL.blue
  local a = btn.enabled and 1 or 0.35
  local k = (btn.hover and btn.enabled) and 1.3 or 1
  love.graphics.setColor(col[1] * k, col[2] * k, col[3] * k, a)
  rrect("fill", btn.x, btn.y, btn.w, btn.h, 8)
  love.graphics.setColor(1, 1, 1, a)
  love.graphics.setLineWidth(2); rrect("line", btn.x, btn.y, btn.w, btn.h, 8)
  local f = (btn.h >= 50) and F(24) or F(17)
  love.graphics.setFont(f)
  love.graphics.printf(btn.label, btn.x, btn.y + btn.h / 2 - f:getHeight() / 2, btn.w, "center")
end

local function drawPanel(title)
  love.graphics.setColor(0, 0, 0, 0.55); love.graphics.rectangle("fill", 0, 0, VW, VH)
  love.graphics.setColor(0.07, 0.12, 0.10, 0.97); rrect("fill", PANEL.x, PANEL.y, PANEL.w, PANEL.h, 14)
  love.graphics.setColor(1, 0.95, 0.7, 0.9); love.graphics.setLineWidth(2); rrect("line", PANEL.x, PANEL.y, PANEL.w, PANEL.h, 14)
  if title then
    love.graphics.setFont(F(24)); love.graphics.setColor(1, 0.95, 0.7)
    love.graphics.printf(title, PANEL.x, PANEL.y + 18, PANEL.w, "center")
  end
end

local function lifeName(t) return G.players[t.p].name .. " (" .. (t.life.up and ("vida " .. t.life.card.r) or "vida oculta") .. ")" end

local function drawInfoZone()
  local x, y = 24, 346
  love.graphics.setFont(F(16))
  love.graphics.setColor(1, 1, 1, 0.75)
  love.graphics.print("Ronda " .. E.round(G), x, y)
  local rs = "Rebarajes " .. G.reshuffles .. "/7"
  if G.sudden then love.graphics.setColor(1, 0.5, 0.4) else love.graphics.setColor(1, 1, 1, 0.75) end
  love.graphics.print(rs .. (G.sudden and "  · MUERTE SÚBITA: sin defensas" or (G.reshuffles >= 2 and "  (4º: sin defensas · 7º: fin)" or "")), x, y + 22)

  if S.state == "playing" and not G.over and S.viewer ~= G.cur then
    love.graphics.setFont(F(17)); love.graphics.setColor(1, 0.85, 0.6)
    love.graphics.print("Turno de " .. G.players[G.cur].name, x, y + 56)
  elseif S.state == "playing" and not G.over then
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("Movimientos", x, y + 56)
    local maxM = (G.players[G.cur].turns == 0 and G.cur == G.first) and 1 or 3
    for i = 1, maxM do
      local on = i <= G.moves
      love.graphics.setColor(on and 1 or 0.25, on and 0.85 or 0.25, on and 0.4 or 0.25, on and 1 or 0.6)
      love.graphics.circle("fill", x + 110 + (i - 1) * 26, y + 66, 9)
    end
    local iy = y + 92
    if G.pendingMult then
      love.graphics.setFont(F(17))
      if G.pendingMult.kind == "money" then love.graphics.setColor(0.95, 0.75, 0.3); love.graphics.print("Dinero: próximo rayo x2 seguro", x, iy)
      else love.graphics.setColor(0.3, 0.9, 0.4); love.graphics.print("Suerte " .. G.pendingMult.tier * 10 .. ": duelo al lanzar el rayo (" .. PROB[G.pendingMult.tier] .. ")", x, iy) end
      iy = iy + 24
    end
    if deciding("turn") and #UI.selList > 0 then
      love.graphics.setFont(F(17)); love.graphics.setColor(0.6, 0.85, 1)
      local names = {}
      for i, c in ipairs(UI.selList) do names[i] = (c.s == "JN") and "Joker negro" or E.cname(c) end
      local txt = "Ataque: " .. table.concat(names, " + ")
      if UI.selList[1].s ~= "JN" then
        txt = txt .. " = " .. selSum()
        if G.pendingMult and G.pendingMult.kind == "money" then txt = txt .. " (x2 en la más alta: " .. selTotal() .. ")" end
        if G.pendingMult and G.pendingMult.kind == "luck" then
          local t3 = G.pendingMult.tier == 3
          txt = txt .. " (si hay crítico, x" .. (t3 and 3 or 2) .. ((G.v3 and t3) and " a todo el combo: " .. selSum() * 3 or " en la más alta") .. ")"
        end
      end
      love.graphics.printf(txt, x, iy, 340, "left")
      iy = iy + 40
      love.graphics.setFont(F(14)); love.graphics.setColor(1, 1, 1, 0.6)
      local hint = E.canAttack(G, S.viewer) and "Tocá una vida rival para atacar" or "Ahora no se puede atacar"
      if UI.mode == "target" and trapCard() then hint = hint .. " · o una vida tuya sin nada debajo: el rayo queda de trampa" end
      if UI.mode == "jk" then hint = "Joker + K: tocá una vida de otro rival, o 'Solo esta vida'" end
      if UI.mode == "ksplit" then hint = "K: tocá una segunda vida para repartir " .. kTotal() .. " de daño" end
      if UI.mode == "target" and UI.selList[1].s == "R" and E.canAttack(G, S.viewer) then hint = hint .. " (más rayos = ataque combinado)" end
      if UI.mode == "club" then hint = "Trébol: al banco, o escudo bajo una vida tuya" end
      if UI.mode == "wardpick" then hint = (UI.ctx.card.s == "R" and "Trampa" or "Escudo") .. " (1 mov): tocá una vida tuya sin nada debajo" end
      love.graphics.printf(hint, x, iy, 340, "left")
    elseif deciding("turn") and (UI.mode == "hidepick" or UI.mode == "swap") then
      love.graphics.setFont(F(14)); love.graphics.setColor(1, 1, 1, 0.6)
      love.graphics.printf(UI.mode == "hidepick" and "Ocultar (10 + 1 mov): tocá una vida tuya revelada. Sus rayos van al descarte, el daño se conserva en secreto."
                                                    or "Reordenar (1 mov): tocá otra vida oculta tuya para intercambiarlas (con lo que tengan debajo).", x, iy, 340, "left")
    elseif deciding("turn") and UI.mode == "idle" and G.v3 then
      love.graphics.setFont(F(13)); love.graphics.setColor(1, 1, 1, 0.45)
      love.graphics.printf("v3: trébol → banco o escudo bajo una vida · un rayo solo → trampa bajo una vida · dinero 10 → ocultar · tocá una vida oculta tuya → reordenar", x, iy, 340, "left")
    elseif deciding("peek") and UI.ctx then
      love.graphics.setFont(F(15)); love.graphics.setColor(1, 0.9, 0.5)
      love.graphics.printf("J revela: tocá una vida oculta de " .. G.players[UI.ctx.tp].name .. ". Queda boca arriba para todos.", x, iy, 340, "left")
    end
  end
  -- registro a la derecha
  love.graphics.setFont(F(14))
  for i, s in ipairs(S.log) do
    love.graphics.setColor(1, 1, 1, 0.25 + 0.55 * (i / #S.log))
    love.graphics.printf(s, VW - 360, 330 + (i - 1) * 19, 340, "right")
  end
end

local function drawHUD()
  if S.state == "playing" or S.state == "dealing" or S.state == "gameover" then drawInfoZone() end

  -- contador de golpe sobre la vida
  if S.hit and S.hit.t > 0 then
    local c = S.hit.L.card
    local a = clamp(S.hit.t / 0.4, 0, 1)
    love.graphics.setFont(F(34))
    local txt = tostring(S.hit.v)
    love.graphics.setColor(0, 0, 0, 0.7 * a); rrect("fill", c.x - 34, c.y - CH / 2 - 52, 68, 40, 8)
    love.graphics.setColor(1, S.hit.mult and 0.85 or 0.5, 0.3, a)
    love.graphics.printf(txt, c.x - 60, c.y - CH / 2 - 50, 120, "center")
  end

  if UI.mode == "menu" then
    drawPanel(UI.menu == "luck" and ("Usar suerte  ·  tenés " .. total(me().luck)) or ("Usar dinero  ·  tenés " .. total(me().money)))
    love.graphics.setFont(F(13)); love.graphics.setColor(1, 1, 1, 0.6)
    local sub = (UI.menu == "luck") and "Pagás con cartas enteras (el exceso se pierde). Volteás cartas y te quedás la mejor; el rival voltea 1. Si igualás o superás, hay crítico."
      or "Pagás con cartas enteras del banco (el exceso se pierde)."
    love.graphics.printf(sub, PANEL.x + 30, PANEL.y + 46, PANEL.w - 60, "center")
  elseif UI.mode == "kalloc" then
    local tot = kTotal()
    drawPanel(G.v3 and ("K acumulativa: repartir " .. tot .. " de daño (" .. #UI.selList .. (#UI.selList == 1 and " carta)" or " cartas)")) or "K de rayos: repartir 13 de daño")
    love.graphics.setFont(F(19)); love.graphics.setColor(1, 1, 1, 0.9)
    local m = (G.pendingMult and G.pendingMult.kind == "money") and 2 or 1
    local a1, a2 = UI.alloc, tot - UI.alloc
    if m > 1 then   -- el reparto se declara sobre la suma y se escala con el multiplicador (igual que el motor)
      local tv = selTotal()
      a1 = math.max(1, math.min(tv - 1, math.floor(UI.alloc * tv / tot + 0.5))); a2 = tv - a1
    end
    love.graphics.printf(lifeName(UI.t1) .. ":  " .. a1, PANEL.x + 30, PANEL.y + 66, PANEL.w - 60, "center")
    love.graphics.printf(lifeName(UI.t2) .. ":  " .. a2, PANEL.x + 30, PANEL.y + 98, PANEL.w - 60, "center")
    love.graphics.setFont(F(13)); love.graphics.setColor(1, 0.85, 0.5)
    if m > 1 then love.graphics.printf("(x2 del dinero aplicado al total y repartido en proporción)", PANEL.x, PANEL.y + 124, PANEL.w, "center")
    elseif G.pendingMult then love.graphics.printf("(si sale el crítico, el multiplicador se reparte en proporción)", PANEL.x, PANEL.y + 124, PANEL.w, "center") end
  elseif UI.mode == "club" then
    drawPanel("Trébol " .. bv(UI.ctx.card) .. ": ¿qué hacés con él?")
    love.graphics.setFont(F(13)); love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.printf("Bajo una vida va boca abajo (una carta por vida): un trébol es escudo, un rayo es trampa. La Q lo desarma; el joker negro no lo activa.", PANEL.x + 30, PANEL.y + 48, PANEL.w - 60, "center")
  elseif UI.mode == "cem" then
    love.graphics.setColor(0, 0, 0, 0.7); love.graphics.rectangle("fill", 0, 0, VW, VH)
    love.graphics.setFont(F(26)); love.graphics.setColor(1, 0.95, 0.7)
    local why = UI.ctx and UI.ctx.why
    local title = "Cementerio · " .. #G.cem .. (#G.cem == 1 and " vida" or " vidas")
    if why == "jr" then title = "Joker rojo: elegí la vida que revivís" elseif why == "buy" then title = "Dinero 30: elegí la vida que comprás" end
    printC(title, 60)
    if why == "jr" or why == "buy" then love.graphics.setFont(F(16)); love.graphics.setColor(1, 1, 1, 0.7); printC("Va a tu mesa boca abajo", 96) end
    drawOverlayCards()
  elseif UI.mode == "defend" and UI.ctx then
    local c = UI.ctx
    local L = c.life
    local py = VH / 2 - 70
    love.graphics.setColor(0.35, 0.08, 0.08, 0.92); rrect("fill", VW / 2 - 330, py, 660, 150, 14)
    love.graphics.setColor(1, 0.6, 0.5); love.graphics.setLineWidth(2); rrect("line", VW / 2 - 330, py, 660, 150, 14)
    love.graphics.setFont(F(26)); love.graphics.setColor(1, 0.9, 0.7)
    if c.trap then printC("¡Trampa de " .. G.players[c.from].name .. "! Un rayo " .. E.cname(c.cards[1]) .. " salta contra vos: " .. c.val, py + 14)
    else printC(G.players[c.from].name .. " te ataca con " .. c.val .. ((c.mult or 1) > 1 and ("  (x" .. c.mult .. ")") or ""), py + 14) end
    love.graphics.setFont(F(18)); love.graphics.setColor(1, 1, 1, 0.9)
    local need = rem(L)
    printC("Tu vida " .. L.card.r .. " aguanta " .. need .. " más" .. (c.val >= need and "  ·  ESTE GOLPE LA MATA" or ""), py + 52)
    love.graphics.setFont(F(16)); love.graphics.setColor(0.7, 1, 0.75)
    printC("Tocá un trébol de tu mano para restar su valor (figuras = 10), o 'No defender'. Solo una defensa por turno rival.", py + 82)
    love.graphics.setColor(1, 1, 1, 0.6); love.graphics.setFont(F(14))
    printC("El trébol se queda cruzado bajo la vida", py + 108)
  elseif UI.mode == "discard" then
    love.graphics.setColor(0.1, 0.1, 0.2, 0.85); rrect("fill", VW / 2 - 260, VH - 190, 520, 40, 10)
    love.graphics.setFont(F(20)); love.graphics.setColor(1, 0.9, 0.6)
    printC("Tenés " .. #me().hand .. " cartas: descartá " .. (#me().hand - 7), VH - 182)
  end

  if G.duel then
    local D = G.duel
    love.graphics.setColor(0, 0, 0, 0.6); love.graphics.rectangle("fill", 0, 0, VW, VH)
    love.graphics.setFont(F(30)); love.graphics.setColor(1, 0.95, 0.5)
    printC("DUELO DE CRÍTICO", VH / 2 - 150)
    love.graphics.setFont(F(17)); love.graphics.setColor(1, 1, 1, 0.75)
    printC("Suerte " .. D.tier * 10 .. " · probabilidad " .. PROB[D.tier] .. " · premio x" .. (D.tier == 3 and 3 or 2) .. "  ·  la mejor carta debe igualar o superar la del rival", VH / 2 - 116)
    love.graphics.setFont(F(40)); love.graphics.setColor(1, 1, 1, 0.9)
    printC("VS", VH / 2 - 44)
    love.graphics.setFont(F(15)); love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf(G.players[D.p].name, VW / 2 - 160 - (D.tier - 1) * 50 - 150, VH / 2 + 60, 300 + (D.tier - 1) * 100, "center")
    love.graphics.printf(G.players[D.dp].name, VW / 2 + 160 - 100, VH / 2 + 60, 200, "center")
    if D.res then
      love.graphics.setFont(F(44))
      if D.res == "FALLO" then love.graphics.setColor(0.8, 0.8, 0.85); printC("FALLA EL CRÍTICO", VH / 2 + 90)
      else love.graphics.setColor(1, 0.9, 0.3); printC("¡CRÍTICO " .. D.res .. "!", VH / 2 + 90) end
    end
    drawOverlayCards()
  end

  for _, btn in ipairs(S.buttons or {}) do drawButton(btn) end

  for _, f in ipairs(S.floats) do
    local a = clamp(f.t / 0.5, 0, 1)
    love.graphics.setFont(F(f.big and 28 or 18))
    love.graphics.setColor(0, 0, 0, 0.6 * a); love.graphics.printf(f.text, f.x - 100 + 2, f.y + 2, 200, "center")
    love.graphics.setColor(f.color[1], f.color[2], f.color[3], a); love.graphics.printf(f.text, f.x - 100, f.y, 200, "center")
  end
end

local function drawMessage()
  if S.banner then
    local a = clamp(S.banner.t / 0.35, 0, 1) * clamp((S.banner.total - S.banner.t) / 0.15, 0, 1)
    love.graphics.setFont(F(52))
    love.graphics.setColor(0, 0, 0, 0.6 * a); love.graphics.rectangle("fill", 0, VH / 2 - 190, VW, 80)
    love.graphics.setColor(1, 0.9, 0.5, a); printC(S.banner.text, VH / 2 - 180)
  end
  if not S.message or (S.messageT or 0) <= 0 or S.state == "passing" then return end
  local overlay = (G and (G.duel or UI.mode == "menu" or UI.mode == "kalloc" or UI.mode == "cem" or UI.mode == "defend" or UI.mode == "club"))
  local my = overlay and 150 or 292
  local a = clamp(S.messageT / 0.6, 0, 1)
  local c = S.messageColor or { 1, 1, 1 }
  love.graphics.setFont(F(20))
  local w = F(20):getWidth(S.message) + 50
  love.graphics.setColor(0, 0, 0, 0.65 * a)
  rrect("fill", VW / 2 - w / 2, my, w, 36, 10)
  love.graphics.setColor(c[1], c[2], c[3], a)
  love.graphics.printf(S.message, VW / 2 - w / 2, my + 7, w, "center")
end

local function drawPassing()
  local req = S.req
  love.graphics.setColor(0, 0, 0, 1); love.graphics.rectangle("fill", -40, -40, VW + 80, VH + 80)   -- opaco: nada se filtra al pasar el equipo
  local P = G.players[req.p]
  love.graphics.setColor(1, 1, 1)
  if req.why == "defend" then
    love.graphics.setFont(F(50)); love.graphics.setColor(1, 0.7, 0.6); printC(P.name .. ": ¡te atacan!", VH / 2 - 120)
    love.graphics.setFont(F(24)); love.graphics.setColor(1, 1, 1, 0.75)
    printC("Podés bloquear con un trébol de tu mano. Que " .. G.players[G.cur].name .. " no mire.", VH / 2 - 44)
  elseif req.why == "back" then
    love.graphics.setFont(F(50)); printC("Devolvé el turno a " .. G.players[G.cur].name, VH / 2 - 120)
    love.graphics.setFont(F(24)); love.graphics.setColor(1, 1, 1, 0.75)
    printC("La defensa ya está decidida. Se resuelve el ataque.", VH / 2 - 44)
  else
    love.graphics.setFont(F(56)); printC("Turno de " .. P.name, VH / 2 - 120)
    love.graphics.setFont(F(24)); love.graphics.setColor(1, 1, 1, 0.75)
    printC("Ronda " .. E.round(G) .. "  ·  robás 2 cartas y tenés " .. ((not G.fair and P.turns == 0 and req.p == G.first) and "1 movimiento" or "3 movimientos"), VH / 2 - 50)
    printC("Que los demás no miren la pantalla", VH / 2 - 16)
  end
  local a = 0.55 + 0.45 * math.sin(S.t * 4)
  love.graphics.setColor(1, 1, 0.6, a); love.graphics.setFont(F(28))
  printC("Tocá la pantalla para continuar", VH / 2 + 60)
end

local function drawGameOver()
  love.graphics.setColor(0, 0, 0, 0.82); love.graphics.rectangle("fill", -40, -40, VW + 80, VH + 80)
  local W = G.players[G.winner]
  love.graphics.setColor(1, 0.9, 0.3); love.graphics.setFont(F(64))
  printC("¡" .. (W and W.name or "Nadie") .. " gana!", VH / 2 - 130)
  love.graphics.setColor(1, 1, 1, 0.8); love.graphics.setFont(F(24))
  if G.byClock then
    printC("Fin por reloj (" .. plain(G.clockWhy or "") .. "): más vidas en la mesa" .. (W and (" · " .. #W.lives .. " vidas") or ""), VH / 2 - 50)
  else
    printC("Último jugador con vidas en pie · " .. E.round(G) .. " rondas · " .. G.stats.kills .. " vidas destruidas", VH / 2 - 50)
  end
  S.goBtn = { x = VW / 2 - 130, y = VH / 2 + 40, w = 260, h = 56 }
  local mx, my = toVirtual(love.mouse.getPosition())
  local hover = pointIn(mx, my, S.goBtn.x, S.goBtn.y, S.goBtn.w, S.goBtn.h)
  love.graphics.setColor(hover and 0.4 or 0.25, hover and 0.6 or 0.4, hover and 0.4 or 0.3)
  rrect("fill", S.goBtn.x, S.goBtn.y, S.goBtn.w, S.goBtn.h, 10)
  love.graphics.setColor(1, 1, 1); love.graphics.setLineWidth(2)
  rrect("line", S.goBtn.x, S.goBtn.y, S.goBtn.w, S.goBtn.h, 10)
  love.graphics.setFont(F(26))
  love.graphics.printf("Volver al menú", S.goBtn.x, S.goBtn.y + 14, S.goBtn.w, "center")
end

local function drawMenu()
  local suits = { "spades", "hearts", "diamonds", "clubs" }
  love.graphics.setColor(0.95, 0.9, 0.55); love.graphics.setFont(F(82))
  printC("STRATECORUM", 130)
  love.graphics.setColor(1, 1, 1, 0.7); love.graphics.setFont(F(24))
  printC("Juego de cartas estratégico · 2 a 6 jugadores · pass-and-play", 232)
  local mx, my = toVirtual(love.mouse.getPosition())
  -- conmutador de reglas
  for _, btn in ipairs(S.rulesBtns or {}) do
    local on = (S.rules == btn.rules)
    local hover = pointIn(mx, my, btn.x, btn.y, btn.w, btn.h)
    love.graphics.setColor(on and 0.25 or (hover and 0.2 or 0.12), on and 0.45 or (hover and 0.3 or 0.2), on and 0.35 or 0.18)
    rrect("fill", btn.x, btn.y, btn.w, btn.h, 10)
    love.graphics.setColor(on and { 0.95, 0.9, 0.55 } or { 1, 1, 1, 0.35 }); love.graphics.setLineWidth(on and 3 or 1.5)
    rrect("line", btn.x, btn.y, btn.w, btn.h, 10)
    love.graphics.setColor(1, 1, 1, on and 1 or 0.6); love.graphics.setFont(F(22))
    love.graphics.printf((btn.rules == 2) and "Reglas v2" or "Reglas v3", btn.x, btn.y + 11, btn.w, "center")
  end
  love.graphics.setColor(1, 1, 1, 0.6); love.graphics.setFont(F(14))
  printC(S.rules == 3 and "v3: ocultar y reordenar vidas · trébol bajo una vida = escudo, rayo = trampa que golpea al atacante · K reparte el combo · J revela · Q desarma · x3 a todo el combo"
                     or "v2: el manual clásico · J/Q roban banco al destruir · la K sola reparte 13 entre dos vidas", 342)
  for i, s in ipairs(suits) do
    local col = (s == "hearts" or s == "diamonds") and { 0.85, 0.2, 0.25 } or { 0.9, 0.9, 0.95 }
    local bob = math.sin(S.t * 2 + i) * 8
    Card.suit(s, VW / 2 - 180 + (i - 1) * 120, 385 + bob, 16, col, 0.9)
  end
  love.graphics.setColor(1, 1, 1, 0.85); love.graphics.setFont(F(26))
  printC("Elegí la cantidad de jugadores", 408)
  for _, btn in ipairs(S.menuBtns) do
    local hover = pointIn(mx, my, btn.x, btn.y, btn.w, btn.h)
    love.graphics.setColor(hover and 0.35 or 0.18, hover and 0.5 or 0.3, hover and 0.4 or 0.25)
    rrect("fill", btn.x, btn.y, btn.w, btn.h, 12)
    love.graphics.setColor(0.95, 0.9, 0.55); love.graphics.setLineWidth(hover and 3 or 2)
    rrect("line", btn.x, btn.y, btn.w, btn.h, 12)
    love.graphics.setColor(1, 1, 1); love.graphics.setFont(F(46))
    love.graphics.printf(tostring(btn.n), btn.x, btn.y + 20, btn.w, "center")
    love.graphics.setFont(F(13)); love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.printf(E.LIVES_PER[btn.n] .. " vidas" .. (E.DECKS_PER[btn.n] > 1 and " · 2 barajas" or ""), btn.x - 10, btn.y + btn.h + 6, btn.w + 20, "center")
  end
  love.graphics.setColor(1, 1, 1, 0.55); love.graphics.setFont(F(15))
  printC("Corazones = vidas · Picas = rayos (ataque) · Tréboles = suerte y defensa · Diamantes = dinero", 600)
  printC("Robás 2 por turno, 3 movimientos, límite de mano 7 · el daño se acumula bajo la vida · figuras J/Q/K/A = 11/12/13/14", 624)
  love.graphics.setColor(1, 1, 1, 0.4)
  printC("ESC menú · F pantalla completa · M sonido · S velocidad · E terminar turno · clic derecho cancela", 672)
end

function love.draw()
  if S.selftest then return end
  love.graphics.push()
  love.graphics.translate(S.offx, S.offy)
  love.graphics.scale(S.scale)
  love.graphics.setScissor(S.offx, S.offy, VW * S.scale, VH * S.scale)
  if S.shake > 0 then love.graphics.translate((love.math.random() - 0.5) * S.shake, (love.math.random() - 0.5) * S.shake) end

  drawBackground()
  if S.state == "menu" or not G then
    drawMenu()
  else
    drawBoard()
    drawCards()
    PFX.draw()
    drawHUD()
    if S.state == "passing" then drawPassing() end
    if S.state == "gameover" then drawGameOver() end
  end
  drawMessage()

  love.graphics.setScissor()
  love.graphics.pop()
end
