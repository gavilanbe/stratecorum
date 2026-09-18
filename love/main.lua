-- STRATECORUM — juego de cartas (LÖVE 11.x)
-- 2 a 6 jugadores, pass-and-play. Todo dibujado por código.

local flux  = require("lib.tween")
local Deck  = require("src.deck")
local Card  = require("src.cardart")
local PFX   = require("src.particles")
local Audio = require("src.audio")

local CW, CH = Deck.CARDW, Deck.CARDH
local VW, VH = 1280, 800

local DECK_POS    = { x = VW / 2 - 230, y = VH / 2 - 6 }
local DISCARD_POS = { x = VW / 2,        y = VH / 2 - 6 }
local GRAVE_POS   = { x = VW / 2 + 230,  y = VH / 2 - 6 }
local DUEL_A      = { x = VW / 2 - 70,   y = VH / 2 - 130 }
local DUEL_B      = { x = VW / 2 + 70,   y = VH / 2 - 130 }

local LIVES_PER = { [2] = 6, [3] = 4, [4] = 3, [5] = 2, [6] = 2 }

local G = { state = "boot", scale = 1, offx = 0, offy = 0 }

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
local function toVirtual(mx, my) return (mx - G.offx) / G.scale, (my - G.offy) / G.scale end
local function printC(text, y, w) love.graphics.printf(text, 0, y, w or VW, "center") end

local function lock()   G.busy = (G.busy or 0) + 1 end
local function unlock() G.busy = math.max(0, (G.busy or 0) - 1) end
local function isBusy() return (G.busy or 0) > 0 end

local function say(msg, color)
  G.message = msg; G.messageColor = color or { 1, 1, 1 }; G.messageT = 2.6
end

local function moveCard(card, x, y, t, opts)
  opts = opts or {}
  local tw = flux.to(card, t or 0.4, { x = x, y = y, rot = opts.rot or card.rot, scale = opts.scale or card.scale })
  tw:ease(opts.ease or "quadout")
  if opts.delay then tw:delay(opts.delay) end
  if opts.oncomplete then tw:oncomplete(opts.oncomplete) end
  return tw
end

local function flip(card, faceUp, t)
  t = t or 0.13
  flux.to(card, t, { flipScale = 0 }):ease("quadin"):oncomplete(function()
    card.faceUp = faceUp
    flux.to(card, t, { flipScale = 1 }):ease("quadout")
  end)
end

local function afterDelay(t, fn)
  local d = { v = 0 }
  flux.to(d, t, { v = 1 }):oncomplete(fn)
end

----------------------------------------------------------------------
-- Forward declarations
----------------------------------------------------------------------
local layoutAll, layoutHand, layoutLives, handTargets, computeSeats
local newGame, dealOpening, beginPass, startTurn, endTurn, drawForTurn
local onCardChosen, beginAttack, resolveAttack, onTargetChosen, eliminateLife, doCritDuel, cancelAttack
local actSaveLuck, actSaveMoney, actPlaceLife, actRedJoker, actUseLuck, actUseMoney
local buildButtons, updateHover, checkWin, useMove, drawFromDeck, discardCard
local removeFromHand, aliveCount
local drawBackground, drawBoard, drawCards, drawHUD, drawPassing, drawGameOver, drawMessage, drawMenu
local startNewGame, menuClick, initMenu

----------------------------------------------------------------------
-- Estado / setup
----------------------------------------------------------------------
local function makePlayer(i)
  return { idx = i, name = "Jugador " .. i, hand = {}, lives = {},
           luck = 0, money = 0, dispLuck = 0, dispMoney = 0 }
end

function aliveCount(p)
  local n = 0
  for _, L in ipairs(p.lives) do if not L.dead then n = n + 1 end end
  return n
end

