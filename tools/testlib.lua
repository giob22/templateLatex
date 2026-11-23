-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 giob22. Vedi il file LICENSE.
-- testlib.lua: pezzi comuni dei test dei pacchetti di margini.
--
-- Uso, da <pacchetto>/test/run-tests.lua:
--   package.path = dir .. "/../../tools/?.lua;" .. package.path
--   local lib = require("testlib")
--   lib.run{ root = <cartella del pacchetto>, pkg = "<nome>", args = arg, tests = {...}, units = {...} }
--
-- tests: elenco di { name = "test-xxx", runs = 1, check = function(P, seeds) ... end }
--   compila test/<name>.tex in test/build/ (con il pacchetto e margincore), legge dal .log una
--   riga per pagina e una riga per il seme, e chiama check(P, seeds): restituisce un messaggio
--   d'errore oppure nil. Con runs > 1 compila più volte e seeds ha un elemento per volta.
-- units: elenco di { "nome", function() ... end } che girano senza TeX e restituiscono
--   un messaggio d'errore oppure nil.
-- Se c'è pdftoppm, ogni pagina compilata viene rasterizzata in test/build/<name>-<n>.png.

local lfs = require("lfs")
local lib = {}

function lib.copy(src, dst)
  local f = assert(io.open(src, "rb")); local data = f:read("a"); f:close()
  local g = assert(io.open(dst, "wb")); g:write(data); g:close()
end

function lib.slurp(path)
  local f = io.open(path, "rb"); if not f then return nil end
  local data = f:read("a"); f:close(); return data
end

function lib.between(x, a, b) return x >= a and x <= b end

-- righe "<pkg>: pagina N [(pari, specchiata)|(dispari)]; scala S; zone di rispetto Z"
function lib.pages(log, pkg)
  local t = {}
  local pat = pkg .. ": pagina (%d+)([^;\n]*); scala ([%d%.]+); zone di rispetto (%d+)"
  for n, kind, s, z in log:gmatch(pat) do
    t[#t+1] = { n = tonumber(n), mirror = kind:find("specchiata") ~= nil, scale = tonumber(s), keep = tonumber(z) }
  end
  return t
end

-- riga "<pkg>: seed N (fissato)" oppure "<pkg>: seed N (casuale; ...)"
function lib.seedof(log, pkg)
  local v, k = log:match(pkg .. ": seed (%d+) %((%a+)")
  return v and { value = tonumber(v), kind = k } or nil
end

-- Prove sul generatore, senza TeX: determinismo con seed fisso, casualità del default.
-- newinstance(): crea un'istanza nuova del pacchetto (core.new{...}).
function lib.unit_seed(newinstance)
  local between = lib.between
  local function wait(s) local t = os.clock(); while os.clock() - t < s do end end
  local A = newinstance(); wait(.03); local B = newinstance()
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

-- Prove sulle zone (where), senza TeX. points(s) estrae da una stringa di operatori PDF i punti
-- {x, y} che il motivo ha disegnato (y verso il basso). Ogni punto deve stare in una zona attiva
-- e fuori dall'area del testo; i nomi sono posizioni fisiche anche sulle pagine pari (specchiate).
-- opts: minpoints (punti attesi per ogni modalità), tol (tolleranza in bp).
function lib.unit_where(newinstance, points, opts)
  opts = opts or {}
  local minpoints, tol = opts.minpoints or 100, opts.tol or 0
  local M = newinstance()
  local W, H = 595.276, 841.89
  M.set("seed", "7")
  local function build(where, mirror)
    M.set("where", where)
    return M.build(1, W, H, 102, 100, 493, 740, { mirror = mirror })
  end
  if build("all") ~= build("top, bottom ,left+right") then return "where=all diverso dall'elenco completo dei lati" end
  local modes = { "top", "bottom", "left", "right", "sides", "topbottom", "topleft", "topright",
                  "bottomleft", "bottomright", "corners", "topleft,bottomright", "top,topleft" }
  for _, w in ipairs(modes) do
    local s, st = build(w)
    local c = points(s)
    if #c < minpoints then return "where=" .. w .. ": solo " .. #c .. " punti" end
    for _, p in ipairs(c) do
      local ok = false
      for _, r in ipairs(st.allowed) do
        if p[1] >= r[1] - tol and p[1] <= r[3] + tol and p[2] >= r[2] - tol and p[2] <= r[4] + tol then ok = true end
      end
      local t = st.txt
      if p[1] > t.x0 + tol and p[1] < t.x1 - tol and p[2] > t.y0 + tol and p[2] < t.y1 - tol then ok = false end
      if not ok then return string.format("where=%s: punto fuori zona (%.0f, %.0f)", w, p[1], p[2]) end
    end
  end
  -- gli angoli restano negli angoli, anche con la pagina pari specchiata (riferimento della dispari)
  for _, mirror in ipairs({ false, true }) do
    local s = build("topleft", mirror)
    for _, p in ipairs(points(s)) do
      local xo = mirror and (W - p[1]) or p[1]   -- ascissa fisica dopo lo specchio
      if xo > .42 * W + 1 + tol or p[2] > .30 * H + 1 + tol then
        return string.format("topleft%s: punto a (%.0f, %.0f)", mirror and " (pari)" or "", xo, p[2])
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

-- Compila ed esegue i test. Vedi l'intestazione per spec.
function lib.run(spec)
  local root, pkg = spec.root, spec.pkg
  local dir, build = root .. "/test", root .. "/test/build"
  local only = {}
  for i = 1, #(spec.args or {}) do only[spec.args[i]] = true end
  local function wanted(name) return next(only) == nil or only[name] end

  lfs.mkdir(build)
  for _, ext in ipairs({ "sty", "lua" }) do
    lib.copy(root .. "/" .. pkg .. "." .. ext, build .. "/" .. pkg .. "." .. ext)
    lib.copy(root .. "/../margincore/margincore." .. ext, build .. "/margincore." .. ext)
  end
  local start = lfs.currentdir()
  local havepng = os.execute("pdftoppm -v > pdftoppm.txt 2>&1")
  os.remove("pdftoppm.txt")

  local failed = 0
  for _, u in ipairs(spec.units or {}) do
    if wanted(u[1]) then
      local err = u[2]()
      if err then failed = failed + 1 end
      print(string.format("%-14s %s", u[1], err and ("FALLITO: " .. err) or "ok"))
    end
  end
  for _, T in ipairs(spec.tests or {}) do
    if wanted(T.name) then
      lib.copy(dir .. "/" .. T.name .. ".tex", build .. "/" .. T.name .. ".tex")
      lfs.chdir(build)
      local ok, log, seeds = true, "", {}
      for run = 1, T.runs or 1 do
        ok = os.execute("lualatex -interaction=nonstopmode -halt-on-error " .. T.name .. ".tex > " .. T.name .. ".stdout 2>&1")
        log = lib.slurp(T.name .. ".log") or ""
        seeds[run] = lib.seedof(log, pkg)
        if not ok or log:find("\n! ") then break end
      end
      local P = lib.pages(log, pkg)
      local err
      if not ok or log:find("\n! ") then
        err = "errore di compilazione (vedi build/" .. T.name .. ".log)"
      elseif #P == 0 then
        err = "nessuna riga " .. pkg .. " nel log"
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
end

return lib
