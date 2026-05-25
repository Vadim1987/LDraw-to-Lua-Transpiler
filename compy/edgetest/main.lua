-- Edgetest entry point.

TOL = 0.0005

require "linalg"
require "ldraw_colors"
require "ldraw"
require "picking"

local gfx = love.graphics

local D = 1000
local CENTER_X = 512
local CENTER_Y = 300
local VIEW_M = Mat.unit(3)
local VIEW_T = Vec.d3(0, 0, 0)
local SELECTED
local ROOT_COLOR = Yellow

local DAT_FILES = {
  "dat_3001",
  "dat_3001s01",
  "dat_3003",
  "dat_3003s01",
  "dat_3003s02",
  "dat_4_4cyli",
  "dat_4_4disc",
  "dat_4_4edge",
  "dat_4_4ring3",
  "dat_box3u2p",
  "dat_box5",
  "dat_stud",
  "dat_stud4",
  "dat_stug_2x2"
}

-- Load a transpiled chunk into the compy.ldraw env.

local function load_chunk(name)
  local chunk = (loadfile(name .. ".lua"))
  setfenv(chunk, compy.ldraw)
  compy.ldraw[name] = chunk
end

local function load_chunks()
  for _, name in pairs(DAT_FILES) do
    load_chunk(name)
  end
  load_chunk("ldr_pyramid")
end

-- Silenced env: every compy.ldraw function replaced with
-- ignore. Used for one-pass diagnostic chunk inspection.

local function silenced_env()
  local env = { }
  for k, v in pairs(compy.ldraw) do
    env[k] = (type(v) == "function") and ignore or v
  end
  return env
end

-- Run chunk once with all DSL silenced except LDRAW_ORG, which
-- marks the chunk as a Part if its kind is "Part".

local function detect_part(chunk)
  local env = silenced_env()
  function env.LDRAW_ORG(kind)
    if kind == "Part" then
      compy.ldraw.parts[chunk] = true
    end
  end
  setfenv(chunk, env)
  chunk(ROOT_COLOR, Mat.unit(3), Vec.d3(0, 0, 0), nil)
  setfenv(chunk, compy.ldraw)
end

local function detect_parts()
  for _, name in pairs(DAT_FILES) do
    detect_part(compy.ldraw[name])
  end
end

local function setup_view()
  VIEW_M = Mat:new({
    Vec.d3(0.8779, 0.1685, -0.4489),
    Vec.d3(0, 0.9363, 0.3511),
    Vec.d3(0.4789, -0.3082, 0.8221)
  })
  VIEW_T = Vec.d3(0, 70, 850)
end

local function perspective(x, y, z)
  local dz = D / z
  return CENTER_X + x * dz, CENTER_Y + y * dz
end

-- Apply M, T then the global view to a local point and project.

local function screen_point(M, T, x, y, z)
  local p = Vec.d3(x, y, z):tr(M)
  p:acc(T)
  local q = p:tr(VIEW_M)
  q:acc(VIEW_T)
  return perspective(q:c3())
end

local function same_side(ax, ay, bx, by, cx, cy, dx, dy)
  local vx, vy = bx - ax, by - ay
  local s1 = vx * (cy - ay) - vy * (cx - ax)
  local s2 = vx * (dy - ay) - vy * (dx - ax)
  return 0 <= s1 * s2
end

-- Draw pass callbacks. Each renders one primitive type via
-- the perspective-projected screen_point.

local function draw_edge(M, T, x1, y1, z1, x2, y2, z2)
  local sx1, sy1 = screen_point(M, T, x1, y1, z1)
  local sx2, sy2 = screen_point(M, T, x2, y2, z2)
  gfx.line(sx1, sy1, sx2, sy2)
end

local function draw_line(M, T, q, x1, y1, z1, x2, y2, z2)
  draw_edge(M, T, x1, y1, z1, x2, y2, z2)
end

local function draw_outline(M, T,
    x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4)
  local sx1, sy1 = screen_point(M, T, x1, y1, z1)
  local sx2, sy2 = screen_point(M, T, x2, y2, z2)
  local sx3, sy3 = screen_point(M, T, x3, y3, z3)
  local sx4, sy4 = screen_point(M, T, x4, y4, z4)
  if same_side(sx1, sy1, sx2, sy2, sx3, sy3, sx4, sy4) then
    gfx.line(sx1, sy1, sx2, sy2)
  end
end

local function draw_color_outline(M, T, q,
    x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4)
  draw_outline(M, T,
    x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4)
end

-- Draw pass: install the rendering callbacks and run root.

function draw(root)
  compy.ldraw.edge = draw_edge
  compy.ldraw.line = draw_line
  compy.ldraw.outline = draw_outline
  compy.ldraw.color_outline = draw_color_outline
  compy.ldraw.tri = ignore
  compy.ldraw.quad = ignore
  root()
end

local function view_to_ldraw(v)
  return Vec.d3(
    v:dot(VIEW_M[1]),
    v:dot(VIEW_M[2]),
    v:dot(VIEW_M[3])
  )
end

-- Invert the fixed view/projection to cast an LDraw-space ray.

local function mouse_ray(mx, my)
  local origin = view_to_ldraw(
    Vec.d3(-VIEW_T:c(1), -VIEW_T:c(2), -VIEW_T:c(3))
  )
  local dir = view_to_ldraw(
    Vec.d3((mx - CENTER_X) / D, (my - CENTER_Y) / D, 1)
  )
  return {
    origin = origin,
    dir = dir
  }
end

local function run_model(q)
  compy.ldraw.ldr_pyramid(q, Mat.unit(3), Vec.d3(0, 0, 0), nil)
end

local function draw_selected()
  local s = SELECTED
  s.sub(Red, s.M, s.T, nil)
end

local function draw_scene()
  gfx.setColor(0, 0, 0, 1)
  draw(function()
    run_model(ROOT_COLOR)
  end)
  if SELECTED then
    gfx.setColor(1, 0, 0, 1)
    draw(draw_selected)
  end
end

function love.mousepressed(mx, my)
  SELECTED = pick(function()
    run_model(ROOT_COLOR)
  end, mouse_ray(mx, my))
end

function love.draw()
  gfx.clear(1, 1, 1, 1)
  draw_scene()
end

load_chunks()
detect_parts()
setup_view()
