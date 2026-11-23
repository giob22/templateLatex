-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 giob22. Vedi il file LICENSE.
-- topomargins.lua: motivo "curve di livello" per margincore.
--
-- Il rilievo è la somma di quattro ottave di rumore liscio (reticolo di valori casuali
-- interpolati) più colline negli angoli di crescita; le curve sono le isoipse a quote
-- equidistanti, trovate con i "marching squares" e collegate in polilinee. Una curva su
-- `index` è maestra (più spessa). Dove la densità del margine è bassa le curve sfumano
-- e si interrompono, ognuna a una distanza diversa dall'angolo.
-- Il rilievo nasce dal seme di struttura: in fronte/retro le due pagine affiancate mostrano
-- lo stesso paesaggio specchiato, con piccole differenze nel punto in cui le curve sfumano.

local core = ...
local fmt, num, col = string.format, core.num, core.col

local pals = {
  sepia = { line = {176,121,63},  index = {138,82,38},   peak = {107,61,27} },
  -- inchiostro blu con le curve maestre dorate
  ink   = { line = {64,94,190},   index = {176,140,62},  peak = {24,40,120} },
  mono  = { line = {150,150,150}, index = {60,60,60},    peak = {30,30,30} },
  -- carta nautica: batimetriche
  sea   = { line = {118,164,208}, index = {44,100,160},  peak = {28,70,120} },
}

local M = {
  opts = { palette = "sepia", levels = 40, index = 5, feature = 200, step = 3,
           hills = true, peaks = true, weight = 1 },
}

-- rumore di valore: valori casuali sui nodi di un reticolo (da un hash di coordinate e seme),
-- interpolati con una curva liscia
local function hash(ix, iy, k)
  local h = (ix * 374761393 + iy * 668265263 + k * 2246822519) & 0xFFFFFFFF
  h = ((h ~ (h >> 13)) * 1274126177) & 0xFFFFFFFF
  h = h ~ (h >> 16)
  return (h & 0xFFFFFF) / 16777216
end
local function fade(t) return t * t * t * (t * (t * 6 - 15) + 10) end
local function vnoise(x, y, scale, k)
  local u, v = x / scale, y / scale
  local ix, iy = math.floor(u), math.floor(v)
  local fx, fy = fade(u - ix), fade(v - iy)
  local a, b = hash(ix, iy, k), hash(ix + 1, iy, k)
  local c, d = hash(ix, iy + 1, k), hash(ix + 1, iy + 1, k)
  local top = a + (b - a) * fx
  return top + ((c + (d - c) * fx) - top) * fy
end

-- Lati di una cella: 1 sotto (nodi 00-10), 2 destra (10-11), 3 sopra (01-11), 4 sinistra (00-01).
-- Chiave: nodi sopra la quota, con 00 = 1, 10 = 2, 11 = 4, 01 = 8; valore: i segmenti
-- (coppie di lati) da congiungere. I casi 5 e 10 sono selle.
local CASES = {
  [1] = { {4,1} }, [2] = { {1,2} }, [3] = { {4,2} }, [4] = { {2,3} },
  [5] = { {4,1}, {2,3} }, [6] = { {1,3} }, [7] = { {4,3} }, [8] = { {4,3} },
  [9] = { {1,3} }, [10] = { {1,2}, {4,3} }, [11] = { {2,3} }, [12] = { {4,2} },
  [13] = { {1,2} }, [14] = { {4,1} },
}

