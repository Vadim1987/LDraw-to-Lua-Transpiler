-- LDraw to Lua transpiler.

-- Converts one LDraw file (.ldr/.dat/.mpd) into a

-- Lua chunk of top-level DSL calls. 

-- Matrix comparison tolerance per spec.

TOL = 0.0005

-- Output buffer shared by all emit helpers.

local insert = table.insert
out = { }

-- Format a number as an integer if integer-valued,

-- otherwise as a compact decimal without trailing

-- zeros.

function fmt_num(n)
  if n == math.floor(n) then
    return tostring(math.floor(n))
  end
  local s = string.format("%.4f", n)
  s = s:gsub("0+$", ""):gsub("%.$", "")
  return s
end

-- Split a line into whitespace-delimited tokens.

function tokenize(line)
  local t = { }
  for word in line:gmatch("%S+") do
    insert(t, word)
  end
  return t
end

-- Strip prefix ending with "\" from an LDraw file

-- reference and rewrite "name.ext" as "ext_name".

function mangle_ref(name)
  local bs = name:find("\\[^\\]*$")
  if bs then
    name = name:sub(bs + 1)
  end
  local base, ext = name:match("^(.+)%.([^.]+)$")
  return ext:lower() .. "_" .. base
end

-- Approximate equality within TOL.

function approx_eq(a, b)
  return math.abs(a - b) < TOL
end

-- Append a blank line, collapsing consecutive blanks.

