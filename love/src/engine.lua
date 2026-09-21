-- MOTOR DE REGLAS · Stratecorum v2 / v3 (G.v3)
-- Port 1:1 del bloque "MOTOR DE REGLAS" de web/index.html. No depende de LÖVE:
-- v3 (docs/MANUAL_V3.md): ocultar y reordenar vidas, una carta boca abajo bajo una vida (L.ward: trébol =
-- escudo que resta su valor, rayo = trampa que salta y golpea al atacante), K acumulativa (reparto de
-- cualquier combo con K), x3 de la suerte a todo el combo, J revela una vida oculta del rival golpeado,
-- Q desarma y roba del banco más rico, dinero 10 roba 2 y descarta 1.
-- todo lo visual/asíncrono pasa por G.hooks = { wait(s), decide(p, kind, ctx), fx = {...}, log(s) }.
-- Las funciones que esperan (wait) o piden decisiones (decide) deben correr dentro de una
-- corrutina cuando el driver lo necesite (LÖVE); en la autoprueba los hooks devuelven al instante.
local Deck = require("src.deck")

local E = {}

E.LET = Deck.LET
E.LIVES_PER = { [2] = 6, [3] = 4, [4] = 3, [5] = 3, [6] = 3 }
E.DECKS_PER = { [2] = 1, [3] = 1, [4] = 1, [5] = 2, [6] = 2 }

local function bv(c) return (c.r and c.r > 0) and math.min(c.r, 10) or 0 end   -- valor en banco / defensa
local function dv(c) if c.s == "JN" or c.s == "JR" then return 15 end return c.r end -- valor en duelo de crítico
local function total(b) local s = 0; for _, c in ipairs(b) do s = s + bv(c) end; return s end
local function rem(L) return L.card.r - L.dmg end
local function isJoker(c) return c.s == "JN" or c.s == "JR" end
local function rm(arr, x)
  for i, v in ipairs(arr) do if v == x then table.remove(arr, i); return true end end
  return false
