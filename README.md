# LDraw to Lua Transpiler

Second iteration. Converts LDraw part files (`.dat`/`.ldr`/`.mpd`)
into Lua chunks that run on the Compy platform and render
wireframe projections of LEGO-compatible parts and assemblies.

## How it works

LDraw parts are transpiled ahead of time into Lua chunks that
call a small drawing DSL. At runtime the Compy project loads
the chunks and invokes the root chunk to draw the model in
four projections.

A single global transformation is maintained: a 3x3 rotation
matrix `M` and a translation vector `T`. A point `v` in local
space is mapped to global space as `M*v + T`. Reference-style
DSL functions (`ref`, `placeN`, `placeE`, ..., `stretch`)
save the current `M` and `T` into local variables, update
them for the sub-tree, invoke the sub-part, and restore on
return. There is no matrix stack — save and restore happen
through Lua's lexical scope.

The drawing DSL is parameterised by a pluggable projection
function `project(x, y, z)` that returns 2D screen coordinates.
The model is rendered four times in sequence — front, side,
top, and isometric — by re-invoking the root chunk with a
different `project` each time.

## Repository layout

    ldraw_transpile.lua     -- transpiler entry point
    orthogonal_bases.lua    -- 47 orthogonal 3x3 bases (data)
    transpiler/             -- transpiler modules
      util.lua              -- formatting and I/O helpers
      emit.lua              -- Lua call generation
      types.lua             -- LDraw line-type handling
    compy/
      edgetest/             -- Compy project
        main.lua            -- runtime entry point
        linalg.lua          -- linear algebra library
    README.md
    .gitignore

LDraw library files (`.dat`/`.ldr`/`.mpd`) and transpiler
output (`compy/*/dat_*.lua`, `compy/*/ldr_*.lua`) are not
tracked; see `.gitignore`.

## Building

The transpiler writes its output to whatever path is given on
the command line. To prepare the edgetest project, transpile
the test files from the LDraw library into `compy/edgetest/`:

    lua ldraw_transpile.lua /path/to/ldraw/models/pyramid.ldr \
      compy/edgetest/ldr_pyramid.lua
    lua ldraw_transpile.lua /path/to/ldraw/parts/3001.dat \
      compy/edgetest/dat_3001.lua
    lua ldraw_transpile.lua /path/to/ldraw/parts/s/3001s01.dat \
      compy/edgetest/dat_3001s01.lua

Repeat for the remaining test files: `parts/3003.dat`,
`parts/s/3003s01.dat`, `parts/s/3003s02.dat`,
`p/4-4cyli.dat`, `p/4-4disc.dat`, `p/4-4edge.dat`,
`p/4-4ring3.dat`, `p/box3u2p.dat`, `p/box5.dat`,
`p/stud4.dat`, `p/stud.dat`, `p/stug-2x2.dat`.

The complete LDraw parts library is available at
<https://library.ldraw.org/library/updates/complete.zip>.

## Running

Open `compy/edgetest/` as a project in Compy; its `main.lua`
loads the transpiled chunks and renders the pyramid model in
four projections. Each projection is a separate pass over the
same model with a different `project(x, y, z)` function.

## DSL reference

Transpiled chunks call these globals, all defined in
`main.lua` (or resolved via the `_G` fallback metatable to
`empty_fn` when not implemented).

Drawing primitives:

- `edge(x1, y1, z1, x2, y2, z2)` — line in colour 24.
- `outline(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4)`
  — conditional line. The segment `p1-p2` is drawn only if
  the projections of `p3` and `p4` lie on the same side of
  the line through the projections of `p1` and `p2`.

Unimplemented in this iteration (resolved to no-op): `line`,
`tri`, `quad`, `color_outline`.

Sub-part references:

- `placeN(sub, q, x, y, z)` — identity rotation; only the
  translation is updated.
- `placeE`, `placeS`, `placeW(sub, q, x, y, z)` — 90, 180,
  and 270 degree rotations around the Y axis. Implemented
  via `Mat:orthogonal3` from linalg with indices 20, 5, 17
  respectively.
- `mirrorEW`, `mirrorUD`, `mirrorNS(sub, q, x, y, z)` —
  reflections across the YZ, XZ, and XY planes. Indices 1,
  2, 4 in the orthogonal_base table.
- `place(sub, q, x, y, z, i)` — general orthogonal placement
  with a runtime-supplied index `i` (1..47).
- `stretch(sub, q, x, y, z, a, e, i)` — diagonal scaling by
  `(a, e, i)`.
- `twist(sub, q, x, y, z, a, c)` — Y-axis rotation by the
  complex number `(a, c) = (cos, sin)`.
- `ref(sub, q, x, y, z, a, b, c, d, e, f, g, h, i)` — general
  3x3 rotation with 9 numbers in row-major LDraw order.

Meta commands (from Type 0 lines):

- `LDRAW_ORG("kind") -- comment` — first word becomes the
  argument, the rest of the line is appended as a comment.
- `CATEGORY("...")` — category name as a single argument.
- `PREVIEW(q, x, y, z, a, b, c, d, e, f, g, h, i)` — preview
  matrix for the part.
- `KEYWORD("...")` — one call per word from the
  `0 !KEYWORDS` line.
- `STEP`, `CLEAR`, `PAUSE`, `SAVE`, `WRITE`, `PRINT` —
  no-ops at runtime in this iteration.

## Specification coverage

Implemented from the LDraw file spec
(<https://www.ldraw.org/article/218.html>):

- Type 0: `STEP`, `CLEAR`, `PAUSE`, `SAVE`, `WRITE`, `PRINT`,
  `!CATEGORY`, `!LDRAW_ORG`, `!PREVIEW`, `!KEYWORDS` meta
  dispatch through parallel pattern/handler tables. All
  other lines become comments, word-wrapped at column 64
  with a two-space continuation indent.
- Type 1: matrix shape dispatch in order — identity to
  `placeN`, named orthogonal indices to
  `placeE`/`placeS`/`placeW`/`mirrorEW`/`mirrorUD`/
  `mirrorNS`, any other orthogonal to `place(... i)`,
  diagonal to `stretch`, twist shape to `twist`, general
  case to `ref`. Reference prefix stripping (`s\`, `p\`)
  and identifier mangling (`name.ext` -> `ext_name` with
  dashes replaced by underscores).
- Type 2: `edge` (colour 24) and `line` (explicit colour).
- Type 3: `tri`.
- Type 4: `quad`.
- Type 5: `outline` (colour 24, full conditional line) and
  `color_outline`.
- Blank line collapsing.

## Linear algebra

The runtime depends on `linalg.lua` (loaded via `require`),
which exposes `Vec` and `Mat` classes. Reference-style DSL
functions use `Vec:tr(M)` to apply rotation, `Vec:acc(T)` to
add translation, `Mat:mul` to compose general rotations, and
`Mat:orthogonal3(i)` for the optimised 47 orthogonal
transformations indexed by `orthogonal_base`.

The transpiler uses `orthogonal_base` for matrix shape
matching at compile time. The runtime uses `Mat:orthogonal3`
to apply the corresponding transformation at run time.
