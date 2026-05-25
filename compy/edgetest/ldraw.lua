-- LDraw tree traversal runtime.

-- Virtual LEGO namespace. ldraw chunks live here; this table
-- is also their environment. DSL callbacks live here with
-- regular _G env.

compy = { }
compy.ldraw = { }

-- Parts membership. Populated after load via diagnostic
-- LDRAW_ORG-only pass over each chunk.

compy.ldraw.parts = { }

-- A do-nothing callback used by any pass that wants to silence
-- a particular DSL hook.

function ignore()
  
end

-- Load filename in a private env and return that env as a
-- table. The returned table is the chunk's _G. General-purpose
-- helper for any caller that wants a chunk's bindings.

function loadtable(filename)
  local env = { }
  local chunk = assert(loadfile(filename))
  setfenv(chunk, env)
  chunk()
  return env
end

-- Frame composition helpers. Both draw and pick passes use
-- these to compose child frames from parent (M, T) plus
-- per-call shape data.

-- Translate (x, y, z) by m, then accumulate t.

function compy.ldraw.step_t(m, t, x, y, z)
  local s = Vec.d3(x, y, z):tr(m)
  s:acc(t)
  return s
end

-- Build the twist matrix for parameters (a, c).

function compy.ldraw.twist_m(a, c)
  return Mat:new({
    Vec.d3(a, 0, -c),
    Vec.d3(0, 1, 0),
    Vec.d3(c, 0, a)
  })
end

-- Build the general reference matrix from 9 LDraw entries.

function compy.ldraw.ref_m(a, b, c, d, e, f, g, h, i)
  return Mat:new({
    Vec.d3(a, d, g),
    Vec.d3(b, e, h),
    Vec.d3(c, f, i)
  })
end

-- Virtual LEGO DSL. Each placement function receives parent's
-- frame (M, T, W) and the subref data, then invokes sub with
-- the composed child frame.

function compy.ldraw.placeN(M, T, W, sub, q, x, y, z)
  if sub then
    sub(q, M, compy.ldraw.step_t(M, T, x, y, z), W)
  end
end

function compy.ldraw.place(M, T, W, sub, q, x, y, z, i)
  if sub then
    sub(q, M:orthogonal3(i),
      compy.ldraw.step_t(M, T, x, y, z), W)
  end
end

function compy.ldraw.placeS(M, T, W, sub, q, x, y, z)
  compy.ldraw.place(M, T, W, sub, q, x, y, z, 5)
end

function compy.ldraw.placeW(M, T, W, sub, q, x, y, z)
  compy.ldraw.place(M, T, W, sub, q, x, y, z, 17)
end

function compy.ldraw.placeE(M, T, W, sub, q, x, y, z)
  compy.ldraw.place(M, T, W, sub, q, x, y, z, 20)
end

function compy.ldraw.mirrorEW(M, T, W, sub, q, x, y, z)
  compy.ldraw.place(M, T, W, sub, q, x, y, z, 1)
end

function compy.ldraw.mirrorUD(M, T, W, sub, q, x, y, z)
  compy.ldraw.place(M, T, W, sub, q, x, y, z, 2)
end

function compy.ldraw.mirrorNS(M, T, W, sub, q, x, y, z)
  compy.ldraw.place(M, T, W, sub, q, x, y, z, 4)
end

function compy.ldraw.stretch(M, T, W, sub, q, x, y, z, a, e, i)
  if sub then
    sub(q, Mat.diag(a, e, i):mul(M),
      compy.ldraw.step_t(M, T, x, y, z), W)
  end
end

function compy.ldraw.twist(M, T, W, sub, q, x, y, z, a, c)
  if sub then
    sub(q, compy.ldraw.twist_m(a, c):mul(M),
      compy.ldraw.step_t(M, T, x, y, z), W)
  end
end

function compy.ldraw.ref(M, T, W, sub, q, x, y, z,
    a, b, c, d, e, f, g, h, i)
  if sub then
    sub(q, compy.ldraw.ref_m(a, b, c, d, e, f, g, h, i):mul(M),
      compy.ldraw.step_t(M, T, x, y, z), W)
  end
end

-- Default BFC implementation. Each callback takes W and
-- returns the new W. W is +1 (CCW), -1 (CW), or nil (no BFC).

function compy.ldraw.BFC_CERTIFY(W, sign)
  return sign
end

function compy.ldraw.BFC_NOCERTIFY(W)
  return nil
end

function compy.ldraw.BFC(W, sign)
  if W then
    return sign
  end
end

function compy.ldraw.BFC_INVERT(W)
  if W then
    return -W
  end
end

function compy.ldraw.BFC_CLIP(W, sign)
  return sign or W
end

function compy.ldraw.BFC_NOCLIP(W)
  return nil
end

-- No-op meta callbacks. Passes override these on entry.

compy.ldraw.LDRAW_ORG = ignore
compy.ldraw.STEP = ignore
compy.ldraw.CLEAR = ignore
compy.ldraw.PAUSE = ignore
compy.ldraw.SAVE = ignore
compy.ldraw.WRITE = ignore
compy.ldraw.PRINT = ignore
compy.ldraw.CATEGORY = ignore
compy.ldraw.PREVIEW = ignore
compy.ldraw.KEYWORD = ignore

-- Default geometry no-ops. Pass entries swap these with
-- pass-specific closures.

compy.ldraw.edge = ignore
compy.ldraw.line = ignore
compy.ldraw.outline = ignore
compy.ldraw.color_outline = ignore
compy.ldraw.tri = ignore
compy.ldraw.quad = ignore
