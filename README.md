# LDraw to Lua Transpiler

Third iteration. Converts LDraw files into Lua chunks for the
Compy edgetest runtime.

## Layout

    ldraw_transpile.lua
    orthogonal_bases.lua
    transpiler/
      util.lua
      emit.lua
      types.lua
      colors.lua
      base64.lua
      mpd.lua
      ldraw_color_id.lua
    compy/
      edgetest/
        main.lua
        linalg.lua
        ldraw.lua
        ldraw_colors.lua

Generated model chunks are not tracked. Regenerate them from a
local LDraw library before running the Compy project.

## Transpiler

Run:

    lua ldraw_transpile.lua input.ldr output.lua

The transpiler handles Type 0 colour/category/keyword metas,
Type 1 matrix dispatch, Types 2-5 drawing calls, identifier
mangling, MPD `FILE`/`NOFILE` blocks, and MPD `!DATA` base64
payloads.

Colour indices are resolved through
`transpiler/ldraw_color_id.lua`. Generated chunks use colour
symbols such as `Blue`, `MAIN_COLOR`, and `EDGE_COLOR` instead
of numeric LDraw colour codes. Unknown colour codes stop the
transpiler with an error.

`LDConfig.ldr` colour definitions are committed as
`compy/edgetest/ldraw_colors.lua`. Runtime code requires this
file before loading `ldraw.lua`.

## Runtime

`compy/edgetest/ldraw.lua` owns LDraw tree traversal. It carries
the current transformation matrix `M`, displacement vector `T`,
`MAIN_COLOR`, and `EDGE_COLOR` through sub-tree calls. Each
reference saves the old values in locals, updates the current
frame, invokes the sub-tree, and restores the old values.

The drawing surface is controlled by a pluggable
`project(x, y, z)` function. The current test entry uses one
perspective projection centered on the screen:

    local dz = D / z
    return CENTER_X + x * dz, CENTER_Y + y * dz

Only `edge` and `outline` draw in this iteration. `line`, `tri`,
`quad`, colour outlines, and remaining metas are no-ops.

## Test Model

The edgetest project uses the pyramid model and its required
parts/primitives from a local LDraw library. Regenerate the
chunks under `compy/edgetest/` before copying the project to
Compy.
