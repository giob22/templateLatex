-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 giob22. Vedi il file LICENSE.
-- asicmargins.lua: motivo "layout di chip" per margincore (celle standard con rail VDD/VSS,
-- macro di memoria, tre livelli di metallo M1/M2/M3 con via, bond pad, dummy fill, seal ring),
-- disegnato come operatori PDF diretti.
-- Seme, zone (where), fronte/retro, alone e scala automatica sono del motore comune.

local core = ...
local fmt, num, col = string.format, core.num, core.col

-- Stile comune: opacità (come schiarimento), spessori relativi, tratti.
-- I valori sono quelli della v0.1, quindi "chip" e "mono" non cambiano.
local base = {
  alpha = { strap = .85, vdd = 1, vss = 1, pin = 1, m1 = .8, m2 = .8, m3 = .75,
            v1 = 1, v2 = 1, padfill = .25 },
  width = { m1 = 1, m2 = 1, m3 = 1, v1 = 1, v2 = 1 },
  via = { v1 = .3, v2 = .3 },   -- probabilità di un via a ogni incrocio
  ringw = { 1.2, .5 }, cellw = .3, macrow = .8, mlinew = .3, padw = .8,
  dummy = "0.88 0.88 0.88 rg", cellfill = "0.965 g", cellstroke = "0.65 G",
  macrofill = "0.965 g", mline = "0.78 G",
}

-- Un colore di livello può essere una terna o un elenco di terne: con un elenco
-- ogni segmento ne sceglie una a caso, come le diverse diluizioni di un inchiostro.
local pals = {
  chip = { m1 = {55,138,221}, m2 = {186,117,23}, m3 = {127,119,221},
           v1 = {29,158,117}, v2 = {15,110,86}, vdd = {216,90,48},
           vss = {55,138,221}, ring = {127,119,221}, macro = {136,135,128},
           pad = {186,117,23} },
  -- blu da stilografica (oltremare, cobalto, indaco) con velature chiare;
  -- l'oro è una doratura rada: solo rail VDD, pad, anello e i via grandi di M3
  ink  = { m1 = { {28,58,214}, {48,94,228}, {124,152,236} },
           m2 = { {20,28,96}, {36,54,152}, {96,84,198} },
           m3 = { {118,146,232}, {160,180,244}, {138,120,222} },
           v1 = {22,32,104}, v2 = {192,154,60}, vdd = {196,160,74},
           vss = {36,54,152}, ring = {176,140,62}, macro = {84,96,156},
           pad = {196,160,74},
           alpha = { strap = .5, m1 = .85, m2 = .8, m3 = .42, v1 = .9, v2 = 1,
                     padfill = .18 },
           width = { m1 = .7, m2 = .55, m3 = 1.6, v1 = .8, v2 = .8 },
           via = { v1 = .16, v2 = .25 },
           ringw = { .8, .35 }, cellw = .25, macrow = .55, mlinew = .25, padw = .55,
           dummy = col({150,168,226}, .32) .. " rg",
           cellfill = "0.98 0.984 0.996 rg", cellstroke = col({118,134,196}, .65) .. " RG",
           macrofill = "0.98 0.984 0.996 rg", mline = col({150,164,214}, .55) .. " RG" },
  mono = { m1 = {90,90,90}, m2 = {140,140,140}, m3 = {50,50,50},
           v1 = {30,30,30}, v2 = {0,0,0}, vdd = {60,60,60},
           vss = {110,110,110}, ring = {70,70,70}, macro = {120,120,120},
           pad = {100,100,100} },
}
for _, P in pairs(pals) do
  for k, v in pairs(base) do
    if P[k] == nil then P[k] = v
    elseif type(v) == "table" and type(P[k]) == "table" then
      for kk, vv in pairs(v) do if P[k][kk] == nil then P[k][kk] = vv end end
    end
  end
end

local function ncol(c) return type(c[1]) == "table" and #c or 1 end
local function pick(c, i) if type(c[1]) == "table" then return c[i] or c[1] end return c end

local M = {
  opts = { pitch = 3.2, blockw = 48, palette = "chip", ring = true, blocks = true,
           macros = true, pads = true, dummy = true, m3 = true },
}

