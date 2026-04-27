-- LDraw to Lua transpiler.
-- Converts one LDraw file (.ldr/.dat/.mpd) into a Lua chunk of
-- top-level DSL calls for the Compy edgetest runtime.

-- Matrix comparison tolerance per the LDraw spec.

TOL = 0.0005

-- Column limit enforced by the Compy editor. All emit helpers
-- wrap long output so that no generated line exceeds it.

COLUMN_LIMIT = 64

-- LDraw colour code that means "use the current edge colour of
-- the enclosing scope" rather than a specific colour. Lines and
-- optional lines with this code transpile to the unsigned DSL
-- name (edge, outline); any other colour uses the q-variant.

EDGE_COLOUR = 24

-- Load the transpiler modules. Each module defines its helpers
-- as globals and does not return a namespace.
-- orthogonal_bases comes before transpiler.types because the
-- latter uses orthogonal_base when initialising its tables.

require "transpiler.util"
require "transpiler.emit"
require "orthogonal_bases"
require "transpiler.types"

-- Main: read the input file, normalise line endings, process
-- each line, and write the result.

function main(in_path, out_path)
  local src = read_file(in_path)
  src = src:gsub("\13\n", "\n"):gsub("\13", "\n")
  for line in (src .. "\n"):gmatch("([^\n]*)\n") do
    process_line(line)
  end
  write_file(out_path)
end

if arg and arg[1] and arg[2] then
  main(arg[1], arg[2])
  print("OK: " .. arg[1] .. " -> " .. arg[2])
end
