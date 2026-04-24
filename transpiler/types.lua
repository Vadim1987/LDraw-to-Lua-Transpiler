-- LDraw line-type handling for the transpiler. Covers Type 0
-- meta commands, Type 1 sub-part references with matrix shape
-- dispatch, Types 2-5 drawing primitives, and the top-level
-- line dispatcher.

-- Type 0 meta commands.

-- A factory that returns a handler emitting a no-argument call
-- with the given DSL name.

function make_nullary_emitter(name)
  return function()
    emit_call(name, { })
  end
end

-- A factory that returns a handler emitting a call with one
-- quoted string argument (the captured text).

function make_text_emitter(name)
  return function(msg)
    emit_call(name, { string.format("%q", msg) })
  end
end

-- Type 0 patterns as two parallel tables. Adding another meta
-- pattern is one line in each table.

META_PATTERN = {
  "^STEP%s*$",
  "^CLEAR%s*$",
  "^PAUSE%s*$",
  "^SAVE%s*$",
  "^WRITE%s+(.*)$",
  "^PRINT%s+(.*)$"
}

META_HANDLER = {
  make_nullary_emitter("STEP"),
  make_nullary_emitter("CLEAR"),
  make_nullary_emitter("PAUSE"),
  make_nullary_emitter("SAVE"),
  make_text_emitter("WRITE"),
  make_text_emitter("PRINT")
}

-- Dispatch a Type 0 line: match its text against each pattern
-- in order, invoking the first matching handler. Lines that
-- match no pattern fall through to the comment emitter.

function handle_type0(rest)
  for i = 1, #META_PATTERN do
    local cap = rest:match(META_PATTERN[i])
    if cap then
      META_HANDLER[i](cap)
      return
    end
  end
  emit_comment(rest)
end

-- Type 1 matrix shape dispatch.

-- Check whether the nine matrix entries match a fixed pattern
-- of constants. The pattern is a 9-element table with the same
-- index convention as m.

function matches_matrix(m, pattern)
  for i = 1, 9 do
    if not approx_eq(m[i], pattern[i]) then
      return false
    end
  end
  return true
end

-- Factory that packs nine matrix entries into a 9-element
-- pattern table without an expanded table literal.

function make_pattern(a, b, c, d, e, f, g, h, i)
  local p = { }
  p[1], p[2], p[3] = a, b, c
  p[4], p[5], p[6] = d, e, f
  p[7], p[8], p[9] = g, h, i
  return p
end

-- Fixed rotation patterns for compass-direction placement, as
-- three parallel tables.

PLACE_PATTERN = {
  make_pattern(1, 0, 0, 0, 1, 0, 0, 0, 1),
  make_pattern(0, 0, 1, 0, 1, 0, -1, 0, 0),
  make_pattern(-1, 0, 0, 0, 1, 0, 0, 0, -1),
  make_pattern(0, 0, -1, 0, 1, 0, 1, 0, 0)
}

PLACE_NAME = {
  "placeN",
  "placeE",
  "placeS",
  "placeW"
}

-- Check whether m matches a placeN/E/S/W pattern; return the
-- matching DSL name or nil if no match.

function match_place(m)
  for i = 1, #PLACE_PATTERN do
    if matches_matrix(m, PLACE_PATTERN[i]) then
      return PLACE_NAME[i]
    end
  end
  return nil
end

-- The twist shape is [a, 0, c; 0, 1, 0; -c, 0, a]. It has two
-- free scalars, a and c, so it cannot be matched against a
-- constant pattern.

function is_twist(m)
  return approx_eq(m[2], 0)
    and approx_eq(m[4], 0) and approx_eq(m[5], 1)
    and approx_eq(m[6], 0) and approx_eq(m[8], 0)
    and approx_eq(m[1], m[9]) and approx_eq(m[3], -m[7])
end

-- Parse a Type 1 line. Tokens: "1", colour, tx, ty, tz, nine
-- matrix entries, filename.

function parse_type1(tokens)
  local q = tonumber(tokens[2])
  local x = tonumber(tokens[3])
  local y = tonumber(tokens[4])
  local z = tonumber(tokens[5])
  local m = { }
  for i = 1, 9 do
    m[i] = tonumber(tokens[5 + i])
  end
  return q, x, y, z, m, tokens[15]
end

-- Build the head of the argument list common to every Type 1
-- emission: the sub-part reference, colour, and translation.

function build_type1_head(fname, q, x, y, z)
  local head = { }
  table.insert(head, mangle_ref(fname))
  insert_nums(head, q, x, y, z)
  return head
end

-- Emit a twist call if the matrix has the twist shape, or a
-- ref call with all nine matrix coefficients otherwise.

function emit_twist_or_ref(m, args)
  if is_twist(m) then
    insert_nums(args, m[1], m[3])
    emit_call("twist", args)
    return
  end
  insert_all(args, m, 1, 9)
  emit_call("ref", args)
end

-- Emit a Type 1 line: dispatch to placeN/E/S/W if the matrix
-- matches a compass pattern, otherwise hand off to the
-- twist-or-ref tail.

function handle_type1(tokens)
  local q, x, y, z, m, fname = parse_type1(tokens)
  local args = build_type1_head(fname, q, x, y, z)
  local place = match_place(m)
  if place then
    emit_call(place, args)
    return
  end
  emit_twist_or_ref(m, args)
end

-- Types 2 through 5.

-- Shared logic for Types 2 and 5: colour EDGE_COLOUR uses the
-- unsigned DSL name, any other colour uses the q-variant.

function emit_colour_variant(tokens, last, name_24, name_q)
  local q = tonumber(tokens[2])
  local coords = nums_from_tokens(tokens, 3, last)
  if q == EDGE_COLOUR then
    emit_call(name_24, coords)
  else
    table.insert(coords, 1, fmt_num(q))
    emit_call(name_q, coords)
  end
end

-- Factory for Types 3 and 4, which take a colour plus a fixed
-- number of coordinates and emit a single call.

function make_poly_handler(last, name)
  return function(tokens)
    emit_call(name, nums_from_tokens(tokens, 2, last))
  end
end

function handle_type2(tokens)
  emit_colour_variant(tokens, 8, "edge", "line")
end

function handle_type5(tokens)
  emit_colour_variant(tokens, 14, "outline", "color_outline")
end

TYPE_HANDLER = {
  ["1"] = handle_type1,
  ["2"] = handle_type2,
  ["3"] = make_poly_handler(11, "tri"),
  ["4"] = make_poly_handler(14, "quad"),
  ["5"] = handle_type5
}

-- Line dispatch.

-- Handle a Type 0 line: strip the leading "0" token and pass
-- the rest to handle_type0 as raw text.

function process_zero(trimmed)
  local rest = trimmed:sub(2):match("^%s*(.-)$")
  handle_type0(rest)
end

-- Dispatch a non-blank trimmed line by its first token.

function dispatch_line(trimmed)
  local first = trimmed:match("^(%S+)")
  if first == "0" then
    process_zero(trimmed)
    return
  end
  local handler = TYPE_HANDLER[first]
  if handler then
    handler(tokenize(trimmed))
  end
end

-- Process one input line: blank lines collapse via emit_blank,
-- non-blank lines go through dispatch_line.

function process_line(line)
  local trimmed = line:match("^%s*(.-)%s*$")
  if trimmed == "" then
    emit_blank()
  else
    dispatch_line(trimmed)
  end
end
