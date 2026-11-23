-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 giob22. Vedi il file LICENSE.
-- run-tests.lua di topomargins.   Uso (dalla cartella test/):   texlua run-tests.lua [nome ...]
-- Compila in test/build/ i documenti test-*.tex e fa le prove sul generatore senza TeX.

package.path = (arg[0]:match("^(.*)[/\\][^/\\]*$") or ".") .. "/../../tools/?.lua;" .. package.path
local lib = require("testlib")
local dir = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
local root = dir .. "/.."
local between = lib.between

local core = dofile(root .. "/../margincore/margincore.lua")
local function newinstance()
  return core.new{ name = "topomargins", motif = core.loadmotif(root .. "/topomargins.lua") }
end

local W, H = 595.276, 841.89
-- punti {x, y} (y verso il basso) dei tratti m / l di una stringa di operatori PDF
local function points(s)
  local t = {}
  for x, y in s:gmatch("([%-%d%.]+) ([%-%d%.]+) [ml]") do t[#t+1] = { tonumber(x), H - tonumber(y) } end
  return t
end

-- frazione dei punti di B che coincidono con un punto di A (stesse coordinate, al centesimo di bp).
-- Con lo stesso rilievo i vertici delle curve sono identici; con rilievi diversi non coincidono.
local function overlap(A, B)
  local seen = {}
  for _, p in ipairs(A) do seen[string.format("%.2f:%.2f", p[1], p[2])] = true end
  local hit = 0
  for _, p in ipairs(B) do
    if seen[string.format("%.2f:%.2f", p[1], p[2])] then hit = hit + 1 end
  end
  return hit / math.max(1, #B)
end

local function unit_topo()
  local M = newinstance()
  M.set("seed", "7")
  local function pts(pg, twoside)
    local info = twoside and { twoside = true, mirror = pg % 2 == 0 } or {}
    return points((M.build(pg, W, H, 102, 100, 493, 740, info)))
  end
  local base = #pts(1)
  if base < 1500 then return "poche curve: " .. base .. " punti" end
  M.set("levels", "20"); local few = #pts(1)
  M.set("levels", "60"); local many = #pts(1)
  M.set("levels", "40")
  if not (few < base and base < many) then return "levels non cambia il numero di curve" end
  M.set("peaks", "false"); local nopeaks = #pts(1); M.set("peaks", "true")
  if nopeaks > base then return "peaks=false aggiunge punti" end
  -- la coppia di pagine affiancate (2|3) condivide il rilievo; coppie diverse (3, 5) no
  local p2, p3, p5 = pts(2, true), pts(3, true), pts(5, true)
  local same, other = overlap(p2, p3), overlap(p3, p5)
  if same < .5 then return string.format("pagine 2|3 poco simili: %.2f", same) end
  if other > .05 then return string.format("pagine 3 e 5 troppo simili: %.2f", other) end
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
  -- senza seed=: due compilazioni di fila devono scegliere semi casuali diversi
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
      if #P ~= 12 then return "attese 12 pagine, trovate " .. #P end
    end },
}

lib.run{
  root = root, pkg = "topomargins", args = arg, tests = tests,
  units = {
    { "unit-seed", function() return lib.unit_seed(newinstance) end },
    { "unit-where", function() return lib.unit_where(newinstance, points, { minpoints = 300, tol = 3 }) end },
    { "unit-topo", unit_topo },
  },
}