end
local function has(arr, x) for _, v in ipairs(arr) do if v == x then return true end end; return false end
local function cname(c) return E.LET[c.r] or tostring(c.r) end
local function push(arr, ...) for i = 1, select("#", ...) do arr[#arr + 1] = select(i, ...) end end
local function pushAll(arr, src) for _, c in ipairs(src) do arr[#arr + 1] = c end end

E.bv, E.dv, E.total, E.rem, E.isJoker, E.rm, E.has, E.cname = bv, dv, total, rem, isJoker, rm, has, cname

local NOOP = function() end
local function fx(G, name, ...)
  local f = G.hooks.fx and G.hooks.fx[name]
  if f then return f(...) end
end
local function wait(G, s) return G.hooks.wait(s) end

-- Pago con cartas enteras: combinación de menor suma ≥ coste (a igual suma, la de más cartas).
local function payCombo(bank, cost)
  local n = #bank
  local best = nil
  if n > 16 then  -- bancos enormes (botín): voraz de menor a mayor para no explotar 2^n
    local idx = {}
    for i = 1, n do idx[i] = i end
    table.sort(idx, function(a, b) return bv(bank[a]) < bv(bank[b]) end)
    local s, mask = 0, {}
    for _, i in ipairs(idx) do
      if s >= cost then break end
      s = s + bv(bank[i]); mask[i] = true
    end
    return { s = s, mask = mask }
  end
  for m = 1, (2 ^ n) - 1 do
    local s, k, mask = 0, 0, {}
    for i = 1, n do
      if math.floor(m / 2 ^ (i - 1)) % 2 == 1 then s = s + bv(bank[i]); k = k + 1; mask[i] = true end
    end
    if s >= cost and (not best or s < best.s or (s == best.s and k > best.k)) then best = { s = s, k = k, mask = mask } end
  end
  return best
end
E.payCombo = payCombo

local function pay(G, bank, cost)
  local b = payCombo(bank, cost)
  local out = {}
  if not b then return out end
  for i = #bank, 1, -1 do
    if b.mask[i] then out[#out + 1] = table.remove(bank, i) end
  end
  pushAll(G.discard, out)
  return out
end

local function log(G, s)
  G.log[#G.log + 1] = s
  if #G.log > 40 then table.remove(G.log, 1) end
  if G.hooks.log then G.hooks.log(s) end
end
E.log = log

function E.aliveCount(G)
  local n = 0
  for _, P in ipairs(G.players) do if P.alive then n = n + 1 end end
  return n
end

-- newGame(n, hooks, opts): opts.rnd = función random(a, b) (por defecto love.math.random / math.random)
function E.newGame(n, hooks, opts)
  opts = opts or {}
  local rnd = opts.rnd or ((love and love.math) and love.math.random or math.random)
  local decks = E.DECKS_PER[n] or 1
  local id = 0
  local function mk(s, r) id = id + 1; return Deck.makeCard(s, r, id) end
  local hearts = {}
  for _ = 1, decks do for r = 2, 14 do hearts[#hearts + 1] = mk("H", r) end end
  Deck.shuffle(hearts, rnd)
  local deck = {}
  for _ = 1, decks do
    for _, s in ipairs({ "R", "T", "M" }) do for r = 2, 14 do deck[#deck + 1] = mk(s, r) end end
    deck[#deck + 1] = mk("JN", 0); deck[#deck + 1] = mk("JR", 0)
  end
  local nl = E.LIVES_PER[n] or 3
  local players = {}
  for p = 1, n do
    players[p] = { idx = p, name = (opts.names and opts.names[p]) or ("Jugador " .. p),
                   hand = {}, lives = {}, luck = {}, money = {}, alive = true, turns = 0, startLives = nl, tgt = nil }
  end
  for _, P in ipairs(players) do
    for _ = 1, nl do P.lives[#P.lives + 1] = { card = table.remove(hearts), up = false, dmg = 0, att = {} } end
  end
  pushAll(deck, hearts)
  Deck.shuffle(deck, rnd)
  for _, P in ipairs(players) do for _ = 1, 5 do P.hand[#P.hand + 1] = table.remove(deck) end end

  local allCards = {}
  for _, c in ipairs(deck) do allCards[#allCards + 1] = c end
  for _, P in ipairs(players) do
    for _, c in ipairs(P.hand) do allCards[#allCards + 1] = c end
    for _, L in ipairs(P.lives) do allCards[#allCards + 1] = L.card end
  end
  local G = {
    n = n, players = players, deck = deck, discard = {}, cem = {}, limbo = {}, duel = nil,
    first = rnd(1, n), cur = 1, moves = 0, reshuffles = 0, sudden = false, streak = 0,
    over = false, winner = -1, byClock = false, pendingMult = nil, defended = {},
    log = {}, ncards = id, allCards = allCards,
    stats = { kills = 0, turns = 0, ward = 0, shield = 0, trap = 0, disarm = 0, hide = 0, swap = 0, peek = 0, split = 0, buy = 0 },
    hooks = hooks or { wait = NOOP, decide = NOOP, fx = {} }, rnd = rnd,
    v3 = (opts.v3 ~= false),   -- reglas v3 por defecto; opts.v3 = false juega con el manual v2
  }
  G.hooks.fx = G.hooks.fx or {}
  G.cur = G.first
  return G
end

function E.endByClock(G, why)
  if G.over then return end
  local best, key = -1, nil
  for p, P in ipairs(G.players) do
    if P.alive then
      local s = 0
      for _, L in ipairs(P.lives) do s = s + rem(L) end
      local k = { #P.lives, s }
      if not key or k[1] > key[1] or (k[1] == key[1] and k[2] > key[2]) then key = k; best = p end
    end
  end
  G.over = true; G.winner = best; G.byClock = true; G.clockWhy = why
  log(G, "FIN POR RELOJ: " .. why)
  fx(G, "banner", "¡SE ACABÓ EL TIEMPO!", -1, 1.3)
end

function E.ensureDeck(G)
  if #G.deck > 0 then return true end
  if #G.discard == 0 then E.endByClock(G, "NO QUEDAN CARTAS"); return false end
  if G.reshuffles >= 6 then E.endByClock(G, "7º REBARAJE"); return false end
  G.reshuffles = G.reshuffles + 1
  G.deck = Deck.shuffle(G.discard, G.rnd); G.discard = {}
  log(G, "REBARAJE " .. G.reshuffles .. "/7"); fx(G, "fxShuffle"); wait(G, 0.75)
  if G.reshuffles >= 4 and not G.sudden then
    G.sudden = true; log(G, "☠ MUERTE SÚBITA: SIN DEFENSA"); fx(G, "banner", "MUERTE SÚBITA", -1, 1.4)
  end
  return true
end

function E.drawCards(G, p, k)
  for _ = 1, k do
    if G.over or not E.ensureDeck(G) then return end
    local c = table.remove(G.deck)
    local P = G.players[p]
    P.hand[#P.hand + 1] = c
    fx(G, "fxDraw", c, p); wait(G, 0.15)
  end
end

local function flipFromDeck(G)
  if not E.ensureDeck(G) then return nil end
  return table.remove(G.deck)
end

function E.killLife(G, tp, L, killer, steal)
  local D = G.players[tp]
  if not rm(D.lives, L) then return end
  fx(G, "fxKill", L, steal); G.stats.kills = G.stats.kills + 1
  pushAll(G.discard, L.att); L.att = {}; L.dmg = 0; L.up = true; L.known = false
  if L.ward then G.discard[#G.discard + 1] = L.ward.card; L.ward = nil end   -- la carta de debajo va al descarte
  local K = G.players[killer]
  if steal then
    K.hand[#K.hand + 1] = L.card; log(G, "✦ " .. K.name .. " ROBA LA VIDA " .. L.card.r .. " DE " .. D.name)
  else
    G.cem[#G.cem + 1] = L.card; log(G, "☠ VIDA " .. L.card.r .. " DE " .. D.name)
  end
  wait(G, 0.56)
  if #D.lives == 0 then
    D.alive = false
    pushAll(K.luck, D.luck); pushAll(K.money, D.money); D.luck = {}; D.money = {}
    pushAll(G.discard, D.hand); D.hand = {}
    log(G, "☠ " .. D.name .. " ELIMINADO · BOTÍN PARA " .. K.name); fx(G, "fxElim", tp)
    fx(G, "banner", D.name .. " ELIMINADO", tp, 1.2)
    if E.aliveCount(G) == 1 then
      G.over = true
      for p, P in ipairs(G.players) do if P.alive then G.winner = p end end
    end
  else
    E.drawCards(G, tp, 1)   -- adrenalina
  end
end

function E.critDuel(G, p, dp, tier)
  G.duel = { a = {}, d = {}, p = p, dp = dp, res = nil, best = nil, tier = tier }
  fx(G, "sfx", "duel"); wait(G, 0.45)
  local function reveal(c, side, suspense)
    c._shown = false; G.duel[side][#G.duel[side] + 1] = c
    fx(G, "fxSuspense", c, suspense); wait(G, suspense)
    c._shown = true; fx(G, "fxReveal", c); wait(G, 0.33)
  end
  for i = 0, tier - 1 do
    local c = flipFromDeck(G)
    if c then reveal(c, "a", 0.42 + i * 0.06) end
  end
  local best = 0
  for _, c in ipairs(G.duel.a) do if dv(c) > best then best = dv(c) end end
  for _, c in ipairs(G.duel.a) do if dv(c) == best then G.duel.best = c; break end end
  local dc = flipFromDeck(G)
  if dc then reveal(dc, "d", 0.8) end
  local def = (#G.duel.d > 0) and dv(G.duel.d[1]) or 0
  local ok = #G.duel.a > 0 and best >= def
  local mult = ok and ((tier == 3) and 3 or 2) or 1
  G.duel.res = ok and ("X" .. mult) or "FALLO"
  log(G, ok and ("✦ ¡CRÍTICO X" .. mult .. "!") or "FALLA EL CRÍTICO"); fx(G, "fxCrit", ok)
  wait(G, 1.25)
  for _, c in ipairs(G.duel.a) do c._shown = nil end
  for _, c in ipairs(G.duel.d) do c._shown = nil end
  pushAll(G.discard, G.duel.a); pushAll(G.discard, G.duel.d); G.duel = nil
  return mult
end

local function stealTop2(from, to)
  table.sort(from, function(a, b) return bv(a) < bv(b) end)
  local k = 0
  while #from > 0 and k < 2 do to[#to + 1] = table.remove(from); k = k + 1 end
  return k
end

-- Trampa (v3): el rayo boca abajo bajo la vida atacada salta contra la vida revelada del atacante con menos
-- aguante (o su primera vida oculta, que se revela). El atacante puede bloquearlo con un trébol de su mano
-- (cuenta como su bloqueo del turno). Si mata, la vida va al cementerio; si no, el daño y el rayo se quedan
-- bajo esa vida. Después el ataque original sigue su curso.
function E.springTrap(G, card, L, owner, attacker)
  local A, D = G.players[attacker], G.players[owner]
  local tv = card.r
  local tgt = nil
  for _, x in ipairs(A.lives) do if x.up and (not tgt or rem(x) < rem(tgt)) then tgt = x end end
  tgt = tgt or A.lives[1]
  if not tgt then G.discard[#G.discard + 1] = card; return end
  card._life = tgt; card._tp = attacker; card._slot = 0; card._n = 1; G.limbo[#G.limbo + 1] = card
  log(G, D.name .. " ◎ TRAMPA: RAYO " .. cname(card) .. " CONTRA " .. A.name)
  fx(G, "fxWard", L, "trap", tv, card, attacker); wait(G, 0.52); fx(G, "fxAim", tgt); wait(G, 0.38)
  if not tgt.up then tgt.up = true; fx(G, "fxReveal", tgt.card); wait(G, 0.42) end
  local cv, cb = tv, nil
  local hasClub = false
  for _, c in ipairs(A.hand) do if c.s == "T" then hasClub = true; break end end
  if not G.sudden and not G.defended[attacker] and hasClub then
    fx(G, "hitIncoming", tgt, cv)
    local club = G.hooks.decide(attacker, "defend", { val = cv, life = tgt, from = owner, cards = { card }, mult = 1, trap = true })
    if club and has(A.hand, club) and club.s == "T" then
      rm(A.hand, club); G.defended[attacker] = true; cb = club
      club._life = tgt; club._tp = attacker; club._slot = 0; club._n = 1; G.limbo[#G.limbo + 1] = club
      cv = math.max(0, cv - bv(club))
    end
  end
  fx(G, "hitStart", tgt, false); fx(G, "fxStrike", card, tgt, tv, 0, cv > 0); wait(G, 0.3)
  if cb then log(G, A.name .. " ♣ BLOQUEA " .. bv(cb)); fx(G, "fxShield", tgt, bv(cb), cv); wait(G, 0.62); rm(G.limbo, cb) end
  rm(G.limbo, card); card._life = nil
  if cv >= rem(tgt) then
    if cb then G.discard[#G.discard + 1] = cb end
    G.discard[#G.discard + 1] = card
    E.killLife(G, attacker, tgt, owner, false)
  else
    tgt.dmg = tgt.dmg + cv
    if cb then tgt.att[#tgt.att + 1] = cb end
    tgt.att[#tgt.att + 1] = card   -- el rayo-trampa se queda bajo la vida del atacante como daño acumulado
    fx(G, "fxDamage", tgt, cv); wait(G, 0.38)
  end
end

-- Ataque: una o varias cartas de rayo contra una vida (combinado), o una K repartida entre dos.
-- targets = { { p = idx, life = L, amount = (solo K repartida) } ... }
function E.doAttack(G, p, cards, targets)
  local P = G.players[p]
  local n = #cards
  for i, c in ipairs(cards) do
    rm(P.hand, c); G.limbo[#G.limbo + 1] = c
    c._life = targets[1].life; c._tp = targets[1].p; c._slot = i - 1; c._n = n
  end
  G.moves = G.moves - n; fx(G, "sfx", "play")
  local mult = 1
  if G.pendingMult then
    local pm = G.pendingMult; G.pendingMult = nil
    if pm.kind == "money" then mult = 2 else mult = E.critDuel(G, p, targets[1].p, pm.tier) end
    if G.over then
      for _, c in ipairs(cards) do rm(G.limbo, c); G.discard[#G.discard + 1] = c end
      return
    end
  end
  local sum, hi = 0, 0
  for _, c in ipairs(cards) do sum = sum + c.r; if c.r > hi then hi = c.r end end
  local whole = G.v3 and mult == 3                                -- v3: el x3 de la suerte va a todo el combo
  local totalVal = whole and sum * 3 or (sum + hi * (mult - 1))  -- si no, el multiplicador se aplica a la carta más alta
  if #targets == 1 then targets[1].amount = totalVal
  else  -- reparto declarado sobre la suma de los rayos, escalado con el multiplicador
    G.stats.split = G.stats.split + 1
    local a0 = math.max(1, math.min(totalVal - 1, math.floor(targets[1].amount * totalVal / sum + 0.5)))
    targets[1].amount = a0; targets[2].amount = totalVal - a0
  end
  local hiDone, contrib = false, {}
  for i, c in ipairs(cards) do
    if whole then contrib[i] = c.r * 3
    elseif c.r == hi and not hiDone then hiDone = true; contrib[i] = c.r * mult else contrib[i] = c.r end
  end
  local hasQ, hasJ = false, false
  for _, c in ipairs(cards) do if c.r == 12 then hasQ = true elseif c.r == 11 then hasJ = true end end
  local names = {}
  for i, c in ipairs(cards) do names[i] = cname(c) end
  local desc = table.concat(names, "+") .. (mult > 1 and (" X" .. mult) or "")
  log(G, P.name .. " ⚡ " .. desc)
  local attachedTo = nil
  for _, t in ipairs(targets) do
    if G.over then break end
    local L, D = t.life, G.players[t.p]
    if has(D.lives, L) then
      for _, c in ipairs(cards) do c._life = L; c._tp = t.p end
      fx(G, "fxAim", L); wait(G, 0.38)
      if not L.up then L.up = true; fx(G, "fxReveal", L.card); wait(G, 0.42) end
      local val, blocked = t.amount, nil
      if G.v3 and L.ward then   -- bajo la vida: trébol = escudo, rayo = trampa; se revela al golpear
        local w = L.ward; L.ward = nil
        local kind = (w.card.s == "R") and "trap" or "shield"
        local key = hasQ and "disarm" or kind
        G.stats[key] = (G.stats[key] or 0) + 1
        if hasQ then   -- la Q desarma: escudo o trampa al descarte sin efecto
          G.discard[#G.discard + 1] = w.card
          log(G, D.name .. ": " .. (kind == "trap" and "TRAMPA" or "ESCUDO") .. " DESARMADA POR LA Q")
          fx(G, "fxWard", L, "disarm", bv(w.card), w.card); wait(G, 0.6)
        elseif kind == "shield" then
          G.discard[#G.discard + 1] = w.card
          val = math.max(0, val - bv(w.card))
          log(G, D.name .. " ⛨ ESCUDO " .. bv(w.card)); fx(G, "fxWard", L, "shield", bv(w.card), w.card); wait(G, 0.65)
        else   -- trampa: el rayo salta contra el atacante; después sigue el ataque original
          E.springTrap(G, w.card, L, t.p, p)
          if G.over then break end
        end
      end
      local raw = val
      local hasClub = false
      for _, c in ipairs(D.hand) do if c.s == "T" then hasClub = true; break end end
      if not G.sudden and not G.defended[t.p] and val > 0 and hasClub then
        fx(G, "hitIncoming", L, val)
        local club = G.hooks.decide(t.p, "defend", { val = val, life = L, from = p, cards = cards, mult = mult })
        if club then
          rm(D.hand, club); G.defended[t.p] = true; blocked = club
          club._life = L; club._tp = t.p; club._slot = 0; club._n = 1; G.limbo[#G.limbo + 1] = club
          val = math.max(0, val - bv(club))
        end
      end
      fx(G, "hitStart", L, mult > 1)
      for i = 1, n do
        fx(G, "fxStrike", cards[i], L, (#targets > 1) and raw or contrib[i], i - 1, raw > 0)
        wait(G, (n > 1) and 0.19 or 0.26)
      end
      if blocked then
        log(G, D.name .. " ♣ BLOQUEA " .. bv(blocked)); fx(G, "fxShield", L, bv(blocked), val); wait(G, 0.62); rm(G.limbo, blocked)
      end
      if val >= rem(L) then
        if blocked then G.discard[#G.discard + 1] = blocked end
        local steal = false
        for _, c in ipairs(cards) do if c.r == 14 then steal = true end end
        E.killLife(G, t.p, L, p, steal)
        if hasJ and not G.v3 then   -- v2: la J roba 2 tréboles al destruir (en v3 revela, ver abajo)
          local k = stealTop2(D.luck, P.luck)
          if k > 0 then log(G, P.name .. " ROBA " .. k .. " ♣ A " .. D.name); fx(G, "fxSteal", p, "T", k); wait(G, 0.3) end
        end
        if hasQ then   -- v3: roba 2 del banco más rico (dinero o suerte); v2: siempre dinero
          local suit = (G.v3 and total(D.money) < total(D.luck)) and "T" or "M"
          local k = stealTop2(suit == "M" and D.money or D.luck, suit == "M" and P.money or P.luck)
          if k > 0 then log(G, P.name .. " ROBA " .. k .. (suit == "M" and " ● A " or " ♣ A ") .. D.name); fx(G, "fxSteal", p, suit, k); wait(G, 0.3) end
        end
      else
        L.dmg = L.dmg + val
        if blocked then L.att[#L.att + 1] = blocked end
        if not attachedTo then attachedTo = L end
        fx(G, "fxDamage", L, val); wait(G, 0.38)
      end
    end
  end
  local alive = false
  if attachedTo then
    for _, X in ipairs(G.players) do if has(X.lives, attachedTo) then alive = true end end
  end
  for _, c in ipairs(cards) do
    rm(G.limbo, c); c._life = nil
    if alive then attachedTo.att[#attachedTo.att + 1] = c else G.discard[#G.discard + 1] = c end
  end
  -- v3: la J revela (para todos) una vida oculta de cada rival golpeado, a elección del atacante
  -- (con una K repartida entre dos rivales, una de cada uno)
  if G.v3 and not G.over and hasJ then
    local done = {}
    for _, t in ipairs(targets) do
      local tp = t.p
      if not done[tp] then
        done[tp] = true
        local D = G.players[tp]
        local any = false
        for _, L in ipairs(D.lives) do if not L.up then any = true end end
        if D.alive and any then
          local L2 = G.hooks.decide(p, "peek", { tp = tp })
          if L2 and has(D.lives, L2) and not L2.up then
            L2.up = true; L2.known = false; G.stats.peek = G.stats.peek + 1
            log(G, P.name .. " ✦ J REVELA LA VIDA " .. L2.card.r .. " DE " .. D.name)
            fx(G, "fxReveal", L2.card); fx(G, "fxPeek", L2, p); wait(G, 0.7)
          end
        end
      end
    end
  end
end

function E.perform(G, p, a)
  local P = G.players[p]
  if a.type ~= "bank" then G.streak = 0 end
  if a.type == "place" then
    rm(P.hand, a.card); P.lives[#P.lives + 1] = { card = a.card, up = false, dmg = 0, att = {} }
    G.moves = G.moves - 1; log(G, P.name .. " ♥ NUEVA VIDA"); fx(G, "fxPlace", a.card); wait(G, 0.4); return true
  elseif a.type == "bank" then
    rm(P.hand, a.card)
    local bank = (a.card.s == "T") and P.luck or P.money
    bank[#bank + 1] = a.card; G.moves = G.moves - 1
    local ic = (a.card.s == "T") and "♣" or "●"
    log(G, P.name .. " " .. ic .. " +" .. bv(a.card)); fx(G, "fxBank", a.card, G.streak); G.streak = G.streak + 1; wait(G, 0.36); return true
  elseif a.type == "luck" then
    fx(G, "fxPay", pay(G, P.luck, a.tier * 10)); G.pendingMult = { kind = "luck", tier = a.tier }; G.moves = G.moves - 1
    log(G, P.name .. " ♣ -" .. a.tier * 10 .. " ► CRÍTICO"); wait(G, 0.48); return true
  elseif a.type == "money" then
    fx(G, "fxPay", pay(G, P.money, (a.tier == 4 and 1 or a.tier) * 10)); G.moves = G.moves - 1   -- ocultar (4) cuesta 10
    if a.tier == 1 then
      G.stats.buy = G.stats.buy + 1
      log(G, P.name .. " ● -10 ► ROBA 2" .. (G.v3 and ", DESCARTA 1" or "")); wait(G, 0.32); E.drawCards(G, p, 2)
      if G.v3 and #P.hand > 0 and not G.over then   -- v3: el jugador elige qué carta descarta
        local c = G.hooks.decide(p, "discard", { why = "pay" })
        if c and has(P.hand, c) then rm(P.hand, c); G.discard[#G.discard + 1] = c; fx(G, "sfx", "draw"); wait(G, 0.2) end
      end
    elseif a.tier == 4 then   -- v3: ocultar una vida revelada (el daño se conserva en secreto)
      local L = a.life
      if L and has(P.lives, L) and L.up then
        L.up = false; L.known = true
        pushAll(G.discard, L.att); L.att = {}; G.stats.hide = G.stats.hide + 1
        log(G, P.name .. " ● -10 ► OCULTA UNA VIDA"); fx(G, "fxHide", L); wait(G, 0.6)
      end
    elseif a.tier == 2 then
      G.pendingMult = { kind = "money" }; log(G, P.name .. " ● -20 ► RAYO X2"); wait(G, 0.48)
    else
      rm(G.cem, a.pick); P.lives[#P.lives + 1] = { card = a.pick, up = false, dmg = 0, att = {} }
      log(G, P.name .. " ● -30 ► REVIVE " .. a.pick.r); fx(G, "fxRevive", a.pick); wait(G, 0.7)
    end
    return true
  elseif a.type == "jokerRed" then
    rm(P.hand, a.card); G.discard[#G.discard + 1] = a.card; G.moves = G.moves - 1
    if a.pick then
      rm(G.cem, a.pick); P.lives[#P.lives + 1] = { card = a.pick, up = false, dmg = 0, att = {} }
      log(G, P.name .. " ✦ REVIVE " .. a.pick.r); fx(G, "fxRevive", a.pick); wait(G, 0.7)
    else
      log(G, P.name .. " ✦ ROBA 2"); wait(G, 0.25); E.drawCards(G, p, 2)
    end
    return true
  elseif a.type == "jokerBlack" then
    rm(P.hand, a.card); G.limbo[#G.limbo + 1] = a.card
    a.card._life = a.t1.life; a.card._tp = a.t1.p; a.card._slot = 0; a.card._n = 1
    G.moves = G.moves - 1; fx(G, "sfx", "play")
    log(G, P.name .. " ✦ COMODÍN NEGRO"); wait(G, 0.48)
    local ts = { a.t1 }
    if a.t2 and a.k then rm(P.hand, a.k); G.discard[#G.discard + 1] = a.k; G.moves = G.moves - 1; ts[2] = a.t2 end
    for _, t in ipairs(ts) do
      if G.over then break end
      if has(G.players[t.p].lives, t.life) then
        a.card._life = t.life; a.card._tp = t.p; fx(G, "fxAim", t.life); wait(G, 0.38)
        if not t.life.up then t.life.up = true; fx(G, "fxReveal", t.life.card); wait(G, 0.34) end
        fx(G, "hitStart", t.life, false); fx(G, "fxStrike", a.card, t.life, 0, 0, true, true); wait(G, 0.3)
        E.killLife(G, t.p, t.life, p, false)
      end
    end
    rm(G.limbo, a.card); a.card._life = nil; G.discard[#G.discard + 1] = a.card
    return true
  elseif a.type == "attack" then
    E.doAttack(G, p, a.cards or { a.card }, a.targets); return true
  elseif a.type == "ward" then   -- v3: carta boca abajo bajo una vida propia: trébol = escudo, rayo = trampa (lo decide el palo)
    local L = a.life
    if not G.v3 or not L or not has(P.lives, L) or L.ward or not a.card or (a.card.s ~= "T" and a.card.s ~= "R") or not has(P.hand, a.card) then return false end
    rm(P.hand, a.card); L.ward = { card = a.card, kind = (a.card.s == "R") and "trap" or "shield" }
    G.moves = G.moves - 1; G.stats.ward = G.stats.ward + 1
    log(G, P.name .. (a.card.s == "R" and " ⚡" or " ♣") .. " BAJO UNA VIDA"); fx(G, "fxWardPlace", L); wait(G, 0.42); return true
  elseif a.type == "swap" then   -- v3: intercambia dos vidas ocultas propias (con lo que tengan debajo)
    if not G.v3 then return false end
    local i, j = nil, nil
    for k, L in ipairs(P.lives) do if L == a.a then i = k elseif L == a.b then j = k end end
    if not i or not j or i == j or a.a.up or a.b.up then return false end
    P.lives[i], P.lives[j] = P.lives[j], P.lives[i]
    a.a.known, a.b.known = false, false   -- el rival pierde la pista
    G.moves = G.moves - 1; G.stats.swap = G.stats.swap + 1
    log(G, P.name .. " REORDENA SUS VIDAS"); fx(G, "fxSwap", a.a, a.b); wait(G, 0.7); return true
  end
  return false
end

function E.canAttack(G, p)
  if G.players[p].turns == 0 then return false end
  for i, X in ipairs(G.players) do
    if i ~= p and X.alive and #X.lives > 0 then return true end
  end
  return false
end

function E.playTurn(G, p)
  local P = G.players[p]
  G.moves = 0; G.pendingMult = nil; G.defended = {}; G.stats.turns = G.stats.turns + 1; G.streak = 0
  fx(G, "fxTurn", p)
  E.drawCards(G, p, 2)
  if G.over then return end
  G.moves = (P.turns == 0 and p == G.first) and 1 or 3
  local guard = 0
  while G.moves > 0 and not G.over and P.alive and guard < 12 do
    guard = guard + 1
    local a = G.hooks.decide(p, "turn")
    if not a or a.type == "end" then break end
    if not E.perform(G, p, a) then break end
  end
  if G.pendingMult then log(G, "SE PIERDE EL MULTIPLICADOR"); G.pendingMult = nil end
  G.moves = 0
  while P.alive and not G.over and #P.hand > 7 do
    local c = G.hooks.decide(p, "discard")
    if not c or not has(P.hand, c) then break end
    rm(P.hand, c); G.discard[#G.discard + 1] = c; fx(G, "sfx", "draw"); wait(G, 0.16)
  end
  P.turns = P.turns + 1
end

function E.nextPlayer(G)
  repeat G.cur = G.cur % G.n + 1 until G.players[G.cur].alive
end

function E.countCards(G)
  local n = #G.deck + #G.discard + #G.cem + #G.limbo + (G.duel and (#G.duel.a + #G.duel.d) or 0)
  for _, P in ipairs(G.players) do
    n = n + #P.hand + #P.luck + #P.money
    for _, L in ipairs(P.lives) do n = n + 1 + #L.att + (L.ward and 1 or 0) end   -- incluida la carta bajo la vida
  end
  return n
end

function E.round(G)
  local m = math.huge
  for _, P in ipairs(G.players) do if P.alive and P.turns < m then m = P.turns end end
  return (m == math.huge and 0 or m) + 1
end

return E
