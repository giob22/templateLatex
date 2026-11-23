-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 giob22. Vedi il file LICENSE.
-- run-tests.lua: compila i documenti di prova e controlla il log di asicmargins.
-- Uso (dalla cartella test/):   texlua run-tests.lua [nome-test ...]
-- I file vengono compilati in test/build/; se pdftoppm è disponibile,
-- ogni pagina è rasterizzata in test/build/<nome>-<n>.png per il controllo visivo.

local lfs = require("lfs")

local dir = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
local root = dir .. "/.."
local build = dir .. "/build"

local function copy(src, dst)
  local f = assert(io.open(src, "rb")); local data = f:read("a"); f:close()
  local g = assert(io.open(dst, "wb")); g:write(data); g:close()
end
local function slurp(path)
  local f = io.open(path, "rb"); if not f then return nil end
  local data = f:read("a"); f:close(); return data
end

-- righe "asicmargins: pagina N [(pari, specchiata)|(dispari)]; scala S; zone di rispetto Z"
local function pages(log)
  local t = {}
  for n, kind, s, z in log:gmatch("asicmargins: pagina (%d+)([^;\n]*); scala ([%d%.]+); zone di rispetto (%d+)") do
    t[#t+1] = { n = tonumber(n), mirror = kind:find("specchiata") ~= nil, scale = tonumber(s), keep = tonumber(z) }
  end
  return t
end

-- riga "asicmargins: seed N (fissato)" oppure "asicmargins: seed N (casuale; ...)"
local function seedof(log)
  local v, k = log:match("asicmargins: seed (%d+) %((%a+)")
  return v and { value = tonumber(v), kind = k } or nil
end

local function between(x, a, b) return x >= a and x <= b end

-- Il motore comune sta in ../margincore; il motivo di questo pacchetto in ../asicmargins.lua.
local core = dofile(root .. "/../margincore/margincore.lua")
local function newinstance()
  return core.new{ name = "asicmargins", motif = core.loadmotif(root .. "/asicmargins.lua") }
end

-- Prove sul generatore, senza TeX: determinismo con seed fisso, casualità del default.
local function unit_seed()
  local function load() return newinstance() end
  local function wait(s) local t = os.clock(); while os.clock() - t < s do end end
  local A = load(); wait(.03); local B = load()
  if A.opts.seed == B.opts.seed then return "due caricamenti danno lo stesso seme di default" end
  for _, M in ipairs({ A, B }) do
    if not M.seed_random then return "il seme di default non è marcato casuale" end
    if not between(M.opts.seed, 1, 999999999) then return "seme casuale fuori intervallo: " .. M.opts.seed end
  end
  local function page(M, pg) return (M.build(pg, 595.276, 841.89, 102, 100, 493, 740, {})) end
  A.set("seed", "7")
  if A.seed_random or A.opts.seed ~= 7 then return "seed=7 non viene applicato" end
  local p1 = page(A, 1)
  if page(A, 1) ~= p1 then return "stesso seme e stessa pagina: disegni diversi" end
  if page(A, 2) == p1 then return "pagine diverse con lo stesso disegno" end
  A.set("seed", "8")
  if page(A, 1) == p1 then return "semi diversi con lo stesso disegno" end
  A.set("seed", "random")
  if not A.seed_random then return "seed=random non riattiva il seme casuale" end
  local seen, n = {}, 0
  for _ = 1, 40 do
    A.set("seed", "random")
    local s = page(A, 1)
    if not seen[s] then seen[s] = true; n = n + 1 end
  end
  if n < 40 then return "40 semi casuali hanno dato solo " .. n .. " disegni distinti" end
end

-- Prove sulle zone (where), senza TeX: ogni rettangolo disegnato ha il centro in una zona attiva
-- e mai nell'area del testo; i nomi sono posizioni fisiche anche sulle pagine pari (specchiate).
local function unit_where()
  local M = newinstance()
  local W, H = 595.276, 841.89
  M.set("seed", "7")
  local function build(where, mirror)
    M.set("where", where)
    return M.build(1, W, H, 102, 100, 493, 740, { mirror = mirror })
  end
  local function centers(s)
    local t = {}
    for x, y, w, h in s:gmatch("([%-%d%.]+) ([%-%d%.]+) ([%-%d%.]+) ([%-%d%.]+) re") do
      t[#t+1] = { tonumber(x) + tonumber(w) / 2, H - (tonumber(y) + tonumber(h) / 2) }
    end
    return t
  end
  if build("all") ~= build("top, bottom ,left+right") then return "where=all diverso dall'elenco completo dei lati" end
  local modes = { "top", "bottom", "left", "right", "sides", "topbottom", "topleft", "topright",
                  "bottomleft", "bottomright", "corners", "topleft,bottomright", "top,topleft" }
  for _, w in ipairs(modes) do
    local s, st = build(w)
    local c = centers(s)
    if #c < 100 then return "where=" .. w .. ": solo " .. #c .. " elementi" end
    for _, p in ipairs(c) do
      local ok = false
      for _, r in ipairs(st.allowed) do
        if p[1] >= r[1] and p[1] <= r[3] and p[2] >= r[2] and p[2] <= r[4] then ok = true end
      end
      local t = st.txt
      if p[1] > t.x0 and p[1] < t.x1 and p[2] > t.y0 and p[2] < t.y1 then ok = false end
      if not ok then return string.format("where=%s: elemento fuori zona (%.0f, %.0f)", w, p[1], p[2]) end
    end
  end
  -- gli angoli restano negli angoli, anche con la pagina pari specchiata (riferimento della dispari)
  for _, mirror in ipairs({ false, true }) do
    local s = build("topleft", mirror)
    for _, p in ipairs(centers(s)) do
      local xo = mirror and (W - p[1]) or p[1]   -- ascissa fisica dopo lo specchio
      if xo > .42 * W + 1 or p[2] > .30 * H + 1 then
        return string.format("topleft%s: elemento a (%.0f, %.0f)", mirror and " (pari)" or "", xo, p[2])
      end
    end
  end
  local say = texio.write_nl
  texio.write_nl = function() end   -- l'avviso per il valore non valido non serve qui
  M.set("where", "pippo")
  local _, st = M.build(1, W, H, 102, 100, 493, 740, {})
  texio.write_nl = say
  if st.allowed then return "un valore non valido non ricade su all" end
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
}

local only = {}
for i = 1, #arg do only[arg[i]] = true end

lfs.mkdir(build)
copy(root .. "/asicmargins.sty", build .. "/asicmargins.sty")
copy(root .. "/asicmargins.lua", build .. "/asicmargins.lua")
copy(root .. "/../margincore/margincore.sty", build .. "/margincore.sty")
copy(root .. "/../margincore/margincore.lua", build .. "/margincore.lua")
local start = lfs.currentdir()
local havepng = os.execute("pdftoppm -v > pdftoppm.txt 2>&1")
os.remove("pdftoppm.txt")

local failed = 0
if next(only) == nil or only["unit-seed"] then
  local err = unit_seed()
  if err then failed = failed + 1 end
  print(string.format("%-14s %s", "unit-seed", err and ("FALLITO: " .. err) or "ok"))
end
if next(only) == nil or only["unit-where"] then
  local err = unit_where()
  if err then failed = failed + 1 end
  print(string.format("%-14s %s", "unit-where", err and ("FALLITO: " .. err) or "ok"))
end
for _, T in ipairs(tests) do
  if next(only) == nil or only[T.name] then
    copy(dir .. "/" .. T.name .. ".tex", build .. "/" .. T.name .. ".tex")
    lfs.chdir(build)
    local ok, log, seeds = true, "", {}
    for run = 1, T.runs or 1 do
      ok = os.execute("lualatex -interaction=nonstopmode -halt-on-error " .. T.name .. ".tex > " .. T.name .. ".stdout 2>&1")
      log = slurp(T.name .. ".log") or ""
      seeds[run] = seedof(log)
      if not ok or log:find("\n! ") then break end
    end
    local P = pages(log)
    local err
    if not ok or log:find("\n! ") then
      err = "errore di compilazione (vedi build/" .. T.name .. ".log)"
    elseif #P == 0 then
      err = "nessuna riga asicmargins nel log"
    else
      err = T.check(P, seeds)
    end
    if not err and havepng then
      os.execute("pdftoppm -r 50 -png " .. T.name .. ".pdf " .. T.name)
    end
    lfs.chdir(start)
    if err then failed = failed + 1 end
    print(string.format("%-14s %s  (%d pagine, scala %s)", T.name, err and ("FALLITO: " .. err) or "ok",
      #P, P[1] and string.format("%.3f", P[1].scale) or "-"))
  end
end
print(failed == 0 and "Tutti i test superati." or (failed .. " test falliti."))
os.exit(failed == 0 and 0 or 1)
