-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 giob22. Vedi il file LICENSE.
-- fpgamargins.lua: motivo "matrice di interconnessione FPGA" per margincore.
--
-- Piste orizzontali e verticali (con una ogni sei più spessa, le "piste lunghe"), punti di
-- connessione programmabili (PIP) agli incroci, blocchi logici (CLB, BRAM, DSP) sparsi e
-- alcune connessioni già instradate in arancione, che seguono le piste.
-- Piste e blocchi vengono dal seme di struttura: in fronte/retro le pagine affiancate hanno la
-- stessa matrice specchiata; i PIP attivi e le connessioni instradate cambiano a ogni pagina,
-- come due configurazioni diverse dello stesso dispositivo.

local core = ...
local fmt, num, col = string.format, core.num, core.col

local pals = {
  blue = { tr = {159,178,208}, long = {111,136,181}, pip = {150,168,200}, on = {31,58,110}, net = {224,123,32},
           clb = {227,241,239}, clbk = {58,138,133}, clbi = {169,212,207},
           bram = {251,238,221}, bramk = {197,138,59}, bramc = {217,164,96},
           dsp = {236,230,246}, dspk = {122,95,176}, dspc = {154,133,200} },
  -- blu da stilografica con le connessioni instradate dorate
  ink  = { tr = {143,160,216}, long = {74,98,184}, pip = {140,156,214}, on = {28,42,120}, net = {184,145,58},
           clb = {232,236,250}, clbk = {64,88,170}, clbi = {176,190,236},
           bram = {250,243,224}, bramk = {176,140,62}, bramc = {212,184,110},
           dsp = {226,230,248}, dspk = {52,70,150}, dspc = {130,146,208} },
  mono = { tr = {185,185,185}, long = {120,120,120}, pip = {160,160,160}, on = {40,40,40}, net = {20,20,20},
           clb = {240,240,240}, clbk = {90,90,90}, clbi = {200,200,200},
           bram = {235,235,235}, bramk = {90,90,90}, bramc = {170,170,170},
           dsp = {228,228,228}, dspk = {90,90,90}, dspc = {160,160,160} },
}

local M = {
  opts = { palette = "blue", pitch = 4.6, blocks = true, nets = true, pips = true, weight = 1 },
}

