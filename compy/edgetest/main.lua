-- Edgetest entry point.

TOL = 0.0005

require "linalg"
require "ldraw_colors"
require "ldraw"

D = 1000
CENTER_X = 512
CENTER_Y = 300

function perspective(x, y, z)
  local dz = D / z
  return CENTER_X + x * dz, CENTER_Y + y * dz
end

project = perspective

DAT_FILES = {
  "dat_3001",
  "dat_3001s01",
  "dat_3003",
  "dat_3003s01",
  "dat_3003s02",
  "dat_4_4cyli",
  "dat_4_4disc",
  "dat_4_4edge",
  "dat_4_4ring3",
  "dat_box3u2p",
  "dat_box5",
  "dat_stud",
  "dat_stud4",
  "dat_stug_2x2"
}

function load_chunks()
  for i = 1, #DAT_FILES do
    local name = DAT_FILES[i]
    _G[name] = loadfile(name .. ".lua")
  end
end

function setup_view()
  VIEW_M = Mat:new({
    Vec.d3(0.8779, 0.1685, -0.4489),
    Vec.d3(0, 0.9363, 0.3511),
    Vec.d3(0.4789, -0.3082, 0.8221)
  })
  VIEW_T = Vec.d3(0, 70, 850)
end

load_chunks()
ldr_pyramid = loadfile("ldr_pyramid.lua")
setup_view()
ldr_pyramid()
