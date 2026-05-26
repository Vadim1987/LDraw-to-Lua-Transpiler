-- LDraw tree traversal runtime. The compy.ldraw table is the
-- shared environment of all transpiled chunks. Every callback
-- the chunks invoke -- placement, BFC, meta, geometry -- is
-- provided by the active pass via the table's __index. This
-- file holds only what is shared across passes: the namespace,
-- frame math, and a BFC default table that passes can copy.

compy = { }
compy.ldraw = { }

-- Parts membership. Filled by detect_parts at startup; used
-- by pick to mark a sub-chunk as a selectable Part.

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

-- Frame composition helpers. Pure math, used by placement
-- callbacks of every pass.

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

-- BFC defaults. Each callback takes W and returns the new W.
-- W is +1 (CCW), -1 (CW), or nil (no BFC). Passes that need
-- BFC support copy these entries into their callback table.

BFC_DEFAULTS = { }

function BFC_DEFAULTS.BFC_CERTIFY(W, sign)
  return sign
end

function BFC_DEFAULTS.BFC_NOCERTIFY(W)
  return nil
end

function BFC_DEFAULTS.BFC(W, sign)
  if W then
    return sign
  end
end

function BFC_DEFAULTS.BFC_INVERT(W)
  if W then
    return -W
  end
end

function BFC_DEFAULTS.BFC_CLIP(W, sign)
  return sign or W
end

function BFC_DEFAULTS.BFC_NOCLIP(W)
  return nil
end

-- Indexed placements that are shorthand for place(... i) with
-- a fixed orthogonal_base index. Same mapping as NAMED_INDEX
-- in transpiler/types.lua. Each pass installs these in its
-- own callback table; this constant only fixes the names.

INDEXED_PLACEMENTS = {
  placeS = 5, 
  placeW = 17, 
  placeE = 20,
  mirrorEW = 1, 
  mirrorUD = 2, 
  mirrorNS = 4
}
