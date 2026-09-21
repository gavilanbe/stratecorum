function love.conf(t)
  t.version = "11.5"
  t.console = false
  -- `love . --selftest N`: autoprueba del motor sin ventana ni sonido
  local selftest = false
  for _, a in ipairs(arg or {}) do if a == "--selftest" then selftest = true end end
  if selftest then
    t.window = nil
    t.modules.audio = false
    t.modules.graphics = false
    t.modules.window = false
    t.modules.joystick = false
    t.modules.sound = false
    t.modules.touch = false
    t.modules.video = false
    t.modules.font = false
    t.modules.image = false
    return
  end
  t.window.title  = "Stratecorum"
  t.window.width  = 1280
  t.window.height = 800
  t.window.resizable = true
  t.window.minwidth  = 1024
  t.window.minheight = 640
  t.window.msaa = 4
  t.window.vsync = 1
end
