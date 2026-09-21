-- Motor de tweens minimalista (estilo flux) con easings.
local flux = { tweens = {} }

local easing = {
  linear     = function(t) return t end,
  quadin     = function(t) return t*t end,
  quadout    = function(t) return -t*(t-2) end,
  quadinout  = function(t) t=t*2; if t<1 then return 0.5*t*t end; t=t-1; return -0.5*(t*(t-2)-1) end,
  cubicout   = function(t) t=t-1; return t*t*t+1 end,
  expoout    = function(t) if t>=1 then return 1 end; return 1-2^(-10*t) end,
  backin     = function(t) local s=1.70158; return t*t*((s+1)*t-s) end,
  backout    = function(t) local s=1.70158; t=t-1; return t*t*((s+1)*t+s)+1 end,
  elasticout = function(t) if t==0 then return 0 end; if t>=1 then return 1 end; local p=0.35; return 2^(-10*t)*math.sin((t-p/4)*(2*math.pi)/p)+1 end,
  bounceout  = function(t)
    if t<1/2.75 then return 7.5625*t*t
    elseif t<2/2.75 then t=t-1.5/2.75; return 7.5625*t*t+0.75
    elseif t<2.5/2.75 then t=t-2.25/2.75; return 7.5625*t*t+0.9375
    else t=t-2.625/2.75; return 7.5625*t*t+0.984375 end
  end,
}
flux.easing = easing

local Tween = {}
Tween.__index = Tween

function flux.to(obj, time, vars)
  local t = setmetatable({
    obj = obj, time = math.max(time or 0.0001, 0.0001), vars = vars or {},
    elapsed = 0, _ease = easing.quadout, _delay = 0, _inited = false,
    _oncomplete = nil, _onupdate = nil, _onstart = nil, _next = nil, _dead = false,
  }, Tween)
  table.insert(flux.tweens, t)
  return t
end

function Tween:ease(n)       self._ease = easing[n] or self._ease; return self end
function Tween:delay(d)      self._delay = d or 0; return self end
function Tween:oncomplete(f) self._oncomplete = f; return self end
function Tween:onupdate(f)   self._onupdate = f; return self end
function Tween:onstart(f)    self._onstart = f; return self end

function Tween:after(obj, time, vars)
  if type(obj) == "number" then vars = time; time = obj; obj = self.obj end
  local n = flux.to(obj, time, vars)
  for i = #flux.tweens, 1, -1 do
    if flux.tweens[i] == n then table.remove(flux.tweens, i); break end
  end
  self._next = n
  return n
end

function flux.update(dt)
  local list = flux.tweens
  for i = #list, 1, -1 do
    local t = list[i]
    if t._dead then
      table.remove(list, i)
    elseif t._delay > 0 then
      t._delay = t._delay - dt
    else
      if not t._inited then
        t.start, t.diff = {}, {}
        for k, v in pairs(t.vars) do
          t.start[k] = t.obj[k] or 0
          t.diff[k]  = v - (t.obj[k] or 0)
        end
        t._inited = true
        if t._onstart then t._onstart() end
      end
      t.elapsed = t.elapsed + dt
      local p = t.elapsed / t.time
      if p > 1 then p = 1 end
      local e = t._ease(p)
      for k in pairs(t.vars) do t.obj[k] = t.start[k] + t.diff[k] * e end
      if t._onupdate then t._onupdate() end
      if p >= 1 then
        t._dead = true
        if t._oncomplete then t._oncomplete() end
        if t._next then table.insert(list, t._next) end
      end
    end
  end
end

function flux.stop(t)
  while t do t._dead = true; t = t._next end
end

function flux.clear() flux.tweens = {} end

return flux
