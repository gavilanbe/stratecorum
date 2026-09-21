-- Autoprueba del motor sin gráficos: `love . --selftest 200` (o `luajit src/selftest.lua 200` desde love/).
-- Juega N partidas de bots (mitad con reglas v2, mitad con v3) repartidas entre 2, 3 y 4 jugadores,
-- comprueba que siempre hay 54 cartas (108 con dos barajas) entre mazo, descarte, cementerio, manos,
-- bancos y vidas (incluido el trébol bajo la vida), que toda partida termina, e imprime un resumen JSON
-- con un bloque por reglas ("v2" y "v3").
local E  = require("src.engine")
local AI = require("src.ai")

local ST = {}

local function jsonEnc(v, ind)
  ind = ind or ""
  local t = type(v)
  if t == "table" then
    local isArr = (#v > 0) or (next(v) == nil)
    local parts = {}
    if isArr then
      for _, x in ipairs(v) do parts[#parts + 1] = jsonEnc(x, ind .. " ") end
      if #parts == 0 then return "[]" end
      return "[" .. table.concat(parts, ", ") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local val = v[k]; if val == nil then val = v[tonumber(k)] end
      parts[#parts + 1] = ind .. " " .. string.format("%q", k) .. ": " .. jsonEnc(val, ind .. " ")
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. ind .. "}"
  elseif t == "string" then return string.format("%q", v)
  elseif t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "null" end
    if v == math.floor(v) then return string.format("%d", v) end
    return string.format("%.3f", v)
  elseif t == "boolean" then return tostring(v)
  end
  return "null"
end
ST.json = jsonEnc

local V3STATS = { "ward", "shield", "trap", "disarm", "hide", "swap", "peek", "split", "buy" }

local function playGame(n, seed, v3)
  local rng
  if love and love.math then
    local r = love.math.newRandomGenerator(seed)
    rng = function(a, b) return r:random(a, b) end
  else
    math.randomseed(seed); rng = math.random
  end
  local hooks = { wait = function() end, fx = {} }
  local G = E.newGame(n, hooks, { rnd = rng, v3 = v3 })
  hooks.decide = function(p, kind, ctx) return AI.decide(G, p, kind, ctx) end
  local expected = G.ncards
  local guard = 0
  local badCount = 0
  while not G.over and guard < 4000 do
    guard = guard + 1
    E.playTurn(G, G.cur)
    if E.countCards(G) ~= expected then badCount = badCount + 1 end
    if G.over then break end
    E.nextPlayer(G)
  end
  local rounds = 0
  for _, P in ipairs(G.players) do if P.turns > rounds then rounds = P.turns end end
  return { over = G.over, winner = G.winner, byClock = G.byClock, rounds = rounds, badCount = badCount,
           expected = expected, kills = G.stats.kills, reshuffles = G.reshuffles, stats = G.stats }
end

-- Un lote de N partidas con unas reglas (v3 = true/false). Devuelve el bloque de informe de ese lote.
local function runSet(N, v3, sizes, seed0)
  local out = { rules = v3 and "v3" or "v2", games = N, expectedCards = {}, perPlayers = {}, errors = {}, badCount = 0, unfinished = 0, clock = 0 }
  local stats = {}
  for _, n in ipairs(sizes) do stats[n] = { games = 0, wins = {}, rounds = {}, clock = 0, badCount = 0, kills = 0, v3 = {} } end
  for i = 1, N do
    local n = sizes[((i - 1) % #sizes) + 1]
    local seed = seed0 + i
    local ok, res = pcall(playGame, n, seed, v3)
    local s = stats[n]
    s.games = s.games + 1
    if not ok then
      out.errors[#out.errors + 1] = "partida " .. i .. " (" .. n .. "j, semilla " .. seed .. "): " .. tostring(res)
    else
      out.expectedCards[tostring(n)] = res.expected
      if not res.over then out.unfinished = out.unfinished + 1; out.errors[#out.errors + 1] = "sin final, semilla " .. seed end
      if res.badCount > 0 then out.badCount = out.badCount + res.badCount; s.badCount = s.badCount + res.badCount end
      local w = tostring(res.winner)
      s.wins[w] = (s.wins[w] or 0) + 1
      s.rounds[#s.rounds + 1] = res.rounds
      s.kills = s.kills + res.kills
      if res.byClock then s.clock = s.clock + 1; out.clock = out.clock + 1 end
      for _, k in ipairs(V3STATS) do s.v3[k] = (s.v3[k] or 0) + (res.stats[k] or 0) end
    end
  end
  for _, n in ipairs(sizes) do
    local s = stats[n]
    table.sort(s.rounds)
    local r = s.rounds
    local block = {
      games = s.games, wins = s.wins, clock = s.clock, badCount = s.badCount,
      medianRounds = r[math.floor(#r / 2) + 1] or 0, p90Rounds = r[math.max(1, math.floor(#r * 0.9))] or 0,
      avgKills = s.games > 0 and (s.kills / s.games) or 0,
    }
    if v3 and s.games > 0 then   -- uso medio por partida de las jugadas de v3
      block.avgV3 = {}
      for _, k in ipairs(V3STATS) do block.avgV3[k] = s.v3[k] / s.games end
    end
    out.perPlayers[tostring(n)] = block
  end
  out.ok = (#out.errors == 0 and out.badCount == 0 and out.unfinished == 0)
  return out
end

-- ST.run(N): mitad de las partidas con reglas v2 y mitad con v3 (opts.rules = 2 o 3 para un solo lote).
function ST.run(N, opts)
  N = tonumber(N) or 200
  opts = opts or {}
  local sizes = opts.sizes or { 2, 3, 4 }
  local t0 = os.clock()
  local out = { games = N, errors = {}, badCount = 0, unfinished = 0, clock = 0 }
  local sets = {}
  if opts.rules == 2 then sets[1] = { "v2", N, false }
  elseif opts.rules == 3 then sets[1] = { "v3", N, true }
  else sets[1] = { "v2", math.ceil(N / 2), false }; sets[2] = { "v3", math.floor(N / 2), true } end
  for _, s in ipairs(sets) do
    local key, cnt, v3 = s[1], s[2], s[3]
    local r = runSet(cnt, v3, sizes, v3 and 5000 or 1000)
    out[key] = r
    for _, e in ipairs(r.errors) do out.errors[#out.errors + 1] = key .. ": " .. e end
    out.badCount = out.badCount + r.badCount
    out.unfinished = out.unfinished + r.unfinished
    out.clock = out.clock + r.clock
  end
  out.seconds = os.clock() - t0
  out.ok = (#out.errors == 0 and out.badCount == 0 and out.unfinished == 0)
  return out
end

-- Ejecución directa con luajit/lua desde la carpeta love/: `luajit src/selftest.lua 200`
if not love and arg and arg[0] and arg[0]:match("selftest%.lua$") then
  package.path = "./?.lua;" .. package.path
  local out = ST.run(tonumber(arg[1]) or 200)
  print(jsonEnc(out))
  os.exit(out.ok and 0 or 1)
end

return ST
