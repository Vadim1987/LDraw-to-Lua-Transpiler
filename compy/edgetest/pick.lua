-- Pick pass body. Loaded once at runtime via loadfile and
-- called repeatedly as a function. Each invocation re-runs
-- this chunk with fresh (root, ray) and fresh local state.
-- The pass installs its callback table for the duration of
-- the traversal; no module-level mutable state.

local root, ray, radii = ...

local ox, oy, oz = ray.origin:c3()
local dx, dy, dz = ray.dir:c3()
local hit, hit_l = nil, math.huge
local current_part
local L = compy.ldraw

local function record(l)
  if current_part and l < hit_l then
    hit, hit_l = current_part, l
  end
end

local function polygon_test(n, W)
  local nx, ny, nz = normal3()
  local l = ray_plane(ox, oy, oz, dx, dy, dz, nx, ny, nz)
  if not l then
    return 
  end
  if W and signed_volume(ox, oy, oz) * W < 0 then
    return 
  end
  local hx, hy, hz = ox + dx * l, oy + dy * l, oz + dz * l
  if point_in_convex(n, hx, hy, hz, nx, ny, nz) then
    record(l)
  end
end

local function call_sub_any(sub, q, M, T, W)
  if L.parts[sub] then
    local saved = current_part
    current_part = {
      sub = sub,
      M = M,
      T = T
    }
    sub(q, M, T, W)
    current_part = saved
  else
    sub(q, M, T, W)
  end
end

-- Orthonormal placements may skip a subtree whose bounding
-- sphere the ray misses.

local function call_sub_ortho(sub, q, M, T, W)
  if radii and radii[sub] then
    local cx, cy, cz = T:c3()
    if not sphere_test(ox, oy, oz, dx, dy, dz,
        cx, cy, cz, radii[sub]) then
      return
    end
  end
  call_sub_any(sub, q, M, T, W)
end

local PICK_CALLBACKS = { }
PICK_CALLBACKS.edge = ignore
PICK_CALLBACKS.line = ignore
PICK_CALLBACKS.outline = ignore
PICK_CALLBACKS.color_outline = ignore
PICK_CALLBACKS.LDRAW_ORG = ignore
PICK_CALLBACKS.STEP = ignore
PICK_CALLBACKS.CLEAR = ignore
PICK_CALLBACKS.PAUSE = ignore
PICK_CALLBACKS.SAVE = ignore
PICK_CALLBACKS.WRITE = ignore
PICK_CALLBACKS.PRINT = ignore
PICK_CALLBACKS.CATEGORY = ignore
PICK_CALLBACKS.PREVIEW = ignore
PICK_CALLBACKS.KEYWORD = ignore

for k, v in pairs(BFC_DEFAULTS) do
  PICK_CALLBACKS[k] = v
end

PICK_CALLBACKS.tri = function(M, T, W, q,
    x1, y1, z1, x2, y2, z2, x3, y3, z3)
  load_globals(M, T, 3,
    x1, y1, z1, x2, y2, z2, x3, y3, z3)
  polygon_test(3, W)
end

PICK_CALLBACKS.quad = function(M, T, W, q,
    x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4)
  load_globals(M, T, 4,
    x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4)
  polygon_test(4, W)
end

PICK_CALLBACKS.placeN = function(M, T, W, sub, q, x, y, z)
  if sub then
    call_sub_ortho(sub, q, M, L.step_t(M, T, x, y, z), W)
  end
end

PICK_CALLBACKS.place = function(M, T, W, sub, q, x, y, z, i)
  if sub then
    call_sub_ortho(sub, q, M:orthogonal3(i),
      L.step_t(M, T, x, y, z), W)
  end
end

-- Build a pick placement closure that calls PICK_CALLBACKS.place with a
-- fixed orthogonal_base index. Used to materialise placeS/W/E
-- and mirrorEW/UD/NS from INDEXED_PLACEMENTS.

local function make_pick_indexed(i)
  return function(M, T, W, sub, q, x, y, z)
    PICK_CALLBACKS.place(M, T, W, sub, q, x, y, z, i)
  end
end

for name, i in pairs(INDEXED_PLACEMENTS) do
  PICK_CALLBACKS[name] = make_pick_indexed(i)
end

-- Non-orthonormal placements skip the sphere test entirely;
-- the bounding radius is in part-local coordinates and would
-- need to be scaled by the largest eigenvalue of the transform
-- to remain valid. TODO: extend skip support to these.

PICK_CALLBACKS.stretch = function(M, T, W, sub, q, x, y, z, a, e, i)
  if sub then
    call_sub_any(sub, q, Mat.diag(a, e, i):mul(M),
      L.step_t(M, T, x, y, z), W)
  end
end

PICK_CALLBACKS.twist = function(M, T, W, sub, q, x, y, z, a, c)
  if sub then
    call_sub_any(sub, q, L.twist_m(a, c):mul(M),
      L.step_t(M, T, x, y, z), W)
  end
end

PICK_CALLBACKS.ref = function(M, T, W, sub, q, x, y, z,
    a, b, c, d, e, f, g, h, i)
  if sub then
    call_sub_any(sub, q,
      L.ref_m(a, b, c, d, e, f, g, h, i):mul(M),
      L.step_t(M, T, x, y, z), W)
  end
end

setmetatable(compy.ldraw, { __index = PICK_CALLBACKS })
root()
return hit, hit_l