function emit_blank()
  if out[#out] == "" then
    return 
  end
  insert(out, "")
end

-- Check whether adding word to current line keeps

-- it within the 64-column limit for its prefix.

function fits_comment(prefix, current, word)
  if current == "" then
    return #(prefix .. word) <= 64
  end
  return #(prefix .. current .. " " .. word) <= 64
end

-- Append a word to a comment line, adding a space

-- separator if the line is not empty.

function append_word(line, word)
  if line == "" then
    return word
  end
  return line .. " " .. word
end

-- Wrap a long comment at word boundaries. 

function emit_wrapped_comment(rest)
  local prefix, line = "-- ", ""
  for word in rest:gmatch("%S+") do
    if fits_comment(prefix, line, word) then
      line = append_word(line, word)
    else
      insert(out, prefix .. line)
      prefix, line = "  -- ", word
    end
  end
  if line ~= "" then
    insert(out, prefix .. line)
  end
end

-- Append a comment line preserving original text

-- verbatim when it fits; otherwise word-wrap it.

function emit_comment(rest)
  if rest == "" then
    insert(out, "--")
    return 
  end
  if #rest + 3 <= 64 then
    insert(out, "-- " .. rest)
  else
    emit_wrapped_comment(rest)
  end
end

-- Try to emit a function call on a single line;

-- return true on success, false if it would exceed

-- the 64-column limit.

function try_inline_call(name, args)
  local inline = name .. "(" .. table.concat(args, ", ") .. ")"
  if 64 < #inline then
    return false
  end
  insert(out, inline)
  return true
end

-- Emit a function call spread across multiple lines,

-- one argument per line with trailing commas.

function emit_multi_call(name, args)
  insert(out, name .. "(")
  for i = 1, #args do
    local tail = ","
    if i == #args then
      tail = ""
    end
    insert(out, "  " .. args[i] .. tail)
  end
  insert(out, ")")
end

-- Emit a function call, inline if it fits, multiline

-- (one arg per line) otherwise.

function emit_call(name, args)
  if not try_inline_call(name, args) then
    emit_multi_call(name, args)
  end
end

-- Handlers for META commands that carry text.

function emit_write(msg)
  emit_call("WRITE", { string.format("%q", msg) })
end

function emit_print(msg)
  emit_call("PRINT", { string.format("%q", msg) })
end

-- Handlers for META commands with no arguments.

function emit_step()
  emit_call("STEP", { })
end

function emit_clear()
  emit_call("CLEAR", { })
end

function emit_pause()
  emit_call("PAUSE", { })
end

function emit_save()
  emit_call("SAVE", { })
end

-- Type 0 patterns as two parallel tables to avoid
-- nested table literals the autoformatter expands.
-- Each index i pairs a regex with its handler.

META_PATTERN_REGEX = {
  "^STEP%s*$",
  "^CLEAR%s*$",
  "^PAUSE%s*$",
  "^SAVE%s*$",
  "^WRITE%s+(.*)$",
  "^PRINT%s+(.*)$"
}

META_PATTERN_HANDLER = {
  emit_step,
  emit_clear,
  emit_pause,
  emit_save,
  emit_write,
  emit_print
}

-- Handle a Type 0 line given the content after
-- the leading "0 " token.

function handle_type0(rest)
  for i = 1, #META_PATTERN_REGEX do
    local cap = rest:match(META_PATTERN_REGEX[i])
    if cap then
      META_PATTERN_HANDLER[i](cap)
      return
    end
  end
  emit_comment(rest)
end

-- Check whether a matrix matches the placeN shape.

function is_place_n(m)
  return approx_eq(m[1], 1) and approx_eq(m[2], 0)
       and approx_eq(m[3], 0)
       and approx_eq(m[4], 0)
       and approx_eq(m[5], 1)
       and approx_eq(m[6], 0)
       and approx_eq(m[7], 0)
       and approx_eq(m[8], 0)
       and approx_eq(m[9], 1)
end

function is_place_e(m)
  return approx_eq(m[1], 0) and approx_eq(m[2], 0)
       and approx_eq(m[3], 1)
       and approx_eq(m[4], 0)
       and approx_eq(m[5], 1)
       and approx_eq(m[6], 0)
       and approx_eq(m[7], -1)
       and approx_eq(m[8], 0)
       and approx_eq(m[9], 0)
end

function is_place_s(m)
  return approx_eq(m[1], -1) and approx_eq(m[2], 0)
       and approx_eq(m[3], 0)
       and approx_eq(m[4], 0)
       and approx_eq(m[5], 1)
       and approx_eq(m[6], 0)
       and approx_eq(m[7], 0)
       and approx_eq(m[8], 0)
       and approx_eq(m[9], -1)
end

function is_place_w(m)
  return approx_eq(m[1], 0) and approx_eq(m[2], 0)
       and approx_eq(m[3], -1)
       and approx_eq(m[4], 0)
       and approx_eq(m[5], 1)
       and approx_eq(m[6], 0)
       and approx_eq(m[7], 1)
       and approx_eq(m[8], 0)
       and approx_eq(m[9], 0)
end

-- Twist is [a,0,c; 0,1,0; -c,0,a] shape.

function is_twist(m)
  return approx_eq(m[2], 0) and approx_eq(m[4], 0)
       and approx_eq(m[5], 1)
       and approx_eq(m[6], 0)
       and approx_eq(m[8], 0)
       and approx_eq(m[1], m[9])
       and approx_eq(m[3], -m[7])
end

-- Parse tokens 2..15 of a Type 1 line as numbers.

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

-- placeN/E/S/W dispatch as two parallel tables, same
-- reason as META_PATTERNS: avoid nested literals.

PLACE_CHECK = {
  is_place_n,
  is_place_e,
  is_place_s,
  is_place_w
}

PLACE_NAME = {
  "placeN",
  "placeE",
  "placeS",
  "placeW"
}

-- Try each place* predicate; emit the matching
-- DSL call and return true, or false if none fit.

function try_emit_place(m, pos)
  for i = 1, #PLACE_CHECK do
    if PLACE_CHECK[i](m) then
      emit_call(PLACE_NAME[i], pos)
      return true
    end
  end
  return false
end

-- Handle a non-place Type 1 line: emit a twist call

-- if the matrix has the twist shape, otherwise fall

-- through to a full ref call with all 9 matrix

-- coefficients.

function emit_non_place(m, pos)
  if is_twist(m) then
    insert(pos, fmt_num(m[1]))
    insert(pos, fmt_num(m[3]))
    emit_call("twist", pos)
    return 
  end
  for i = 1, 9 do
    insert(pos, fmt_num(m[i]))
  end
  emit_call("ref", pos)
end

-- Dispatch a Type 1 line to the matching DSL call

-- based on the transformation matrix shape.

function handle_type1(tokens)
  local q, x, y, z, m, fname = parse_type1(tokens)
  local pos = { }
  insert(pos, mangle_ref(fname))
  insert(pos, fmt_num(q))
  insert(pos, fmt_num(x))
  insert(pos, fmt_num(y))
  insert(pos, fmt_num(z))
  if try_emit_place(m, pos) then
    return 
  end
  emit_non_place(m, pos)
end

-- Convert tokens[from..to] to formatted num strings.

function nums_from_tokens(tokens, from, to)
  local nums = { }
  for i = from, to do
    insert(nums, fmt_num(tonumber(tokens[i])))
  end
  return nums
end

-- Shared logic for Types 2 and 5.

function emit_colour_variant(tokens, n, name_24, name_q)
  local q = tonumber(tokens[2])
  local coords = nums_from_tokens(tokens, 3, n)
  if q == 24 then
    emit_call(name_24, coords)
  else
    insert(coords, 1, fmt_num(q))
    emit_call(name_q, coords)
  end
end

-- Type 2: line (6 coords after colour).

function handle_type2(tokens)
  emit_colour_variant(tokens, 8, "edge", "line")
end

-- Type 3: triangle.

function handle_type3(tokens)
  local args = nums_from_tokens(tokens, 2, 11)
  emit_call("tri", args)
end

-- Type 4: quadrilateral.

function handle_type4(tokens)
  local args = nums_from_tokens(tokens, 2, 14)
  emit_call("quad", args)
end

-- Type 5: optional line (12 coords after colour).

function handle_type5(tokens)
  emit_colour_variant(tokens, 14, "outline", "color_outline")
end

-- Dispatch a tokenised line to the right handler.

TYPE_HANDLERS = {
  ["1"] = handle_type1,
  ["2"] = handle_type2,
  ["3"] = handle_type3,
  ["4"] = handle_type4,
  ["5"] = handle_type5
}

-- Handle a Type 0 line: strip the leading "0" token

-- and pass the rest to handle_type0 as raw text.

function process_zero(trimmed)
  local rest = trimmed:sub(2):match("^%s*(.-)$")
  handle_type0(rest)
end

-- Dispatch a non-blank trimmed line by its first

-- token: Type 0 gets special handling, Types 1-5

-- go through the TYPE_HANDLERS table.

function dispatch_line(trimmed)
  local first = trimmed:match("^(%S+)")
  if first == "0" then
    process_zero(trimmed)
    return 
  end
  local handler = TYPE_HANDLERS[first]
  if handler then
    handler(tokenize(trimmed))
  end
end

-- Process one input line: blank lines collapse via

-- emit_blank, non-blank lines go to dispatch_line.

function process_line(line)
  local trimmed = line:match("^%s*(.-)%s*$")
  if trimmed == "" then
    emit_blank()
  else
    dispatch_line(trimmed)
  end
end

-- Read the whole input file as a single string.

function read_file(path)
  local f = io.open(path, "r")
  if not f then
    error("cannot open: " .. path)
  end
  local s = f:read("*all")
  f:close()
  return s
end

-- Write the output buffer joined by newlines.

function write_file(path)
  local f = io.open(path, "w")
  if not f then
    error("cannot write: " .. path)
  end
  f:write(table.concat(out, "\n"))
  f:write("\n")
  f:close()
end

-- Main: read file, split into lines handling both

-- CRLF and LF line endings, process each line, and

-- write the result.

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
