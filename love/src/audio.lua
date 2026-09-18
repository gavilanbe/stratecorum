-- Efectos de sonido sintetizados en runtime (sin archivos externos).
local A = { enabled = true, sounds = {}, volume = 0.6 }
local RATE = 44100

local function gen(dur, fn, vol)
  vol = vol or 0.5
  local n = math.max(1, math.floor(RATE * dur))
  local data = love.sound.newSoundData(n, RATE, 16, 1)
  for i = 0, n - 1 do
    local t = i / RATE
    local s = fn(t, i / n) * vol
    if s > 1 then s = 1 elseif s < -1 then s = -1 end
    data:setSample(i, s)
  end
  return love.audio.newSource(data, "static")
end

local function noise() return love.math.random() * 2 - 1 end

function A.load()
  local ok = pcall(function()
    A.sounds.click   = gen(0.05, function(t, p) return math.sin(2*math.pi*820*t) * (1-p) end, 0.3)
    A.sounds.select  = gen(0.09, function(t, p) return math.sin(2*math.pi*(520+420*p)*t) * (1-p) end, 0.3)
    A.sounds.deal    = gen(0.06, function(t, p) return noise()*(1-p)*0.6 + math.sin(2*math.pi*320*t)*(1-p)*0.4 end, 0.35)
    A.sounds.attack  = gen(0.18, function(t, p) return noise() * (1-p) end, 0.4)
    A.sounds.hit     = gen(0.25, function(t, p) return math.sin(2*math.pi*(190-130*p)*t) * (1-p) end, 0.55)
    A.sounds.destroy = gen(0.42, function(t, p) return (math.sin(2*math.pi*(120-80*p)*t)*0.6 + noise()*0.4) * (1-p) end, 0.7)
    A.sounds.coin    = gen(0.18, function(t, p) return (math.sin(2*math.pi*1200*t)+math.sin(2*math.pi*1820*t))*0.5*(1-p) end, 0.3)
    A.sounds.luck    = gen(0.26, function(t, p) return math.sin(2*math.pi*(620+1200*p)*t) * (1-p) end, 0.3)
    A.sounds.life    = gen(0.30, function(t, p) return math.sin(2*math.pi*(440+220*p)*t) * (1-p) end, 0.35)
    A.sounds.crit    = gen(0.50, function(t, p) return (math.sin(2*math.pi*(300+900*p)*t) + noise()*0.3) * (1-p) end, 0.5)
    A.sounds.error   = gen(0.16, function(t, p) return math.sin(2*math.pi*145*t) * (1-p) end, 0.4)
    A.sounds.turn    = gen(0.22, function(t, p) return math.sin(2*math.pi*(300+220*p)*t) * (1-p) end, 0.3)
    A.sounds.win     = gen(0.75, function(t, p) local f = 400*(1+math.floor(p*4)*0.25); return math.sin(2*math.pi*f*t)*(1-p*0.5) end, 0.4)
  end)
  if not ok then A.enabled = false end
end

function A.play(name)
  if not A.enabled then return end
  local s = A.sounds[name]
  if s then pcall(function()
    local c = s:clone()
    c:setVolume(A.volume)
    c:play()
  end) end
end

return A
