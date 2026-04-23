-- 3D vectors as flat three-element tables {x, y, z}.

function vec_new(x, y, z)
  local v = { }
  v[1], v[2], v[3] = x, y, z
  return v
end

-- Return the components of a vector as three values.

function vec_unpack(v)
  return v[1], v[2], v[3]
end

-- Dot product of two vectors.

function vec_dot(a, b)
  return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

-- Sum of two vectors.

function vec_add(a, b)
  return vec_new(a[1] + b[1], a[2] + b[2], a[3] + b[3])
end