function M.draw(ctx)
  local o, W, H, s = ctx.opts, ctx.W, ctx.H, ctx.s
  local rs, rd, dens0, inEx, free = ctx.rs, ctx.rd, ctx.dens0, ctx.inEx, ctx.free
  local pal = pals[o.palette] or pals.blue
  local ri = ctx.ri
  local t = math.max(1.5, o.pitch * s)
  local x0, y0 = ri + 3 * s, ri + 3 * s
  local nx, ny = math.floor((W - 2 * ri - 6 * s) / t), math.floor((H - 2 * ri - 6 * s) / t)
  local function X(i) return x0 + i * t end
  local function Y(j) return y0 + j * t end

  -- nodi della griglia fuori dalle zone vietate
  local okg = {}
  for j = 0, ny - 1 do
    local row = j * nx + 1
    for i = 0, nx - 1 do okg[row + i] = not inEx(X(i), Y(j), 0) end
  end

  -- tratti: Hs[j*nx+i+1] collega (i,j)-(i+1,j); Vs[j*nx+i+1] collega (i,j)-(i,j+1)
  local Hs, Vs = {}, {}
  for j = 0, ny - 1 do
    local i = 0
    while i < nx - 1 do
      local n = 4 + math.floor(rs() * 11)
      if rs() < math.min(1, dens0(X(math.min(nx - 1, i + n // 2)), Y(j))) then
        for k = i, math.min(i + n, nx - 1) - 1 do
          local idx = j * nx + k + 1
          Hs[idx] = okg[idx] and okg[idx + 1] or nil
        end
      end
      i = i + n + math.floor(rs() * 5)
    end
  end
  for i = 0, nx - 1 do
    local j = 0
    while j < ny - 1 do
      local n = 4 + math.floor(rs() * 11)
      if rs() < math.min(1, dens0(X(i), Y(math.min(ny - 1, j + n // 2)))) then
        for k = j, math.min(j + n, ny - 1) - 1 do
          local idx = k * nx + i + 1
          Vs[idx] = okg[idx] and okg[idx + nx] or nil
        end
      end
      j = j + n + math.floor(rs() * 5)
    end
  end

  local function P(x, y) return fmt("%.1f %.1f", x, H - y) end
  local bufT, bufL = {}, {}
  for j = 0, ny - 1 do                              -- piste orizzontali: una polilinea per tratto continuo
    local i = 0
    while i < nx - 1 do
      if Hs[j * nx + i + 1] then
        local k = i
        while k + 1 < nx - 1 and Hs[j * nx + k + 2] do k = k + 1 end
        local buf = (j % 6 == 0) and bufL or bufT
        buf[#buf + 1] = P(X(i), Y(j)) .. " m " .. P(X(k + 1), Y(j)) .. " l"
        i = k + 1
      else
        i = i + 1
      end
    end
  end
  for i = 0, nx - 1 do                              -- piste verticali
    local j = 0
    while j < ny - 1 do
      if Vs[j * nx + i + 1] then
        local k = j
        while k + 1 < ny - 1 and Vs[(k + 1) * nx + i + 1] do k = k + 1 end
        local buf = (i % 6 == 0) and bufL or bufT
        buf[#buf + 1] = P(X(i), Y(j)) .. " m " .. P(X(i), Y(k + 1)) .. " l"
        j = k + 1
      else
        j = j + 1
      end
    end
  end

  local function node(i, j)
    local h = (i > 0 and Hs[j * nx + i]) or (i < nx - 1 and Hs[j * nx + i + 1])
    local v = (j > 0 and Vs[(j - 1) * nx + i + 1]) or (j < ny - 1 and Vs[j * nx + i + 1])
    return h and v
  end

  local wt = (tonumber(o.weight) or 1) * s
  local out = { "1 J 1 j" }
  if #bufT > 0 then out[#out + 1] = col(pal.tr, 1) .. " RG " .. num(.45 * wt) .. " w " .. table.concat(bufT, " ") .. " S" end
  if #bufL > 0 then out[#out + 1] = col(pal.long, 1) .. " RG " .. num(.9 * wt) .. " w " .. table.concat(bufL, " ") .. " S" end

  -- connessioni già instradate: percorsi che seguono le piste
  if o.nets then
    local DIRS = { {1, 0}, {-1, 0}, {0, 1}, {0, -1} }
    local function avail(i, j, dx, dy)
      if dx == 1 then return i < nx - 1 and Hs[j * nx + i + 1] end
      if dx == -1 then return i > 0 and Hs[j * nx + i] end
      if dy == 1 then return j < ny - 1 and Vs[j * nx + i + 1] end
      return j > 0 and Vs[(j - 1) * nx + i + 1]
    end
    local paths, dots = {}, {}
    for _ = 1, 400 do
      local i, j = math.floor(rd() * nx), math.floor(rd() * ny)
      if node(i, j) then
        local d = DIRS[1 + math.floor(rd() * 4)]
        local pts = { P(X(i), Y(j)) .. " m" }
        local first = { X(i), Y(j) }
        local np = 1
        for _ = 1, 30 + math.floor(rd() * 51) do
          local cand, keep = {}, false
          for _, c in ipairs(DIRS) do
            if not (c[1] == -d[1] and c[2] == -d[2]) and avail(i, j, c[1], c[2]) then
              cand[#cand + 1] = c
              if c == d then keep = true end
            end
          end
          if #cand == 0 then break end
          if not (keep and rd() < .75) then d = cand[1 + math.floor(rd() * #cand)] end
          i, j = i + d[1], j + d[2]
          pts[#pts + 1] = P(X(i), Y(j)) .. " l"
          np = np + 1
        end
        if np > 12 then
          paths[#paths + 1] = table.concat(pts, " ")
          dots[#dots + 1] = P(first[1], first[2]) .. " m " .. P(first[1], first[2]) .. " l"
          dots[#dots + 1] = P(X(i), Y(j)) .. " m " .. P(X(i), Y(j)) .. " l"
        end
      end
    end
    if #paths > 0 then
      out[#out + 1] = col(pal.net, 1) .. " RG " .. num(1.3 * wt) .. " w " .. table.concat(paths, " ") .. " S"
      out[#out + 1] = num(3.4 * wt) .. " w " .. table.concat(dots, " ") .. " S"
    end
  end

  -- punti di connessione: un punto tenue a ogni incrocio, scuro se attivo (cerchietti di
  -- lunghezza zero con estremità tonde: pochi byte per punto)
  if o.pips then
    local off, on = {}, {}
    for j = 0, ny - 1 do
      for i = 0, nx - 1 do
        if (i + j) % 2 == 0 and node(i, j) then
          local p = P(X(i), Y(j))
          local list = (rd() < .2) and on or off
          list[#list + 1] = p .. " m " .. p .. " l"
        end
      end
    end
    if #off > 0 then out[#out + 1] = col(pal.pip, 1) .. " RG " .. num(1.5 * wt) .. " w " .. table.concat(off, " ") .. " S" end
    if #on > 0 then out[#out + 1] = col(pal.on, 1) .. " RG " .. num(2.1 * wt) .. " w " .. table.concat(on, " ") .. " S" end
  end

  -- blocchi logici: CLB (quattro celle), BRAM (righe), DSP (croce)
  if o.blocks then
    local function R(a, b, c2, d) return fmt("%.1f %.1f %.1f %.1f re", a, H - d, c2 - a, d - b) end
    local n, bl = 9, {}
    for bi = 1, nx - n - 2, 15 do
      for bj = 1, ny - n - 2, 15 do
        local r = { x0 = X(bi), y0 = Y(bj), x1 = X(bi + n), y1 = Y(bj + n) }
        local keep = rs()
        if keep < .85 and r.x0 > ri and r.x1 < W - ri and r.y0 > ri and r.y1 < H - ri and free(r)
           and dens0((r.x0 + r.x1) / 2, (r.y0 + r.y1) / 2) > .5 then
          local kind = (bi // 15) % 4
          local k, f = (kind == 2) and pal.bramk or (kind == 3) and pal.dspk or pal.clbk,
                       (kind == 2) and pal.bram or (kind == 3) and pal.dsp or pal.clb
          bl[#bl + 1] = col(f, 1) .. " rg " .. col(k, 1) .. " RG " .. num(.7 * wt) .. " w " .. R(r.x0, r.y0, r.x1, r.y1) .. " B"
          if kind == 2 then
            local t2 = {}
            for q = 1, 7 do
              local yy = r.y0 + q * (r.y1 - r.y0) / 8
              t2[#t2 + 1] = P(r.x0 + 2, yy) .. " m " .. P(r.x1 - 2, yy) .. " l"
            end
            bl[#bl + 1] = col(pal.bramc, 1) .. " RG " .. num(.35 * wt) .. " w " .. table.concat(t2, " ") .. " S"
          elseif kind == 3 then
            bl[#bl + 1] = col(pal.dspc, 1) .. " RG " .. num(.5 * wt) .. " w " ..
              P(r.x0 + 3, r.y0 + 3) .. " m " .. P(r.x1 - 3, r.y1 - 3) .. " l " ..
              P(r.x1 - 3, r.y0 + 3) .. " m " .. P(r.x0 + 3, r.y1 - 3) .. " l S"
          else
            local w2, t2 = (r.x1 - r.x0) / 2, {}
            for a = 0, 1 do
              for b = 0, 1 do
                t2[#t2 + 1] = R(r.x0 + 3 + a * w2, r.y0 + 3 + b * w2, r.x0 + w2 - 3 + a * w2, r.y0 + w2 - 3 + b * w2)
              end
            end
            bl[#bl + 1] = col(pal.clbi, 1) .. " rg " .. table.concat(t2, " ") .. " f"
          end
        end
      end
    end
    for _, b in ipairs(bl) do out[#out + 1] = b end
  end
  return out
end

return M