function M.draw(ctx)
  local o, W, H, s = ctx.opts, ctx.W, ctx.H, ctx.s
  local dens0, inEx, EX = ctx.dens0, ctx.inEx, ctx.EX
  local pal = pals[o.palette] or pals.sepia
  local ri = ctx.ri
  local step = math.max(1.2, o.step * s)
  local nx = math.floor((W - 2 * ri) / step) + 1
  local ny = math.floor((H - 2 * ri) / step) + 1
  local m = .6 * step                      -- distanza minima dalle zone vietate
  local function X(i) return ri + i * step end
  local function Y(j) return ri + j * step end

  -- nodi della griglia che cadono nelle zone vietate (testo, where, alone)
  local masked = {}
  for _, e in ipairs(EX) do
    local i0 = math.max(0, math.floor((e.x0 - m - ri) / step) + 1)
    local i1 = math.min(nx - 1, math.ceil((e.x1 + m - ri) / step) - 1)
    local j0 = math.max(0, math.floor((e.y0 - m - ri) / step) + 1)
    local j1 = math.min(ny - 1, math.ceil((e.y1 + m - ri) / step) - 1)
    for j = j0, j1 do
      local row = j * nx + 1
      for i = i0, i1 do masked[row + i] = true end
    end
  end

  -- colline: una forte sull'angolo principale, una sul secondo, le altre più deboli
  local hills = {}
  if o.hills then
    local function add(c, a, sg)
      hills[#hills + 1] = { x = c[1] * W + (c[1] == 0 and 1 or -1) * .10 * W,
                            y = c[2] * H + (c[2] == 0 and 1 or -1) * .08 * H, a = a, s2 = 2 * sg * sg }
    end
    add(ctx.c1, 2.6, .235 * W)
    if ctx.c2 ~= ctx.c1 then add(ctx.c2, 2.2, .22 * W) end
    for _, c in ipairs(ctx.clist) do
      if c ~= ctx.c1 and c ~= ctx.c2 then add(c, 1.2, .15 * W) end
    end
  end

  local F, sk, dseed = o.feature * s, ctx.sseed, ctx.dseed
  local AMP, K = { 1, .5, .22, .08 }, 4.6
  local function terrain(x, y)
    local z = 0
    for k = 1, 4 do
      z = z + AMP[k] * K * (vnoise(x, y, F / 2 ^ (k - 1), sk + 7919 * k) - .5)
    end
    for _, h in ipairs(hills) do
      local dx, dy = x - h.x, y - h.y
      z = z + h.a * math.exp(-(dx * dx + dy * dy) / h.s2)
    end
    return z
  end

  -- quote ai nodi liberi
  local Z, zmin, zmax = {}, math.huge, -math.huge
  for j = 0, ny - 1 do
    local row = j * nx + 1
    for i = 0, nx - 1 do
      if not masked[row + i] then
        local z = terrain(X(i), Y(j))
        Z[row + i] = z
        if z < zmin then zmin = z end
        if z > zmax then zmax = z end
      end
    end
  end
  if not (zmax > zmin) then return {} end
  local nlev = math.max(2, math.floor(o.levels))
  local sp = (zmax - zmin) / nlev

  -- punti delle curve sui lati delle celle, per livello; ogni punto ha al più due vicini
  local EPX, EPY, A1, A2 = {}, {}, {}, {}
  local function edgepoint(k, e, i, j, L, z00, z10, z01, z11)
    local id, x, y
    if e == 1 then
      id = 2 * (j * nx + i); x = X(i) + (L - z00) / (z10 - z00) * step; y = Y(j)
    elseif e == 2 then
      id = 2 * (j * nx + i + 1) + 1; x = X(i + 1); y = Y(j) + (L - z10) / (z11 - z10) * step
    elseif e == 3 then
      id = 2 * ((j + 1) * nx + i); x = X(i) + (L - z01) / (z11 - z01) * step; y = Y(j + 1)
    else
      id = 2 * (j * nx + i) + 1; x = X(i); y = Y(j) + (L - z00) / (z01 - z00) * step
    end
    EPX[k][id], EPY[k][id] = x, y
    return id
  end
  local function link(k, a, b)
    local a1, a2 = A1[k], A2[k]
    if a1[a] then a2[a] = b else a1[a] = b end
    if a1[b] then a2[b] = a else a1[b] = a end
  end
  for j = 0, ny - 2 do
    local r0, r1 = j * nx + 1, (j + 1) * nx + 1
    for i = 0, nx - 2 do
      local z00, z10, z01, z11 = Z[r0 + i], Z[r0 + i + 1], Z[r1 + i], Z[r1 + i + 1]
      if z00 and z10 and z01 and z11 then
        local lo = math.min(z00, z10, z01, z11)
        local hi = math.max(z00, z10, z01, z11)
        for k = math.floor((lo - zmin) / sp) + 1, math.floor((hi - zmin) / sp) do
          local L = zmin + k * sp
          local code = (z00 >= L and 1 or 0) + (z10 >= L and 2 or 0)
                     + (z11 >= L and 4 or 0) + (z01 >= L and 8 or 0)
          local cs = CASES[code]
          if cs then
            if not EPX[k] then EPX[k], EPY[k], A1[k], A2[k] = {}, {}, {}, {} end
            for _, c in ipairs(cs) do
              local a = edgepoint(k, c[1], i, j, L, z00, z10, z01, z11)
              local b = edgepoint(k, c[2], i, j, L, z00, z10, z01, z11)
              link(k, a, b)
            end
          end
        end
      end
    end
  end

  -- una curva si vede dove la densità liscia (più un po' di rumore a grana larga) supera una
  -- soglia propria della curva: così ognuna sfuma a una distanza diversa dall'angolo
  -- soglie e rumore a grana larga vengono dal seme di struttura (uguale per le due pagine
  -- affiancate); il seme della pagina aggiunge solo una piccola variazione
  local rsd = core.rng(sk + 5)
  local th = {}
  for k = 1, nlev do th[k] = .10 + rsd() * .22 end
  local function visible(x, y, thr)
    if inEx(x, y, m) then return false end
    return dens0(x, y) + .45 * (vnoise(x, y, 55 * s, sk + 11) - .5)
                       + .10 * (vnoise(x, y, 28 * s, dseed + 13) - .5) > thr
  end

  local run = {}               -- punti visibili consecutivi della polilinea in corso
  local function flush(buf)
    if #run >= 6 then
      local t = {}
      for q = 1, #run, 2 do
        t[#t + 1] = fmt("%.2f %.2f %s", run[q], H - run[q + 1], q == 1 and "m" or "l")
      end
      buf[#buf + 1] = table.concat(t, " ")
    end
    run = {}
  end
  local function point(buf, x, y, thr)
    if visible(x, y, thr) then run[#run + 1] = x; run[#run + 1] = y else flush(buf) end
  end

  local bufN, bufI = {}, {}
  local every = math.max(1, math.floor(o.index))
  for k = 1, nlev do
    local px, py, a1, a2 = EPX[k], EPY[k], A1[k], A2[k]
    if px then
      local buf, thr = (k % every == 0) and bufI or bufN, th[k]
      local ids = {}
      for id in pairs(a1) do ids[#ids + 1] = id end
      table.sort(ids)
      local seen = {}
      local function trace(start)
        seen[start] = true
        point(buf, px[start], py[start], thr)
        local cur = start
        while true do
          local n1, n2 = a1[cur], a2[cur]
          local nxt
          if n1 and not seen[n1] then nxt = n1 elseif n2 and not seen[n2] then nxt = n2 end
          if not nxt then
            if cur ~= start and (n1 == start or n2 == start) then point(buf, px[start], py[start], thr) end
            break
          end
          seen[nxt] = true
          point(buf, px[nxt], py[nxt], thr)
          cur = nxt
        end
        flush(buf)
      end
      for _, id in ipairs(ids) do          -- prima le curve aperte, dai loro estremi
        if not a2[id] and not seen[id] then trace(id) end
      end
      for _, id in ipairs(ids) do          -- poi quelle chiuse
        if not seen[id] then trace(id) end
      end
    end
  end

  local out = { "1 J 1 j" }
  local wt = (tonumber(o.weight) or 1) * s
  if #bufN > 0 then
    out[#out + 1] = col(pal.line, 1) .. " RG " .. num(.42 * wt) .. " w " .. table.concat(bufN, " ") .. " S"
  end
  if #bufI > 0 then
    out[#out + 1] = col(pal.index, 1) .. " RG " .. num(.85 * wt) .. " w " .. table.concat(bufI, " ") .. " S"
  end

  -- quote dei picchi: una crocetta sui massimi locali più alti, ben distanziati
  if o.peaks then
    local cand = {}
    for j = 1, ny - 2 do
      for i = 1, nx - 2 do
        local idx = j * nx + i + 1
        local z = Z[idx]
        if z and z > zmin + .6 * (zmax - zmin) then
          local top = true
          for dj = -1, 1 do
            for di = -1, 1 do
              if di ~= 0 or dj ~= 0 then
                local zz = Z[idx + dj * nx + di]
                if not zz or zz >= z then top = false end
              end
            end
          end
          if top then cand[#cand + 1] = { z, X(i), Y(j) } end
        end
      end
    end
    table.sort(cand, function(a, b) if a[1] ~= b[1] then return a[1] > b[1] end return a[2] < b[2] end)
    local keep, t, r = {}, {}, 3 * s
    for _, c in ipairs(cand) do
      local far = true
      for _, q in ipairs(keep) do
        if (q[1] - c[2]) ^ 2 + (q[2] - c[3]) ^ 2 < (45 * s) ^ 2 then far = false; break end
      end
      if far and dens0(c[2], c[3]) > .3 then
        keep[#keep + 1] = { c[2], c[3] }
        t[#t + 1] = fmt("%.2f %.2f m %.2f %.2f l %.2f %.2f m %.2f %.2f l",
                        c[2] - r, H - c[3], c[2] + r, H - c[3], c[2], H - c[3] + r, c[2], H - c[3] - r)
      end
    end
    if #t > 0 then
      out[#out + 1] = col(pal.peak, 1) .. " RG " .. num(.6 * wt) .. " w " .. table.concat(t, " ") .. " S"
    end
  end
  return out
end

return M
