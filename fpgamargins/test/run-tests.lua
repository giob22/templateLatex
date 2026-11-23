-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 giob22. Vedi il file LICENSE.
-- run-tests.lua di fpgamargins.   Uso (dalla cartella test/):   texlua run-tests.lua [nome ...]
-- Compila in test/build/ i documenti test-*.tex e fa le prove sul generatore senza TeX.

package.path = (arg[0]:match("^(.*)[/\\][^/\\]*$") or ".") .. "/../../tools/?.lua;" .. package.path
local lib = require("testlib")
local dir = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
local root = dir .. "/.."
local between = lib.between

local core = dofile(root .. "/../margincore/margincore.lua")
local function newinstance()
  return core.new{ name = "fpgamargins", motif = core.loadmotif(root .. "/fpgamargins.lua") }
end

local W, H = 595.276, 841.89
-- punti {x, y} (y verso il basso): vertici dei tratti m / l e centri dei rettangoli (blocchi)
local function points(s)
  local t = {}
  for x, y in s:gmatch("([%-%d%.]+) ([%-%d%.]+) [ml]") do t[#t+1] = { tonumber(x), H - tonumber(y) } end
  for x, y, w, h in s:gmatch("([%-%d%.]+) ([%-%d%.]+) ([%-%d%.]+) ([%-%d%.]+) re") do
    t[#t+1] = { tonumber(x) + tonumber(w) / 2, H - (tonumber(y) + tonumber(h) / 2) }
  end
  return t
end

-- frazione dei punti di B che coincidono con un punto di A (stesse coordinate)
local function overlap(A, B)
  local seen = {}
  for _, p in ipairs(A) do seen[string.format("%.1f:%.1f", p[1], p[2])] = true end
  local hit = 0
  for _, p in ipairs(B) do
    if seen[string.format("%.1f:%.1f", p[1], p[2])] then hit = hit + 1 end
  end
  return hit / math.max(1, #B)
end

local function unit_fpga()
  local M = newinstance()
  M.set("seed", "7")
  local function str(pg, twoside)
    local info = twoside and { twoside = true, mirror = pg % 2 == 0 } or {}
    return (M.build(pg, W, H, 102, 100, 493, 740, info))
  end
  local base = #points(str(1))
  if base < 1500 then return "poche piste: " .. base .. " punti" end
  M.set("blocks", "false"); local noblocks = str(1); M.set("blocks", "true")
  if select(2, str(1):gsub(" re", "")) <= select(2, noblocks:gsub(" re", "")) then return "blocks=false non toglie i blocchi" end
  M.set("nets", "false"); local nonets = #str(1); M.set("nets", "true")
  if nonets >= #str(1) then return "nets=false non toglie le connessioni" end
  M.set("pips", "false"); local nopips = #str(1); M.set("pips", "true")
  if nopips >= #str(1) then return "pips=false non toglie i punti" end
  -- la coppia di pagine affiancate (2|3) condivide la matrice: i vertici delle piste coincidono
  local same = overlap(points(str(2, true)), points(str(3, true)))
  if same < .5 then return string.format("pagine 2|3 poco simili: %.2f", same) end
end

local tests = {
  { name = "test-a4", check = function(P, seeds)
      if not seeds[1] or seeds[1].value ~= 7 or seeds[1].kind ~= "fissato" then
        return "seed=7 non compare come fissato nel log"
      end
      for _, p in ipairs(P) do
        if not between(p.scale, .99, 1.01) then return "scala " .. p.scale .. " invece di ~1" end
        if p.mirror then return "pagina specchiata in solo fronte" end
      end
    end },
  { name = "test-a5", check = function(P)
      for _, p in ipairs(P) do
        if not between(p.scale, .5, .75) then return "scala A5 fuori intervallo: " .. p.scale end
      end
    end },
  { name = "test-letter", check = function(P)
      for _, p in ipairs(P) do
        if not between(p.scale, .75, .92) then return "scala letter fuori intervallo: " .. p.scale end
      end
    end },
  { name = "test-twoside", check = function(P)
      if #P < 4 then return "servono almeno 4 pagine, trovate " .. #P end
      for _, p in ipairs(P) do
        if p.mirror ~= (p.n % 2 == 0) then return "pagina " .. p.n .. ": specchiatura errata" end
      end
    end },
  { name = "test-seed", runs = 2, check = function(P, seeds)
      for i = 1, 2 do
        if not seeds[i] or seeds[i].kind ~= "casuale" then return "compilazione " .. i .. ": seme non casuale nel log" end
      end
      if seeds[1].value == seeds[2].value then return "due compilazioni con lo stesso seme: " .. seeds[1].value end
    end },
  { name = "test-where", check = function(P)
      if #P ~= 14 then return "attese 14 pagine, trovate " .. #P end
      for _, p in ipairs(P) do
        if p.mirror ~= (p.n % 2 == 0) then return "pagina " .. p.n .. ": specchiatura errata" end
      end
    end },
  { name = "test-halo", check = function(P)
      for _, p in ipairs(P) do
        if p.keep < 1 then return "pagina " .. p.n .. ": nessuna zona di rispetto (numero nel margine)" end
      end
    end },
  { name = "test-opzioni", check = function(P)
      if #P ~= 10 then return "attese 10 pagine, trovate " .. #P end
    end },
}

lib.run{
  root = root, pkg = "fpgamargins", args = arg, tests = tests,
  units = {
    { "unit-seed", function() return lib.unit_seed(newinstance) end },
    { "unit-where", function() return lib.unit_where(newinstance, points, { minpoints = 200, tol = 6 }) end },
    { "unit-fpga", unit_fpga },
  },
}
