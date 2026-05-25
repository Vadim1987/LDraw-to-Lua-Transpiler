-- Pick pass body. Loaded once at runtime via loadfile and
-- called repeatedly as a function. Each invocation re-runs
-- this chunk with fresh (root, ray) and fresh local state.
-- State lives as upvalues of the closures installed in
-- compy.ldraw; no module-level mutable state.

local root, ray = ...

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

local function call_sub(sub, q, M, T, W)
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

L.tri = function(M, T, W, q,
    x1, y1, z1, x2, y2, z2, x3, y3, z3)
  load_globals(M, T, 3,
    x1, y1, z1, x2, y2, z2, x3, y3, z3)
  polygon_test(3, W)
end

L.quad = function(M, T, W, q,
    x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4)
  load_globals(M, T, 4,
    x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4)
  polygon_test(4, W)
end

L.placeN = function(M, T, W, sub, q, x, y, z)
  if sub then
    call_sub(sub, q, M, L.step_t(M, T, x, y, z), W)
  end
end

L.place = function(M, T, W, sub, q, x, y, z, i)
  if sub then
    call_sub(sub, q, M:orthogonal3(i),
      L.step_t(M, T, x, y, z), W)
  end
end

L.placeS = function(M, T, W, sub, q, x, y, z)
  L.place(M, T, W, sub, q, x, y, z, 5)
end

L.placeW = function(M, T, W, sub, q, x, y, z)
  L.place(M, T, W, sub, q, x, y, z, 17)
end

L.placeE = function(M, T, W, sub, q, x, y, z)
  L.place(M, T, W, sub, q, x, y, z, 20)
end

L.mirrorEW = function(M, T, W, sub, q, x, y, z)
  L.place(M, T, W, sub, q, x, y, z, 1)
end

L.mirrorUD = function(M, T, W, sub, q, x, y, z)
  L.place(M, T, W, sub, q, x, y, z, 2)
end

L.mirrorNS = function(M, T, W, sub, q, x, y, z)
  L.place(M, T, W, sub, q, x, y, z, 4)
end

L.stretch = function(M, T, W, sub, q, x, y, z, a, e, i)
  if sub then
    call_sub(sub, q, Mat.diag(a, e, i):mul(M),
      L.step_t(M, T, x, y, z), W)
  end
end

L.twist = function(M, T, W, sub, q, x, y, z, a, c)
  if sub then
    call_sub(sub, q, L.twist_m(a, c):mul(M),
      L.step_t(M, T, x, y, z), W)
  end
end

L.ref = function(M, T, W, sub, q, x, y, z,
    a, b, c, d, e, f, g, h, i)
  if sub then
    call_sub(sub, q,
      L.ref_m(a, b, c, d, e, f, g, h, i):mul(M),
      L.step_t(M, T, x, y, z), W)
  end
end

L.edge = ignore
L.line = ignore
L.outline = ignore
L.color_outline = ignore

root()
return hit, hit_l