function M.draw(ctx)
  local o, W, H, s = ctx.opts, ctx.W, ctx.H, ctx.s
  local rs, rd, dens = ctx.rs, ctx.rd, ctx.dens
  local TXT, EX, reg, set, c1, c2 = ctx.TXT, ctx.EX, ctx.reg, ctx.set, ctx.c1, ctx.c2
  local free, inEx, clip, rowIv, colIv = ctx.free, ctx.inEx, ctx.clip, ctx.rowIv, ctx.colIv
  local pal = pals[o.palette] or pals.chip
  local A, WD = pal.alpha, pal.width
  local p = o.pitch * s
  local ringO, ringI, ri = 8 * s, 11 * s, ctx.ri
  local bw = o.blockw * s

  -- livelli: ognuno è un elenco di secchi, uno per tonalità della palette
  local L = {}
  for _, k in ipairs({ "dummy", "strap", "vdd", "vss", "pin", "v1pad" }) do L[k] = { {} } end
  for _, k in ipairs({ "m1", "m2", "m3", "v1", "v2" }) do
    L[k] = {}
    for i = 1, ncol(pal[k]) do L[k][i] = {} end
  end
  local cells, mac, mlines, padd = {}, {}, {}, {}
  local function put(name, x, y, w, h)
    local B = L[name]
    local t = B[1]
    if #B > 1 then t = B[1 + math.floor(rd() * #B)] end
    t[#t+1] = fmt("%.2f %.2f %.2f %.2f re", x, H - y - h, w, h)
  end

  local blocks, macros, pads = {}, {}, {}
  local function strip(side, y0, h)
    local r
    if side < 0 then r = { x0 = ri, x1 = math.min(TXT.x0 - 4*s, ri + bw) }
    else r = { x0 = math.max(TXT.x1 + 4*s, W - ri - bw), x1 = W - ri } end
    if r.x1 - r.x0 < 22*s then return nil end
    r.y0, r.y1 = y0, y0 + h
    if r.y0 < ri or r.y1 > H - ri then return nil end
    return r
  end

  if o.blocks then
    local n, rh = 8, 2.5 * p
    for _, c in ipairs({ c1, c2 }) do
      local side = c[1] == 0 and -1 or 1
      local y0 = c[2] == 1 and (H - ri - n*rh) or ri
      local r = strip(side, y0, n*rh)
      if r and free(r) then r.n, r.rh = n, rh; blocks[#blocks+1] = r; EX[#EX+1] = r end
    end
    -- piccola banda di celle sotto il testo
    if H - ri - TXT.y1 > 4*p + 6*s then
      local w = .55 * (TXT.x1 - TXT.x0)
      local x0 = TXT.x0 + rs() * .35 * (TXT.x1 - TXT.x0)
      local r = { x0 = x0, x1 = x0 + w, y0 = H - ri - 4*p, y1 = H - ri, n = 2, rh = 2*p }
      if free(r) then blocks[#blocks+1] = r; EX[#EX+1] = r end
    end
  end

  if o.macros then
    for _ = 1, 2 do
      local side = rs() < .5 and -1 or 1
      if reg then   -- le macro stanno solo su un lato attivo
        if side < 0 and not set.left then side = 1 elseif side > 0 and not set.right then side = -1 end
      end
      local h = 22 * p
      local r = strip(side, H * (.2 + .45 * rs()), h)
      if r and free(r) then r.side = side; macros[#macros+1] = r; EX[#EX+1] = r end
    end
  end

  if o.pads then
    local pw, ph, pp = 2.5*p, 1.75*p, 4.5*p
    if TXT.y0 - ri >= ph + 12*s then
      local x = TXT.x0 + 6*s + rs() * 20*s
      for i = 0, 7 do
        local q = { x0 = x + i*pp, x1 = x + i*pp + pw, y0 = ri + 1.5*s, y1 = ri + 1.5*s + ph }
        if q.x1 < TXT.x1 and free(q) then pads[#pads+1] = q end
      end
    end
    if H - ri - TXT.y1 >= ph + 12*s then
      local bx = TXT.x0 + 6*s
      for _, b in ipairs(blocks) do if b.n == 2 then bx = b.x1 + 12*s end end
      for i = 0, 2 do
        local px = bx + i*pp
        local q = { x0 = px, x1 = px + pw, y0 = H - ri - ph - .5*s, y1 = H - ri - .5*s }
        if px + pw < TXT.x1 and free(q) then pads[#pads+1] = q end
      end
    end
    for _, q in ipairs(pads) do EX[#EX+1] = { x0 = q.x0 - 2*s, x1 = q.x1 + 2*s, y0 = q.y0 - 2*s, y1 = q.y1 + 2*s } end
  end

  -- dummy fill nelle zone poco dense
  if o.dummy then
    local step = 2 * p
    for x = ri + p, W - ri - p, step do
      for y = ri + p, H - ri - p, step do
        if not inEx(x, y, step) and dens(x, y) < .5 and rd() < .6 then put("dummy", x, y, .75*p, .75*p) end
      end
    end
  end

  -- celle standard con rail e strap
  for _, B in ipairs(blocks) do
    local rh, n = B.rh, B.n
    for r = 0, n - 1 do
      local cx = B.x0
      while cx < B.x1 - 1 do
        local w = math.min((1.5 + .75 * math.floor(rd() * 4)) * p, B.x1 - cx)
        cells[#cells+1] = fmt("%.2f %.2f %.2f %.2f re B", cx, H - (B.y0 + r*rh) - rh, w, rh)
        if w >= 1.5 * p then
          put("m1", cx + .375*p, B.y0 + r*rh + rh*.3, .75*p, .375*p)
          put("m1", cx + w - 1.125*p, B.y0 + r*rh + rh*.62, .75*p, .375*p)
        end
        cx = cx + w
      end
    end
    local off = (n == 2) and 2.5 * p or 2 * p
    local sxs = { B.x0 + off, B.x1 - off }
    for r = 0, n do
      local ry = B.y0 + r * rh
      put(r % 2 == 1 and "vss" or "vdd", B.x0, ry - .25*p, B.x1 - B.x0, .5*p)
      for _, sx in ipairs(sxs) do
        for _, dx in ipairs({ -.425*p, .125*p }) do
          for _, dy in ipairs({ -.425*p, .125*p }) do put("v1", sx + dx, ry + dy, .3*p, .3*p) end
        end
      end
    end
    for _, sx in ipairs(sxs) do put("strap", sx - .375*p, B.y0, .75*p, B.y1 - B.y0) end
  end

  -- macro di memoria
  for _, Mc in ipairs(macros) do
    mac[#mac+1] = fmt("%.2f %.2f %.2f %.2f re B", Mc.x0, H - Mc.y1, Mc.x1 - Mc.x0, Mc.y1 - Mc.y0)
    local y = Mc.y0 + p
    while y < Mc.y1 - .25*p do
      mlines[#mlines+1] = fmt("%.2f %.2f m %.2f %.2f l", Mc.x0 + .5*p, H - y, Mc.x1 - .5*p, H - y)
      y = y + .75 * p
    end
    local cx = (Mc.x0 + Mc.x1) / 2
    mlines[#mlines+1] = fmt("%.2f %.2f m %.2f %.2f l", cx, H - Mc.y0 - .5*p, cx, H - Mc.y1 + .5*p)
    y = Mc.y0 + .75 * p
    while y < Mc.y1 - .5*p do
      put("pin", Mc.side < 0 and Mc.x1 or Mc.x0 - .75*p, y, .75*p, .35*p)
      y = y + p
    end
  end

  -- routing: M1 orizzontale, M2 verticale, M3 orizzontale largo
  local w1, w2, w3 = .5*p*WD.m1, .5*p*WD.m2, .75*p*WD.m3
  local hs, h3, vcol = {}, {}, {}
  local xmin, xmax, ymin, ymax = ri, W - ri, ri, H - ri
  local minlen = 1.25 * p
  local y = ymin
  while y <= ymax do
    local iv = rowIv(y)
    local x = xmin
    while x < xmax do
      local a, b = x, math.min(xmax, x + p * (2 + rd() * 7.5))
      if rd() < dens((a + b) / 2, y) then
        for _, q in ipairs(clip(a, b, iv)) do
          if q[2] - q[1] >= minlen then hs[#hs+1] = { q[1], q[2], y }; put("m1", q[1], y - w1/2, q[2] - q[1], w1) end
        end
      end
      x = b + p * (.5 + rd() * 2.3)
    end
    y = y + p
  end
  local ci = 0
  local x = xmin
  while x <= xmax do
    local iv = colIv(x)
    local yy = ymin
    while yy < ymax do
      local a, b = yy, math.min(ymax, yy + p * (2 + rd() * 7.5))
      if rd() < dens(x, (a + b) / 2) then
        for _, q in ipairs(clip(a, b, iv)) do
          if q[2] - q[1] >= minlen then
            vcol[ci] = vcol[ci] or {}
            vcol[ci][#vcol[ci]+1] = { q[1], q[2] }
            put("m2", x - w2/2, q[1], w2, q[2] - q[1])
          end
        end
      end
      yy = b + p * (.5 + rd() * 2.3)
    end
    x = x + p; ci = ci + 1
  end
  if o.m3 then
    y = ymin + .5 * p
    while y <= ymax do
      local iv = rowIv(y)
      local xx = xmin
      while xx < xmax do
        local a, b = xx, math.min(xmax, xx + p * (5 + rd() * 12.5))
        if rd() < dens((a + b) / 2, y) * .55 then
          for _, q in ipairs(clip(a, b, iv)) do
            if q[2] - q[1] >= 2.5 * p then h3[#h3+1] = { q[1], q[2], y }; put("m3", q[1], y - w3/2, q[2] - q[1], w3) end
          end
        end
        xx = b + p * (1.5 + rd() * 6)
      end
      y = y + 2 * p
    end
  end

  -- via agli incroci
  local function vias(list, name, size)
    local prob = pal.via[name]
    for _, h in ipairs(list) do
      local c0 = math.floor((h[1] - xmin) / p) + 1
      local c1 = math.ceil((h[2] - xmin) / p) - 1
      for c = c0, c1 do
        local vx = xmin + c * p
        if vx > h[1] + 1 and vx < h[2] - 1 and vcol[c] then
          for _, v in ipairs(vcol[c]) do
            if h[3] > v[1] + 1 and h[3] < v[2] - 1 and rd() < prob then
              put(name, vx - size/2, h[3] - size/2, size, size)
            end
          end
        end
      end
    end
  end
  vias(hs, "v1", .75 * p * WD.v1)
  vias(h3, "v2", p * WD.v2)

  -- pad di bonding
  for _, q in ipairs(pads) do
    padd[#padd+1] = fmt("%.2f %.2f %.2f %.2f re B", q.x0, H - q.y1, q.x1 - q.x0, q.y1 - q.y0)
    put("v1pad", q.x0 + .875*p, q.y0 + .625*p, .75*p, .5*p)
  end

  -- emissione
  local out = {}
  local function layer(name, c, a)
    for i, t in ipairs(L[name]) do
      if #t > 0 then out[#out+1] = col(pick(c, i), a) .. " rg\n" .. table.concat(t, "\n") .. "\nf" end
    end
  end
  out[#out+1] = pal.dummy
  if #L.dummy[1] > 0 then out[#out+1] = table.concat(L.dummy[1], "\n") .. "\nf" end
  if #cells > 0 then
    out[#out+1] = pal.cellfill .. " " .. pal.cellstroke .. " " .. num(pal.cellw * s) .. " w\n" .. table.concat(cells, "\n")
  end
  if #mac > 0 then
    out[#out+1] = pal.macrofill .. " " .. col(pal.macro, 1) .. " RG " .. num(pal.macrow * s) .. " w\n" .. table.concat(mac, "\n")
    out[#out+1] = pal.mline .. " " .. num(pal.mlinew * s) .. " w\n" .. table.concat(mlines, "\n") .. "\nS"
  end
  layer("strap", pal.m2, A.strap)
  layer("vdd", pal.vdd, A.vdd)
  layer("vss", pal.vss, A.vss)
  layer("pin", pal.m2, A.pin)
  layer("m1", pal.m1, A.m1)
  layer("m2", pal.m2, A.m2)
  layer("m3", pal.m3, A.m3)
  layer("v1", pal.v1, A.v1)
  layer("v2", pal.v2, A.v2)
  if #padd > 0 then
    out[#out+1] = col(pal.pad, A.padfill) .. " rg " .. col(pal.ring, 1) .. " RG " .. num(pal.padw * s) .. " w\n" .. table.concat(padd, "\n")
    layer("v1pad", pal.v1, A.v1)
  end
  if o.ring and not reg then
    out[#out+1] = col(pal.ring, 1) .. " RG " .. num(pal.ringw[1] * s) .. " w "
      .. fmt("%.2f %.2f %.2f %.2f re S %s w %.2f %.2f %.2f %.2f re S",
             ringO, ringO, W - 2*ringO, H - 2*ringO, num(pal.ringw[2] * s),
             ringI, ringI, W - 2*ringI, H - 2*ringI)
  elseif o.ring then
    -- anello a tratti: lati attivi per tutta la lunghezza, angoli per la loro portata
    local function path(d)
      local t = {}
      local function seg(x0, y0, x1, y1) t[#t+1] = fmt("%.2f %.2f m %.2f %.2f l", x0, H - y0, x1, H - y1) end
      if set.top then seg(d, d, W - d, d) end
      if set.bottom then seg(d, H - d, W - d, H - d) end
      if set.left then seg(d, d, d, H - d) end
      if set.right then seg(W - d, d, W - d, H - d) end
      if set.tl then seg(d, d, reg.rx, d); seg(d, d, d, reg.ry) end
      if set.tr then seg(W - d, d, W - reg.rx, d); seg(W - d, d, W - d, reg.ry) end
      if set.bl then seg(d, H - d, reg.rx, H - d); seg(d, H - d, d, H - reg.ry) end
      if set.br then seg(W - d, H - d, W - reg.rx, H - d); seg(W - d, H - d, W - d, H - reg.ry) end
      return table.concat(t, " ")
    end
    out[#out+1] = col(pal.ring, 1) .. " RG 2 J " .. num(pal.ringw[1] * s) .. " w " .. path(ringO)
      .. " S " .. num(pal.ringw[2] * s) .. " w " .. path(ringI) .. " S"
  end
  return out
end

return M
