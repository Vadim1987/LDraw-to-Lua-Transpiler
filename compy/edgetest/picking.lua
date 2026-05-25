-- Ray picking pass for transpiled LDraw trees.
-- The pick body lives in pick.lua and is loaded as a function
-- so the Compy editor can edit it as its own chunk. The body
-- chunk receives (root, ray) via ... on each call.

-- Numeric scratch buffers reused for every polygon test.
-- Workspace, not state: each polygon_test fills these from
-- scratch before reading.

GX = { }
GY = { }
GZ = { }

-- Apply M, T to local (x, y, z); store into scratch at slot i.

function global_xyz(M, T, x, y, z, i)
  local p = Vec.d3(x, y, z):tr(M)
  p:acc(T)
  GX[i], GY[i], GZ[i] = p:c3()
end

-- Fill GX/GY/GZ slots 1..n from a flat list of locals.

function load_globals(M, T, n, ...)
  for i = 1, n do
    local b = (i - 1) * 3
    global_xyz(
      M,
      T,
      select(b + 1, ...),
      select(b + 2, ...),
      select(b + 3, ...),
      i
    )
  end
end

-- Polygon normal from the first three vertices.

function normal3()
  local ax, ay, az = GX[2] - GX[1], GY[2] - GY[1], GZ[2] - GZ[1]
  local bx, by, bz = GX[3] - GX[1], GY[3] - GY[1], GZ[3] - GZ[1]
  return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
end

-- Signed volume of (p2-p1, p3-p1, origin-p1).

function signed_volume(ox, oy, oz)
  local ax, ay, az = GX[2] - GX[1], GY[2] - GY[1], GZ[2] - GZ[1]
  local bx, by, bz = GX[3] - GX[1], GY[3] - GY[1], GZ[3] - GZ[1]
  local cx, cy, cz = ox - GX[1], oy - GY[1], oz - GZ[1]
  return (ax * (by * cz - bz * cy) - ay * (bx * cz - bz * cx))
       + az * (bx * cy - by * cx)
end

-- Intersect ray with polygon plane; return positive distance
-- or nil.

function ray_plane(ox, oy, oz, dx, dy, dz, nx, ny, nz)
  local det = dx * nx + dy * ny + dz * nz
  if math.abs(det) < TOL then
    return 
  end
  local tx, ty, tz = ox - GX[1], oy - GY[1], oz - GZ[1]
  local l = -(tx * nx + ty * ny + tz * nz) / det
  if TOL <= l then
    return l
  end
end

-- Cross of (edge i->j) with (hit - GX[i]), dotted with normal.

function edge_side(i, j, hx, hy, hz, nx, ny, nz)
  local ex, ey, ez = GX[j] - GX[i], GY[j] - GY[i], GZ[j] - GZ[i]
  local tx, ty, tz = hx - GX[i], hy - GY[i], hz - GZ[i]
  local cx, cy, cz = ey * tz - ez * ty, ez * tx - ex * tz, ex * 
      ty - ey * tx
  return cx * nx + cy * ny + cz * nz
end

-- True if hit lies on the inside of every polygon edge.

function point_in_convex(n, hx, hy, hz, nx, ny, nz)
  for i = 1, n do
    local j = i % n + 1
    if edge_side(i, j, hx, hy, hz, nx, ny, nz) < 0 then
      return false
    end
  end
  return true
end

-- pick(root, ray) is the loaded pick.lua chunk. It returns
-- (hit, hit_l) after running root and accumulating closest
-- polygon intersection across all Part subtrees.

pick = loadfile("pick.lua")
