-- Sistema de partículas simple con presets para los efectos del juego.
local P = { list = {} }

local function rnd(a, b)
  if love and love.math then return love.math.random() * (b - a) + a end
  return math.random() * (b - a) + a
end

local function add(x, y, cfg)
  local a   = rnd(cfg.amin or 0, cfg.amax or math.pi * 2)
  local spd = rnd(cfg.smin or 50, cfg.smax or 200)
  local life = rnd(cfg.lmin or 0.4, cfg.lmax or 0.9)
  local color = cfg.color or { 1, 1, 1 }
  if cfg.colors then color = cfg.colors[math.floor(rnd(1, #cfg.colors + 0.999))] end
  P.list[#P.list + 1] = {
    x = x, y = y,
    vx = math.cos(a) * spd,
    vy = math.sin(a) * spd - (cfg.lift or 0),
    life = life, maxlife = life,
    size = rnd(cfg.szmin or 2, cfg.szmax or 6),
    grav = cfg.grav or 300, drag = cfg.drag or 0.92,
    color = color, kind = cfg.kind or "circle",
    rot = rnd(0, math.pi * 2), spin = rnd(-8, 8),
  }
end

function P.burst(x, y, n, cfg)
  cfg = cfg or {}
  for _ = 1, n do add(x, y, cfg) end
end

function P.update(dt)
  for i = #P.list, 1, -1 do
    local p = P.list[i]
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(P.list, i)
    else
      p.vy = p.vy + p.grav * dt
      p.vx, p.vy = p.vx * p.drag, p.vy * p.drag
      p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
      p.rot = p.rot + p.spin * dt
    end
  end
end

function P.draw()
  for _, p in ipairs(P.list) do
    local a = p.life / p.maxlife
    local c = p.color
    love.graphics.setColor(c[1], c[2], c[3], a)
    if p.kind == "rect" then
      love.graphics.push()
      love.graphics.translate(p.x, p.y); love.graphics.rotate(p.rot)
      love.graphics.rectangle("fill", -p.size / 2, -p.size / 2, p.size, p.size)
      love.graphics.pop()
    elseif p.kind == "star" then
      local s = p.size * (0.6 + a * 0.6)
      love.graphics.push()
      love.graphics.translate(p.x, p.y); love.graphics.rotate(p.rot)
      love.graphics.polygon("fill", 0, -s, s * 0.4, 0, 0, s, -s * 0.4, 0)
      love.graphics.pop()
    else
      love.graphics.circle("fill", p.x, p.y, p.size * a + 0.5)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function P.clear() P.list = {} end

-- Presets
function P.hit(x, y)     P.burst(x, y, 18, { colors = {{1,0.85,0.3},{1,0.6,0.1},{1,1,0.7}}, smin=120, smax=320, lmin=0.3, lmax=0.6, szmin=2, szmax=5, grav=400 }) end
function P.destroy(x, y) P.burst(x, y, 42, { colors = {{1,0.3,0.3},{1,0.6,0.2},{0.7,0.1,0.1},{0.35,0.35,0.35}}, smin=80, smax=440, lmin=0.5, lmax=1.1, szmin=3, szmax=9, grav=520 }) end
function P.coins(x, y)   P.burst(x, y, 22, { colors = {{1,0.85,0.2},{1,0.7,0.1},{1,0.95,0.6}}, smin=80, smax=260, lift=120, lmin=0.5, lmax=1.0, szmin=3, szmax=7, kind="rect", grav=600 }) end
function P.luck(x, y)    P.burst(x, y, 22, { colors = {{0.4,1,0.5},{0.2,0.9,0.7},{0.8,1,0.85}}, smin=60, smax=220, lift=80, lmin=0.5, lmax=1.1, szmin=3, szmax=7, kind="star", grav=180 }) end
function P.heal(x, y)    P.burst(x, y, 16, { colors = {{1,0.4,0.6},{1,0.6,0.8},{1,0.8,0.9}}, smin=20, smax=90, lift=160, lmin=0.8, lmax=1.4, szmin=4, szmax=8, kind="star", grav=-40, drag=0.96 }) end
function P.deal(x, y)    P.burst(x, y, 8,  { colors = {{1,1,1},{0.8,0.85,1}}, smin=30, smax=120, lmin=0.2, lmax=0.4, szmin=2, szmax=4, grav=200 }) end
function P.crit(x, y)    P.burst(x, y, 70, { colors = {{1,0.9,0.2},{1,0.4,0.2},{0.5,0.8,1},{1,1,1}}, smin=120, smax=560, lmin=0.6, lmax=1.4, szmin=3, szmax=10, kind="star", grav=280 }) end

return P