function drawFromDeck()
  if #G.deck == 0 then
    for i = #G.discard, 1, -1 do
      local c = table.remove(G.discard)
      c.faceUp = false; c._z = 1
      G.deck[#G.deck + 1] = c
    end
    Deck.shuffle(G.deck)
    for i, c in ipairs(G.deck) do c.x = DECK_POS.x - i * 0.25; c.y = DECK_POS.y - i * 0.25 end
  end
  return table.remove(G.deck)
end

function removeFromHand(p, card)
  for i, c in ipairs(p.hand) do if c == card then table.remove(p.hand, i); return end end
end

function discardCard(card)
  card._z = 12
  card.glow = 0
  local jitter = (love.math.random() - 0.5)
  moveCard(card, DISCARD_POS.x + jitter * 10, DISCARD_POS.y + jitter * 8, 0.35, { rot = jitter * 0.4, scale = 1 })
  afterDelay(0.18, function() card.faceUp = true end)
  G.discard[#G.discard + 1] = card
end

function newGame(numPlayers)
  numPlayers = numPlayers or 2
  G.numPlayers = numPlayers
  local livesEach = LIVES_PER[numPlayers] or 3
  local draw, lifeHearts = Deck.build(numPlayers, livesEach)

  G.deck, G.discard, G.graveyard = draw, {}, {}
  G.players = {}
  for i = 1, numPlayers do G.players[i] = makePlayer(i) end
  for i = 1, numPlayers do
    for _ = 1, livesEach do
      local c = table.remove(lifeHearts)
      if c then
        c.faceUp = false; c._z = 5
        G.players[i].lives[#G.players[i].lives + 1] = { card = c, dead = false, accumulated = 0 }
      end
    end
  end

  G.allCards = {}
  for i, c in ipairs(G.deck) do
    c._z = 1; c.faceUp = false
    c.x = DECK_POS.x - i * 0.25; c.y = DECK_POS.y - i * 0.25
    G.allCards[#G.allCards + 1] = c
  end
  for _, p in ipairs(G.players) do
    for _, L in ipairs(p.lives) do
      L.card.x = DECK_POS.x; L.card.y = DECK_POS.y
      G.allCards[#G.allCards + 1] = L.card
    end
  end

  G.current = 1
  G.busy = 0
  G.ui = { mode = "idle", selected = nil, targets = {}, targetsNeeded = 1, pendingMult = 1, pendingCrit = nil }
  G.movesLeft = 3
  G.message = nil
  G.buttons = {}
  computeSeats()
  dealOpening()
end

----------------------------------------------------------------------
-- Layout
----------------------------------------------------------------------
local function opponentsOf(idx)
  local list = {}
  for k = 1, G.numPlayers do if k ~= idx then list[#list + 1] = k end end
  return list
end

function computeSeats()
  local cur = G.current
  G.players[cur]._lay = {
    handY = VH - 78, livesY = VH - 226, cx = VW / 2, faceUp = true, owner = "me",
    luckX = 96, luckY = VH - 120, moneyX = VW - 96, moneyY = VH - 120, width = 880,
  }
  local opp = opponentsOf(cur)
  local n = math.max(#opp, 1)
  local slotW = VW / n
  for i, pi in ipairs(opp) do
    local cx = slotW * (i - 0.5)
    G.players[pi]._lay = {
      handY = 72, livesY = 214, cx = cx, faceUp = false, owner = "opp",
      luckX = cx - 150, luckY = 60, moneyX = cx + 150, moneyY = 60,
      width = math.min(880, slotW - 30),
    }
  end
end

function handTargets(p)
  local lay = p._lay
  local n = #p.hand
  if n == 0 then return {} end
  local spacing = math.min(CW + 14, (lay.width or 760) / n)
  local startx = lay.cx - (n - 1) * spacing / 2
  local out = {}
  for i = 1, n do out[i] = { x = startx + (i - 1) * spacing, y = lay.handY } end
  return out
end

function layoutHand(p, animate, t)
  local tg = handTargets(p)
  for i, c in ipairs(p.hand) do
    c.w, c.h = CW, CH
    c._home = { x = tg[i].x, y = tg[i].y }
    if animate then moveCard(c, tg[i].x, tg[i].y, t or 0.32, { scale = 1, rot = 0 })
    else c.x, c.y = tg[i].x, tg[i].y end
  end
end

function layoutLives(p, animate, t)
  local lay = p._lay
  local alive = {}
  for _, L in ipairs(p.lives) do if not L.dead then alive[#alive + 1] = L end end
  local n = #alive
  if n == 0 then return end
  local spacing = math.min(CW + 12, (lay.width or 760) / n)
  local startx = lay.cx - (n - 1) * spacing / 2
  for i, L in ipairs(alive) do
    local c = L.card
    c.w, c.h = CW, CH
    local tx, ty = startx + (i - 1) * spacing, lay.livesY
    L._home = { x = tx, y = ty }
    if animate then moveCard(c, tx, ty, t or 0.32, { scale = 1, rot = 0 })
    else c.x, c.y = tx, ty end
  end
end

function layoutAll(animate)
  computeSeats()
  for _, p in ipairs(G.players) do layoutHand(p, animate); layoutLives(p, animate) end
end

----------------------------------------------------------------------
-- Reparto inicial
----------------------------------------------------------------------
function dealOpening()
  lock()
  G.state = "dealing"
  local d = 0
  -- repartir 5 cartas a cada jugador
  for round = 1, 5 do
    for _, p in ipairs(G.players) do
      local c = drawFromDeck()
      if c then
        c.x, c.y = DECK_POS.x, DECK_POS.y; c.faceUp = false; c._z = 6
        p.hand[#p.hand + 1] = c
      end
    end
  end
  for _, p in ipairs(G.players) do
    local tg = handTargets(p)
    for i, c in ipairs(p.hand) do
      c._home = { x = tg[i].x, y = tg[i].y }
      moveCard(c, tg[i].x, tg[i].y, 0.4, { delay = d, ease = "backout",
        oncomplete = function() Audio.play("deal"); PFX.deal(c.x, c.y) end })
      d = d + 0.07
    end
  end
  -- vidas a sus ranuras
  for _, p in ipairs(G.players) do
    local lay = p._lay
    local n = #p.lives
    local spacing = math.min(CW + 12, (lay.width or 760) / math.max(n, 1))
    local startx = lay.cx - (n - 1) * spacing / 2
    for i, L in ipairs(p.lives) do
      local c = L.card
      c.x, c.y = DECK_POS.x, DECK_POS.y; c.faceUp = false; c._z = 5
      local tx = startx + (i - 1) * spacing
      L._home = { x = tx, y = lay.livesY }
      moveCard(c, tx, lay.livesY, 0.45, { delay = d, ease = "quadout",
        oncomplete = function() Audio.play("deal") end })
      d = d + 0.05
    end
  end
  afterDelay(d + 0.5, function() unlock(); beginPass() end)
end

----------------------------------------------------------------------
-- Turnos
----------------------------------------------------------------------
function beginPass()
  G.state = "passing"
  for _, p in ipairs(G.players) do
    for _, c in ipairs(p.hand) do c.faceUp = false end
  end
end

function drawForTurn()
  local p = G.players[G.current]
  local c = drawFromDeck()
  if not c then return end
  c.x, c.y = DECK_POS.x, DECK_POS.y; c.faceUp = false; c.scale = 1; c._z = 6
  p.hand[#p.hand + 1] = c
  lock()
  layoutHand(p, true)
  afterDelay(0.18, function() flip(c, p._lay.faceUp) end)
  afterDelay(0.5, function() Audio.play("deal"); unlock() end)
end

function startTurn()
  G.state = "playing"
  G.ui.mode = "idle"; G.ui.selected = nil; G.ui.targets = {}
  G.ui.pendingMult = 1; G.ui.pendingCrit = nil
  G.movesLeft = 3
  layoutAll(true)
  local p = G.players[G.current]
  for _, c in ipairs(p.hand) do flip(c, true) end
  Audio.play("turn")
  drawForTurn()
end

function endTurn()
  local p = G.players[G.current]
  for _, c in ipairs(p.hand) do flip(c, false) end
  G.ui.mode = "idle"
  afterDelay(0.28, function()
    repeat
      G.current = G.current % G.numPlayers + 1
    until aliveCount(G.players[G.current]) > 0
    beginPass()
  end)
end

function useMove()
  G.movesLeft = G.movesLeft - 1
  if G.movesLeft <= 0 then
    afterDelay(0.55, function() if G.state == "playing" then endTurn() end end)
  end
end

function checkWin()
  local alive = {}
  for _, p in ipairs(G.players) do if aliveCount(p) > 0 then alive[#alive + 1] = p end end
  if #alive <= 1 then
    G.state = "gameover"; G.winner = alive[1]
    Audio.play("win"); PFX.crit(VW / 2, VH / 2)
    return true
  end
  return false
end

----------------------------------------------------------------------
-- Acciones de recursos
----------------------------------------------------------------------
function actSaveLuck(card)
  local p = G.players[G.current]
  removeFromHand(p, card)
  p.luck = p.luck + card.value
  lock(); discardCard(card); layoutHand(p, true)
  PFX.luck(p._lay.luckX, p._lay.luckY); Audio.play("luck")
  say(p.name .. " ahorró " .. card.value .. " de suerte 🍀", { 0.6, 1, 0.7 })
  afterDelay(0.4, unlock)
  useMove()
end

function actSaveMoney(card)
  local p = G.players[G.current]
  removeFromHand(p, card)
  p.money = p.money + card.value
  lock(); discardCard(card); layoutHand(p, true)
  PFX.coins(p._lay.moneyX, p._lay.moneyY); Audio.play("coin")
  say(p.name .. " ahorró " .. card.value .. " de dinero 💰", { 1, 0.9, 0.5 })
  afterDelay(0.4, unlock)
  useMove()
end

function actPlaceLife(card)
  local p = G.players[G.current]
  removeFromHand(p, card)
  card._z = 5
  flip(card, false)
  p.lives[#p.lives + 1] = { card = card, dead = false, accumulated = 0 }
  lock(); layoutHand(p, true); layoutLives(p, true)
  PFX.heal(card.x, card.y); Audio.play("life")
  say(p.name .. " colocó una nueva vida ❤️", { 1, 0.6, 0.7 })
  afterDelay(0.4, unlock)
  useMove()
end

function actRedJoker(card)
  local p = G.players[G.current]
  local life = table.remove(G.graveyard)
  if not life then Audio.play("error"); say("El cementerio está vacío", { 1, 0.6, 0.6 }); return end
  removeFromHand(p, card)
  lock(); discardCard(card)
  life.faceUp = false; life._z = 5; flip(life, false)
  p.lives[#p.lives + 1] = { card = life, dead = false, accumulated = 0 }
  layoutHand(p, true); layoutLives(p, true)
  moveCard(life, p._lay.cx, p._lay.livesY, 0.5, {})
  PFX.heal(p._lay.cx, p._lay.livesY); Audio.play("life")
  say("Joker Rojo: ¡revivió una vida del cementerio! 🃏❤️", { 1, 0.5, 0.6 })
  afterDelay(0.5, unlock)
  useMove()
end

function actUseLuck(tier)
  local p = G.players[G.current]
  if p.luck < tier then Audio.play("error"); say("No tenés suficiente suerte"); return end
  p.luck = p.luck - tier
  local mult = (tier == 10 and 2) or (tier == 20 and 3) or 4
  G.ui.pendingCrit = { mult = mult }
  G.ui.mode = "idle"
  PFX.luck(p._lay.luckX, p._lay.luckY); Audio.play("luck")
  say("Suerte cargada: intento de crítico x" .. mult .. ". ¡Ahora atacá! 🌟", { 0.6, 1, 0.7 })
  useMove()
end

function actUseMoney(tier)
  local p = G.players[G.current]
  if p.money < tier then Audio.play("error"); say("No tenés suficiente dinero"); return end
  p.money = p.money - tier
  G.ui.mode = "idle"
  PFX.coins(p._lay.moneyX, p._lay.moneyY); Audio.play("coin")
  if tier == 10 then
    lock()
    for _ = 1, 3 do
      local c = drawFromDeck()
      if c then
        c.x, c.y = DECK_POS.x, DECK_POS.y; c.faceUp = false; c._z = 6
        p.hand[#p.hand + 1] = c
        flip(c, p._lay.faceUp)
      end
    end
    layoutHand(p, true)
    say("Dinero: ¡robaste 3 cartas! 💸", { 1, 0.9, 0.5 })
    afterDelay(0.5, unlock)
  elseif tier == 20 then
    G.ui.pendingMult = 2
    say("Dinero: x2 al próximo ataque (sin depender de la suerte). ¡Atacá! 💸", { 1, 0.9, 0.5 })
  elseif tier == 30 then
    local c = table.remove(G.graveyard)
    if not c then p.money = p.money + 30; Audio.play("error"); say("El cementerio está vacío"); return end
    c._z = 6; flip(c, p._lay.faceUp)
    p.hand[#p.hand + 1] = c
    lock()
    moveCard(c, p._lay.cx, p._lay.handY, 0.5, {})
    layoutHand(p, true)
    say("Dinero: compraste una vida del cementerio (va a tu mano) 💀➡️❤️", { 1, 0.9, 0.5 })
    afterDelay(0.5, unlock)
  end
  useMove()
end

----------------------------------------------------------------------
-- Ataques
----------------------------------------------------------------------
function beginAttack(card)
  G.ui.mode = "targeting"
  G.ui.selected = card
  G.ui.targets = {}
  G.ui.targetsNeeded = (card.suit == "spades" and card.rank == 13) and 2 or 1
  card.glow = 1
  if G.ui.targetsNeeded == 2 then
    say("K: elegí 2 vidas rivales para dividir el ataque ⚔️", { 1, 0.85, 0.5 })
  else
    say("Elegí una vida rival para atacar ⚔️", { 1, 0.85, 0.5 })
  end
end

function cancelAttack()
  if G.ui.selected then G.ui.selected.glow = 0 end
  for _, p in ipairs(G.players) do for _, L in ipairs(p.lives) do L.card.glow = 0 end end
  G.ui.mode = "idle"; G.ui.selected = nil; G.ui.targets = {}
end

function onTargetChosen(owner, L)
  for _, t in ipairs(G.ui.targets) do if t.life == L then return end end
  G.ui.targets[#G.ui.targets + 1] = { owner = owner, life = L }
  L.card.glow = 1
  if #G.ui.targets >= G.ui.targetsNeeded then resolveAttack() end
end

function doCritDuel(attacker, defender, cb)
  lock()
  local a, b = drawFromDeck(), drawFromDeck()
  for _, c in ipairs({ a, b }) do
    if c then c.x, c.y = DECK_POS.x, DECK_POS.y; c.faceUp = false; c._z = 30 end
  end
  if a then moveCard(a, DUEL_A.x, DUEL_A.y, 0.4, { scale = 1.15 }) end
  if b then moveCard(b, DUEL_B.x, DUEL_B.y, 0.4, { scale = 1.15 }) end
  afterDelay(0.45, function()
    if a then flip(a, true) end
    if b then flip(b, true) end
    Audio.play("select")
  end)
  afterDelay(1.25, function()
    local av = a and (a.value * 100 + a.priority) or 0
    local bv = b and (b.value * 100 + b.priority) or 0
    local success = av > bv
    if success then
      PFX.crit((DUEL_A.x + DUEL_B.x) / 2, DUEL_A.y); Audio.play("crit")
      say("¡CRÍTICO! El duelo lo gana " .. attacker.name .. " ✨", { 1, 0.9, 0.3 })
    else
      say("Crítico fallido… la suerte no acompañó", { 0.8, 0.8, 0.85 })
    end
    if a then discardCard(a) end
    if b then discardCard(b) end
    afterDelay(0.5, function() unlock(); cb(success) end)
  end)
end

function resolveAttack()
  local attacker = G.players[G.current]
  local src = G.ui.selected
  local targets = G.ui.targets
  if not src or #targets < G.ui.targetsNeeded then return end
  G.ui.mode = "resolving"

  local baseMult = G.ui.pendingMult or 1
  local crit = G.ui.pendingCrit

  local function finish(critMult)
    local mult = baseMult * (critMult or 1)
    lock()
    removeFromHand(attacker, src)
    src.glow = 0; src._z = 30; src.faceUp = true
    local focus = targets[1].life.card
    moveCard(src, focus.x, focus.y - 26, 0.28, { scale = 1.18, ease = "quadin",
      oncomplete = function()
        Audio.play("attack")
        for _, tt in ipairs(targets) do
          local L, owner = tt.life, tt.owner
          flip(L.card, true)
          local atk = src.isJoker and 9999 or (src.value * mult)
          L.accumulated = L.accumulated + atk
          local elim
          if src.isJoker and src.jokerColor == "black" then
            elim = true
          elseif L.accumulated > L.card.value then
            elim = true
          elseif L.accumulated == L.card.value then
            elim = (src.priority >= L.card.priority)
          else
            elim = false
          end
          PFX.hit(L.card.x, L.card.y); Audio.play("hit")
          if elim then
            eliminateLife(owner, L, src, attacker)
          else
            say("La vida resistió (" .. L.accumulated .. "/" .. L.card.value .. ")", { 0.9, 0.9, 1 })
          end
        end
        discardCard(src)
        afterDelay(0.45, function()
          unlock()
          G.ui.pendingMult = 1; G.ui.pendingCrit = nil
          G.ui.selected = nil; G.ui.targets = {}; G.ui.mode = "idle"
          if not checkWin() then useMove() end
        end)
      end })
  end

  if crit then
    doCritDuel(attacker, targets[1].owner, function(s) finish(s and crit.mult or 1) end)
  else
    finish(1)
  end
end

function eliminateLife(owner, L, src, attacker)
  L.dead = true
  local card = L.card
  PFX.destroy(card.x, card.y); Audio.play("destroy")

  local toHand = false
  if src then
    if src.suit == "spades" and src.rank == 11 then
      local steal = math.min(20, owner.luck)
      owner.luck = owner.luck - steal; attacker.luck = attacker.luck + steal
      say("J: robó " .. steal .. " de suerte al rival 🍀", { 0.6, 1, 0.7 })
      PFX.luck(attacker._lay.luckX, attacker._lay.luckY)
    elseif src.suit == "spades" and src.rank == 12 then
      local steal = math.min(20, owner.money)
      owner.money = owner.money - steal; attacker.money = attacker.money + steal
      say("Q: robó " .. steal .. " de dinero al rival 💰", { 1, 0.9, 0.5 })
      PFX.coins(attacker._lay.moneyX, attacker._lay.moneyY)
    elseif src.suit == "spades" and src.rank == 1 then
      toHand = true
    end
  end

  for i, x in ipairs(owner.lives) do if x == L then table.remove(owner.lives, i); break end end

  if toHand then
    card._z = 6
    flip(card, attacker._lay.faceUp)
    attacker.hand[#attacker.hand + 1] = card
    moveCard(card, attacker._lay.cx, attacker._lay.handY, 0.55, { rot = 0, scale = 1 })
    layoutHand(attacker, true)
    say("As: ¡eliminó la vida y la robó a su mano! 🂡", { 1, 0.8, 0.4 })
  else
    card._z = 12
    flip(card, false)
    moveCard(card, GRAVE_POS.x + (love.math.random() - 0.5) * 10, GRAVE_POS.y + (love.math.random() - 0.5) * 8,
      0.55, { rot = (love.math.random() - 0.5) * 0.5, scale = 1 })
    G.graveyard[#G.graveyard + 1] = card
  end
  layoutLives(owner, true)
end

----------------------------------------------------------------------
-- Dispatch de clicks
----------------------------------------------------------------------
function onCardChosen(card)
  if G.ui.mode ~= "idle" or isBusy() or G.movesLeft <= 0 then
    if G.movesLeft <= 0 then say("No te quedan movimientos. Terminá el turno."); Audio.play("error") end
    return
  end
  Audio.play("select")
  if card.isJoker then
    if card.jokerColor == "red" then actRedJoker(card) else beginAttack(card) end
  elseif card.suit == "clubs"    then actSaveLuck(card)
  elseif card.suit == "diamonds" then actSaveMoney(card)
  elseif card.suit == "hearts"   then actPlaceLife(card)
  elseif card.suit == "spades"   then beginAttack(card)
  end
end

local function cardHit(c, x, y)
  local w, h = c.w, c.h
  return x >= c.x - w / 2 and x <= c.x + w / 2 and y >= c.y - h / 2 and y <= c.y + h / 2
end
local function handCardAt(x, y, p)
  local found
  for _, c in ipairs(p.hand) do if cardHit(c, x, y) then found = c end end
  return found
end
local function lifeAt(x, y)
  for _, p in ipairs(G.players) do
    for _, L in ipairs(p.lives) do
      if not L.dead and cardHit(L.card, x, y) then return p, L end
    end
  end
end

----------------------------------------------------------------------
-- Botones
----------------------------------------------------------------------
local function addBtn(list, label, x, y, w, h, enabled, onclick, color)
  list[#list + 1] = { label = label, x = x, y = y, w = w, h = h,
                      enabled = enabled ~= false, onclick = onclick, color = color, hover = false }
end

function buildButtons()
  local b = {}
  local p = G.players[G.current]
  local idle = (G.ui.mode == "idle") and not isBusy() and G.movesLeft > 0

  if G.ui.mode == "targeting" then
    addBtn(b, "Cancelar", VW / 2 - 80, VH - 50, 160, 38, true, cancelAttack, { 0.7, 0.3, 0.3 })
  elseif G.ui.mode == "luckmenu" then
    local opts = { { 10, "x2 crítico (10)" }, { 20, "x3 crítico (20)" }, { 30, "x4 crítico (30)" } }
    for i, o in ipairs(opts) do
      addBtn(b, o[2], 40, VH - 200 + (i - 1) * 46, 200, 40, p.luck >= o[1],
        function() actUseLuck(o[1]) end, { 0.2, 0.6, 0.3 })
    end
    addBtn(b, "Cancelar", 40, VH - 200 + 3 * 46, 200, 36, true, function() G.ui.mode = "idle" end, { 0.5, 0.5, 0.55 })
  elseif G.ui.mode == "moneymenu" then
    local opts = { { 10, "Robar 3 cartas (10)" }, { 20, "x2 ataque (20)" }, { 30, "Comprar vida (30)" } }
    for i, o in ipairs(opts) do
      addBtn(b, o[2], VW - 250, VH - 200 + (i - 1) * 46, 210, 40, p.money >= o[1],
        function() actUseMoney(o[1]) end, { 0.7, 0.55, 0.15 })
    end
    addBtn(b, "Cancelar", VW - 250, VH - 200 + 3 * 46, 210, 36, true, function() G.ui.mode = "idle" end, { 0.5, 0.5, 0.55 })
  else
    addBtn(b, "Usar Suerte 🌟", 40, VH - 50, 200, 38, idle and p.luck >= 10,
      function() G.ui.mode = "luckmenu" end, { 0.2, 0.6, 0.3 })
    addBtn(b, "Usar Dinero 💸", VW - 250, VH - 50, 210, 38, idle and p.money >= 10,
      function() G.ui.mode = "moneymenu" end, { 0.7, 0.55, 0.15 })
    addBtn(b, "Terminar Turno", VW / 2 - 90, VH - 50, 180, 38, (G.ui.mode == "idle") and not isBusy(),
      function() endTurn() end, { 0.3, 0.35, 0.5 })
  end
  G.buttons = b
end

----------------------------------------------------------------------
-- Hover / update
----------------------------------------------------------------------
function updateHover(dt)
  local mx, my = toVirtual(love.mouse.getPosition())
  local p = G.players[G.current]
  local hovered = (not isBusy() and G.ui.mode == "idle") and handCardAt(mx, my, p) or nil

  for _, c in ipairs(p.hand) do
    local target = (c == hovered) and 22 or 0
    c._lift = lerp(c._lift or 0, target, math.min(1, dt * 14))
    if c._home and not isBusy() and (G.ui.mode == "idle" or G.ui.mode == "luckmenu" or G.ui.mode == "moneymenu") then
      c.y = c._home.y - c._lift
      c.scale = 1 + (c._lift / 22) * 0.08
    end
  end

  -- resaltado de objetivos
  for _, pl in ipairs(G.players) do
    for _, L in ipairs(pl.lives) do L.card.glow = 0 end
  end
  if G.ui.mode == "targeting" then
    for _, pl in ipairs(G.players) do
      if pl.idx ~= G.current then
        for _, L in ipairs(pl.lives) do
          if not L.dead then L.card.glow = 0.35 + 0.3 * math.abs(math.sin(G.t * 5)) end
        end
      end
    end
    for _, t in ipairs(G.ui.targets) do t.life.card.glow = 1 end
    if G.ui.selected then G.ui.selected.glow = 1 end
  end

  for _, btn in ipairs(G.buttons) do btn.hover = pointIn(mx, my, btn.x, btn.y, btn.w, btn.h) end
end

----------------------------------------------------------------------
-- LÖVE callbacks
----------------------------------------------------------------------
local function computeScale()
  local w, h = love.graphics.getDimensions()
  G.scale = math.min(w / VW, h / VH)
  G.offx = (w - VW * G.scale) / 2
  G.offy = (h - VH * G.scale) / 2
end

function love.resize() computeScale() end

function love.load()
  love.graphics.setDefaultFilter("linear", "linear")
  love.graphics.setBackgroundColor(0.04, 0.07, 0.05)
  Audio.load()
  computeScale()
  G.t = 0
  G.allCards = {}
  G.players = {}
  initMenu()
  G.state = "menu"
end

function startNewGame(n)
  flux.clear(); PFX.clear()
  newGame(n)
end

function initMenu()
  G.menuBtns = {}
  local nums = { 2, 3, 4, 5, 6 }
  local bw, bh, gap = 96, 96, 22
  local total = #nums * bw + (#nums - 1) * gap
  local sx = VW / 2 - total / 2
  for i, n in ipairs(nums) do
    G.menuBtns[i] = { n = n, x = sx + (i - 1) * (bw + gap), y = 450, w = bw, h = bh }
  end
end

function menuClick(x, y)
  for _, btn in ipairs(G.menuBtns) do
    if pointIn(x, y, btn.x, btn.y, btn.w, btn.h) then
      Audio.play("click"); startNewGame(btn.n); return
    end
  end
end

function love.update(dt)
  if dt > 0.1 then dt = 0.1 end
  G.t = (G.t or 0) + dt
  flux.update(dt)
  PFX.update(dt)
  if G.messageT and G.messageT > 0 then G.messageT = G.messageT - dt end
  for _, p in ipairs(G.players or {}) do
    p.dispLuck = lerp(p.dispLuck or 0, p.luck, math.min(1, dt * 8))
    p.dispMoney = lerp(p.dispMoney or 0, p.money, math.min(1, dt * 8))
  end
  if G.state == "playing" then
    buildButtons()
    updateHover(dt)
  else
    G.buttons = {}
  end
end

function love.mousepressed(mx, my, button)
  if button ~= 1 then return end
  local x, y = toVirtual(mx, my)

  if G.state == "menu" then menuClick(x, y); return end
  if G.state == "gameover" then
    if G.goBtn and pointIn(x, y, G.goBtn.x, G.goBtn.y, G.goBtn.w, G.goBtn.h) then
      Audio.play("click"); G.state = "menu"
    end
    return
  end
  if G.state == "passing" then
    if not isBusy() then Audio.play("turn"); startTurn() end
    return
  end
  if G.state ~= "playing" or isBusy() then return end

  for _, btn in ipairs(G.buttons or {}) do
    if btn.enabled and pointIn(x, y, btn.x, btn.y, btn.w, btn.h) then
      Audio.play("click"); btn.onclick(); return
    end
  end

  if G.ui.mode == "targeting" then
    local owner, L = lifeAt(x, y)
    if owner and owner.idx ~= G.current then onTargetChosen(owner, L)
    else Audio.play("error") end
    return
  end

  if G.ui.mode == "idle" then
    local c = handCardAt(x, y, G.players[G.current])
    if c then onCardChosen(c) end
  end
end

function love.keypressed(key)
  if key == "escape" then
    if G.state == "playing" and G.ui.mode == "targeting" then cancelAttack()
    elseif G.state == "playing" and (G.ui.mode == "luckmenu" or G.ui.mode == "moneymenu") then G.ui.mode = "idle"
    else G.state = "menu" end
  elseif key == "f" then
    love.window.setFullscreen(not love.window.getFullscreen())
    computeScale()
  end
end

----------------------------------------------------------------------
-- Render
----------------------------------------------------------------------
function drawBackground()
  love.graphics.setColor(0.05, 0.09, 0.06); love.graphics.rectangle("fill", 0, 0, VW, VH)
  love.graphics.setColor(0.10, 0.20, 0.14)
  love.graphics.ellipse("fill", VW / 2, VH / 2, VW * 0.62, VH * 0.52)
  love.graphics.setColor(0.07, 0.14, 0.10)
  love.graphics.ellipse("line", VW / 2, VH / 2, VW * 0.62, VH * 0.52)
  -- palos flotando de fondo
  local suits = { "spades", "hearts", "diamonds", "clubs" }
  for i = 1, 10 do
    local t = G.t * 0.25 + i
    local x = (VW * (0.05 + 0.1 * i) + math.sin(t) * 40) % VW
    local y = (VH * 0.5 + math.cos(t * 0.8 + i) * 260)
    local col = (i % 2 == 0) and { 1, 1, 1 } or { 0.7, 0.85, 0.7 }
    love.graphics.setColor(col[1], col[2], col[3], 0.04)
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

local function drawBank(x, y, kind, disp, glowAmt)
  love.graphics.setColor(0, 0, 0, 0.5); rrect("fill", x - 72, y - 27, 144, 54, 12)
  local c = kind == "luck" and { 0.3, 0.8, 0.4 } or { 0.9, 0.72, 0.25 }
  if glowAmt and glowAmt > 0 then
    love.graphics.setColor(c[1], c[2], c[3], 0.3 * glowAmt)
    rrect("fill", x - 76, y - 31, 152, 62, 14)
  end
  love.graphics.setColor(c[1], c[2], c[3], 1); love.graphics.setLineWidth(2)
  rrect("line", x - 72, y - 27, 144, 54, 12)
  if kind == "luck" then Card.suit("clubs", x - 46, y - 2, 11, c, 1)
  else Card.suit("diamonds", x - 46, y - 2, 11, c, 1) end
  love.graphics.setFont(F(30)); love.graphics.setColor(1, 1, 1, 1)
  love.graphics.printf(tostring(math.floor(disp + 0.5)), x - 30, y - 18, 92, "center")
end

function drawBoard()
  drawPilePlaceholder(DECK_POS, "Mazo", #G.deck)
  drawPilePlaceholder(DISCARD_POS, "Descarte", #G.discard)
  drawPilePlaceholder(GRAVE_POS, "Cementerio 💀", #G.graveyard)

  for _, p in ipairs(G.players) do
    local lay = p._lay
    local activeGlow = (p.idx == G.current and G.state == "playing") and (0.5 + 0.5 * math.sin(G.t * 3)) or 0
    drawBank(lay.luckX, lay.luckY, "luck", p.dispLuck, activeGlow)
    drawBank(lay.moneyX, lay.moneyY, "money", p.dispMoney, activeGlow)
    -- nombre
    love.graphics.setFont(F(18))
    if p.idx == G.current and G.state == "playing" then love.graphics.setColor(1, 0.95, 0.6)
    else love.graphics.setColor(1, 1, 1, 0.55) end
    local ny = lay.owner == "me" and lay.luckY - 52 or lay.luckY + 36
    love.graphics.printf(p.name .. "  (vidas: " .. aliveCount(p) .. ")", lay.cx - 200, ny, 400, "center")
  end
end

local function drawAccumMarkers()
  -- marca de daño acumulado en vidas reveladas
  for _, p in ipairs(G.players) do
    for _, L in ipairs(p.lives) do
      if not L.dead and L.card.faceUp and L.accumulated > 0 then
        local c = L.card
        love.graphics.setColor(0, 0, 0, 0.6)
        rrect("fill", c.x - 26, c.y + CH / 2 - 8, 52, 18, 5)
        love.graphics.setColor(1, 0.5, 0.4)
        love.graphics.setFont(F(13))
        love.graphics.printf(L.accumulated .. "/" .. c.value, c.x - 26, c.y + CH / 2 - 7, 52, "center")
      end
    end
  end
end

function drawCards()
  table.sort(G.allCards, function(a, b) return (a._z or 0) < (b._z or 0) end)
  for _, c in ipairs(G.allCards) do Card.draw(c) end
  drawAccumMarkers()
end

local function drawButton(btn)
  local col = btn.color or { 0.3, 0.35, 0.5 }
  local a = btn.enabled and 1 or 0.35
  if btn.hover and btn.enabled then a = 1 end
  love.graphics.setColor(col[1] * (btn.hover and 1.3 or 1), col[2] * (btn.hover and 1.3 or 1), col[3] * (btn.hover and 1.3 or 1), a)
  rrect("fill", btn.x, btn.y, btn.w, btn.h, 8)
  love.graphics.setColor(1, 1, 1, a)
  love.graphics.setLineWidth(2); rrect("line", btn.x, btn.y, btn.w, btn.h, 8)
  love.graphics.setFont(F(17))
  love.graphics.printf(btn.label, btn.x, btn.y + btn.h / 2 - 11, btn.w, "center")
end

function drawHUD()
  -- movimientos restantes
  love.graphics.setFont(F(16))
  love.graphics.setColor(1, 1, 1, 0.8)
  love.graphics.printf("Movimientos", VW / 2 - 100, VH - 96, 200, "center")
  for i = 1, 3 do
    local on = i <= G.movesLeft
    love.graphics.setColor(on and 1 or 0.25, on and 0.85 or 0.25, on and 0.4 or 0.25, on and 1 or 0.6)
    love.graphics.circle("fill", VW / 2 - 28 + (i - 1) * 28, VH - 70, 9)
  end

  -- indicadores de modificadores pendientes
  local p = G.players[G.current]
  local iy = VH - 300
  if G.ui.pendingCrit then
    love.graphics.setColor(0.3, 0.9, 0.4); love.graphics.setFont(F(18))
    love.graphics.printf("🌟 Crítico x" .. G.ui.pendingCrit.mult .. " listo", VW / 2 - 200, iy, 400, "center")
    iy = iy + 26
  end
  if (G.ui.pendingMult or 1) > 1 then
    love.graphics.setColor(0.95, 0.75, 0.3); love.graphics.setFont(F(18))
    love.graphics.printf("💸 Ataque x" .. G.ui.pendingMult .. " listo", VW / 2 - 200, iy, 400, "center")
  end

  for _, btn in ipairs(G.buttons or {}) do drawButton(btn) end
end

function drawMessage()
  if not G.message or (G.messageT or 0) <= 0 then return end
  local a = clamp(G.messageT / 0.6, 0, 1)
  local c = G.messageColor or { 1, 1, 1 }
  love.graphics.setFont(F(24))
  local w = F(24):getWidth(G.message) + 60
  love.graphics.setColor(0, 0, 0, 0.6 * a)
  rrect("fill", VW / 2 - w / 2, 14, w, 44, 10)
  love.graphics.setColor(c[1], c[2], c[3], a)
  love.graphics.printf(G.message, VW / 2 - w / 2, 24, w, "center")
end

function drawPassing()
  love.graphics.setColor(0, 0, 0, 0.85); love.graphics.rectangle("fill", 0, 0, VW, VH)
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(F(56)); printC("Turno de " .. G.players[G.current].name, VH / 2 - 90)
  love.graphics.setFont(F(24)); love.graphics.setColor(1, 1, 1, 0.7)
  printC("Que los demás no miren la pantalla 👀", VH / 2 - 14)
  local a = 0.55 + 0.45 * math.sin(G.t * 4)
  love.graphics.setColor(1, 1, 0.6, a); love.graphics.setFont(F(28))
  printC("Tocá la pantalla para empezar", VH / 2 + 60)
end

function drawGameOver()
  love.graphics.setColor(0, 0, 0, 0.82); love.graphics.rectangle("fill", 0, 0, VW, VH)
  love.graphics.setColor(1, 0.9, 0.3)
  love.graphics.setFont(F(64))
  printC("🏆 ¡" .. (G.winner and G.winner.name or "Nadie") .. " gana! 🏆", VH / 2 - 110)
  love.graphics.setColor(1, 1, 1, 0.8); love.graphics.setFont(F(24))
  printC("Último jugador con vidas en pie en Stratecorum", VH / 2 - 30)
  G.goBtn = { x = VW / 2 - 130, y = VH / 2 + 50, w = 260, h = 56 }
  local mx, my = toVirtual(love.mouse.getPosition())
  local hover = pointIn(mx, my, G.goBtn.x, G.goBtn.y, G.goBtn.w, G.goBtn.h)
  love.graphics.setColor(hover and 0.4 or 0.25, hover and 0.6 or 0.4, hover and 0.4 or 0.3)
  rrect("fill", G.goBtn.x, G.goBtn.y, G.goBtn.w, G.goBtn.h, 10)
  love.graphics.setColor(1, 1, 1); love.graphics.setLineWidth(2)
  rrect("line", G.goBtn.x, G.goBtn.y, G.goBtn.w, G.goBtn.h, 10)
  love.graphics.setFont(F(26))
  love.graphics.printf("Jugar de nuevo", G.goBtn.x, G.goBtn.y + 14, G.goBtn.w, "center")
end

function drawMenu()
  local suits = { "spades", "hearts", "diamonds", "clubs" }
  -- título
  love.graphics.setColor(0.95, 0.9, 0.55)
  love.graphics.setFont(F(82))
  printC("STRATECORUM", 150)
  love.graphics.setColor(1, 1, 1, 0.7)
  love.graphics.setFont(F(24))
  printC("Juego de cartas estratégico · 2 a 6 jugadores · pass-and-play", 250)

  -- palos decorativos
  for i, s in ipairs(suits) do
    local col = (s == "hearts" or s == "diamonds") and { 0.85, 0.2, 0.25 } or { 0.9, 0.9, 0.95 }
    local bob = math.sin(G.t * 2 + i) * 8
    Card.suit(s, VW / 2 - 180 + (i - 1) * 120, 360 + bob, 22, col, 0.9)
  end

  love.graphics.setColor(1, 1, 1, 0.85); love.graphics.setFont(F(26))
  printC("Elegí la cantidad de jugadores", 400)

  local mx, my = toVirtual(love.mouse.getPosition())
  for _, btn in ipairs(G.menuBtns) do
    local hover = pointIn(mx, my, btn.x, btn.y, btn.w, btn.h)
    love.graphics.setColor(hover and 0.35 or 0.18, hover and 0.5 or 0.3, hover and 0.4 or 0.25)
    rrect("fill", btn.x, btn.y, btn.w, btn.h, 12)
    love.graphics.setColor(0.95, 0.9, 0.55); love.graphics.setLineWidth(hover and 3 or 2)
    rrect("line", btn.x, btn.y, btn.w, btn.h, 12)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(F(46))
    love.graphics.printf(tostring(btn.n), btn.x, btn.y + 20, btn.w, "center")
  end
  love.graphics.setColor(1, 1, 1, 0.45); love.graphics.setFont(F(16))
  printC("(2 jugadores recomendado · ESC para volver al menú · F pantalla completa)", 600)
end

function love.draw()
  love.graphics.push()
  love.graphics.translate(G.offx, G.offy)
  love.graphics.scale(G.scale)
  love.graphics.setScissor(G.offx, G.offy, VW * G.scale, VH * G.scale)

  drawBackground()
  if G.state == "menu" then
    drawMenu()
  else
    drawBoard()
    drawCards()
    PFX.draw()
    drawHUD()
    if G.state == "passing" then drawPassing() end
    if G.state == "gameover" then drawGameOver() end
  end
  drawMessage()

  love.graphics.setScissor()
  love.graphics.pop()
end
