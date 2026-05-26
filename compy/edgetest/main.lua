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
local PART_RADII

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
  for _, name in ipairs(DAT_FILES) do
    load_chunk(name)
  end
  load_chunk("ldr_pyramid")
end

-- Detect pass callback table. Everything ignores except
-- LDRAW_ORG; that one is set per chunk to mark Part membership.

local DETECT_CALLBACKS = { }
DETECT_CALLBACKS.placeN = ignore
DETECT_CALLBACKS.place = ignore
DETECT_CALLBACKS.placeS = ignore
DETECT_CALLBACKS.placeW = ignore
DETECT_CALLBACKS.placeE = ignore
DETECT_CALLBACKS.mirrorEW = ignore
DETECT_CALLBACKS.mirrorUD = ignore
DETECT_CALLBACKS.mirrorNS = ignore
DETECT_CALLBACKS.stretch = ignore
DETECT_CALLBACKS.twist = ignore
DETECT_CALLBACKS.ref = ignore
DETECT_CALLBACKS.edge = ignore
DETECT_CALLBACKS.line = ignore
DETECT_CALLBACKS.outline = ignore
DETECT_CALLBACKS.color_outline = ignore
DETECT_CALLBACKS.tri = ignore
DETECT_CALLBACKS.quad = ignore
DETECT_CALLBACKS.LDRAW_ORG = ignore
DETECT_CALLBACKS.STEP = ignore
DETECT_CALLBACKS.CLEAR = ignore
DETECT_CALLBACKS.PAUSE = ignore
DETECT_CALLBACKS.SAVE = ignore
DETECT_CALLBACKS.WRITE = ignore
DETECT_CALLBACKS.PRINT = ignore
DETECT_CALLBACKS.CATEGORY = ignore
DETECT_CALLBACKS.PREVIEW = ignore
DETECT_CALLBACKS.KEYWORD = ignore

for k, v in pairs(BFC_DEFAULTS) do
  DETECT_CALLBACKS[k] = v
end

-- Run chunk once with all DSL silenced except LDRAW_ORG, which
-- marks the chunk as a Part if its kind is "Part".

local function detect_part(chunk)
  DETECT_CALLBACKS.LDRAW_ORG = function(kind)
    if kind == "Part" then
      compy.ldraw.parts[chunk] = true
    end
  end
  setmetatable(compy.ldraw, { __index = DETECT_CALLBACKS })
  chunk(ROOT_COLOR, Mat.unit(3), Vec.d3(0, 0, 0), nil)
end

local function detect_parts()
  for _, name in ipairs(DAT_FILES) do
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

-- Bounding sphere radii in LDU for the parts used by the
-- pyramid, measured from the part's local origin to its
-- farthest vertex and rounded up. Picking uses these to skip
-- subtrees the ray misses.

local function setup_radii()
  PART_RADII = {
    [compy.ldraw.dat_3001] = 51,
    [compy.ldraw.dat_3003] = 38
  }
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

-- Draw placement callbacks. Each composes the child frame and
-- recurses; no extra bookkeeping is needed for rendering.

local function draw_placeN(M, T, W, sub, q, x, y, z)
  if sub then
    sub(q, M, compy.ldraw.step_t(M, T, x, y, z), W)
  end
end

local function draw_place(M, T, W, sub, q, x, y, z, i)
  if sub then
    sub(q, M:orthogonal3(i),
      compy.ldraw.step_t(M, T, x, y, z), W)
  end
end

-- Build a draw placement closure that calls draw_place with a
-- fixed orthogonal_base index. Used to materialise placeS/W/E
-- and mirrorEW/UD/NS from INDEXED_PLACEMENTS.

local function make_draw_indexed(i)
  return function(M, T, W, sub, q, x, y, z)
    draw_place(M, T, W, sub, q, x, y, z, i)
  end
end

local function draw_stretch(M, T, W, sub, q, x, y, z, a, e, i)
  if sub then
    sub(q, Mat.diag(a, e, i):mul(M),
      compy.ldraw.step_t(M, T, x, y, z), W)
  end
end

local function draw_twist(M, T, W, sub, q, x, y, z, a, c)
  if sub then
    sub(q, compy.ldraw.twist_m(a, c):mul(M),
      compy.ldraw.step_t(M, T, x, y, z), W)
  end
end

local function draw_ref(M, T, W, sub, q, x, y, z,
    a, b, c, d, e, f, g, h, i)
  if sub then
    sub(q, compy.ldraw.ref_m(a, b, c, d, e, f, g, h, i):mul(M),
      compy.ldraw.step_t(M, T, x, y, z), W)
  end
end

-- Draw callback table. All chunk hooks the draw pass uses are
-- registered here; the table is installed before traversal.

local DRAW_CALLBACKS = { }
DRAW_CALLBACKS.placeN = draw_placeN
DRAW_CALLBACKS.place = draw_place
DRAW_CALLBACKS.stretch = draw_stretch
DRAW_CALLBACKS.twist = draw_twist
DRAW_CALLBACKS.ref = draw_ref
DRAW_CALLBACKS.edge = draw_edge
DRAW_CALLBACKS.line = draw_line
DRAW_CALLBACKS.outline = draw_outline
DRAW_CALLBACKS.color_outline = draw_color_outline
DRAW_CALLBACKS.tri = ignore
DRAW_CALLBACKS.quad = ignore
DRAW_CALLBACKS.LDRAW_ORG = ignore
DRAW_CALLBACKS.STEP = ignore
DRAW_CALLBACKS.CLEAR = ignore
DRAW_CALLBACKS.PAUSE = ignore
DRAW_CALLBACKS.SAVE = ignore
DRAW_CALLBACKS.WRITE = ignore
DRAW_CALLBACKS.PRINT = ignore
DRAW_CALLBACKS.CATEGORY = ignore
DRAW_CALLBACKS.PREVIEW = ignore
DRAW_CALLBACKS.KEYWORD = ignore

for name, i in pairs(INDEXED_PLACEMENTS) do
  DRAW_CALLBACKS[name] = make_draw_indexed(i)
end

for k, v in pairs(BFC_DEFAULTS) do
  DRAW_CALLBACKS[k] = v
end

-- Draw pass: install draw callbacks and run root.

function draw(root)
  setmetatable(compy.ldraw, { __index = DRAW_CALLBACKS })
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
  end, mouse_ray(mx, my), PART_RADII)
end

function love.draw()
  gfx.clear(1, 1, 1, 1)
  draw_scene()
end

load_chunks()
detect_parts()
setup_view()
setup_radii()
