-- LDraw tree traversal runtime.

local gfx = love.graphics
local ORTHOGONAL3 = { }

do
  local unit = Mat.unit(3)
  for i = 1, 47 do
    ORTHOGONAL3[i] = unit:orthogonal3(i)
  end
end

M = Mat.unit(3)
T = Vec.d3(0, 0, 0)
VIEW_M = Mat.unit(3)
VIEW_T = Vec.d3(0, 0, 0)
MAIN_COLOR = Main_Colour
EDGE_COLOR = Edge_Colour

-- Fallback for DSL calls postponed to a later iteration.

function empty_fn()
end

STEP = empty_fn
CLEAR = empty_fn
PAUSE = empty_fn
SAVE = empty_fn
WRITE = empty_fn
PRINT = empty_fn
LDRAW_ORG = empty_fn
CATEGORY = empty_fn
PREVIEW = empty_fn
KEYWORD = empty_fn
line = empty_fn
tri = empty_fn
quad = empty_fn
color_outline = empty_fn

-- LDraw edge colour follows the current main colour.

function make_edge_color(q)
  return {
    value = q.edge,
    edge = q.edge
  }
end

-- Compy receives channels already normalised to 0..1.

function set_draw_color(q)
  local v = q.value
  gfx.setColor(v[1], v[2], v[3], v[4] or 1)
end

-- Apply the current tree frame to a local point.

function apply_global(p)
  local g = p:tr(M)
  g:acc(T)
  return g
end

-- Apply the camera transform after model traversal.

function apply_view(p)
  local g = p:tr(VIEW_M)
  g:acc(VIEW_T)
  return g
end

-- Project a transformed 3D point to screen coordinates.

function screen_point(x, y, z)
  local g = apply_view(apply_global(Vec.d3(x, y, z)))
  return project(g:c3())
end

-- Draw an LDraw type-2 edge in the current edge colour.

function edge(x1, y1, z1, x2, y2, z2)
  local sx1, sy1 = screen_point(x1, y1, z1)
  local sx2, sy2 = screen_point(x2, y2, z2)
  set_draw_color(EDGE_COLOR)
  gfx.line(sx1, sy1, sx2, sy2)
end

-- Conditional lines use the projected control points.

function same_side(ax, ay, bx, by, cx, cy, dx, dy)
  local vx, vy = bx - ax, by - ay
  local s1 = vx * (cy - ay) - vy * (cx - ax)
  local s2 = vx * (dy - ay) - vy * (dx - ax)
  return 0 <= s1 * s2
end

-- Draw an LDraw type-5 conditional edge.

function outline(x1, y1, z1, x2, y2, z2,
    x3, y3, z3, x4, y4, z4)
  local sx1, sy1 = screen_point(x1, y1, z1)
  local sx2, sy2 = screen_point(x2, y2, z2)
  local sx3, sy3 = screen_point(x3, y3, z3)
  local sx4, sy4 = screen_point(x4, y4, z4)
  if same_side(sx1, sy1, sx2, sy2, sx3, sy3, sx4, sy4) then
    set_draw_color(EDGE_COLOR)
    gfx.line(sx1, sy1, sx2, sy2)
  end
end

-- Invoke a sub-tree under an already composed frame.

function call_frame(sub, q, newM, newT)
  local oldM, oldT = M, T
  local oldMain, oldEdge = MAIN_COLOR, EDGE_COLOR
  M, T = newM, newT
  MAIN_COLOR = q
  EDGE_COLOR = make_edge_color(q)
  sub()
  M, T = oldM, oldT
  MAIN_COLOR, EDGE_COLOR = oldMain, oldEdge
end

-- Translate in the parent coordinate system.

function step_translation(oldM, oldT, x, y, z)
  local step = Vec.d3(x, y, z):tr(oldM)
  step:acc(oldT)
  return step
end

-- Compose a local transform into the current tree frame.

function call_transform(sub, q, x, y, z, m)
  local oldM, oldT = M, T
  local newM = m:mul(oldM)
  local newT = step_translation(oldM, oldT, x, y, z)
  call_frame(sub, q, newM, newT)
end

-- Identity placement changes only translation and colour.

function placeN(sub, q, x, y, z)
  local newT = step_translation(M, T, x, y, z)
  call_frame(sub, q, M, newT)
end

-- Generic orthogonal placement by linalg index.

function place(sub, q, x, y, z, i)
  call_transform(sub, q, x, y, z, ORTHOGONAL3[i])
end

-- South is orthogonal transformation 5.

function placeS(sub, q, x, y, z)
  place(sub, q, x, y, z, 5)
end

-- West is orthogonal transformation 17.

function placeW(sub, q, x, y, z)
  place(sub, q, x, y, z, 17)
end

-- East is orthogonal transformation 20.

function placeE(sub, q, x, y, z)
  place(sub, q, x, y, z, 20)
end

-- Mirror across the east-west axis.

function mirrorEW(sub, q, x, y, z)
  place(sub, q, x, y, z, 1)
end

-- Mirror across the up-down axis.

function mirrorUD(sub, q, x, y, z)
  place(sub, q, x, y, z, 2)
end

-- Mirror across the north-south axis.

function mirrorNS(sub, q, x, y, z)
  place(sub, q, x, y, z, 4)
end

-- Build a diagonal scaling matrix.

function stretch_mat(a, e, i)
  return Mat:new({
    Vec.d3(a, 0, 0),
    Vec.d3(0, e, 0),
    Vec.d3(0, 0, i)
  })
end

-- Compose a diagonal stretch into the traversal frame.

function stretch(sub, q, x, y, z, a, e, i)
  local s = stretch_mat(a, e, i)
  call_transform(sub, q, x, y, z, s)
end

-- Build the compact twist rotation matrix.

function make_twist_mat(a, c)
  return Mat:new({
    Vec.d3(a, 0, -c),
    Vec.d3(0, 1, 0),
    Vec.d3(c, 0, a)
  })
end

-- Compose a twist transform into the traversal frame.

function twist(sub, q, x, y, z, a, c)
  local m = make_twist_mat(a, c)
  call_transform(sub, q, x, y, z, m)
end

-- Convert LDraw row-major coefficients to linalg columns.

function make_ref_mat(a, b, c, d, e, f, g, h, i)
  return Mat:new({
    Vec.d3(a, d, g),
    Vec.d3(b, e, h),
    Vec.d3(c, f, i)
  })
end

-- Compose a general Type 1 reference matrix.

function ref(sub, q, x, y, z, a, b, c, d, e, f, g, h, i)
  local m = make_ref_mat(a, b, c, d, e, f, g, h, i)
  call_transform(sub, q, x, y, z, m)
end
