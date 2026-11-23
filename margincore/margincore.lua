-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 giob22. Vedi il file LICENSE.
-- margincore.lua: motore comune dei margini generativi per LuaLaTeX.
--
-- Fa tutto ciò che non dipende dal disegno: seme (casuale se omesso) e sequenze casuali
-- per pagina, area del testo, scala automatica, zone `where` (lati e angoli), campo di
-- densità che cresce dagli angoli, zone vietate (testo, alone attorno a ciò che sporge dal
-- testo), specchiatura delle pagine pari in fronte/retro, messaggi nel log e inserimento
-- del risultato nella pagina.
--
-- Un motivo è una tabella con:
--   opts  = valori predefiniti delle sue opzioni (si sommano a quelle comuni)
--   draw  = function(ctx) ... return { "operatore PDF", ... } end
-- e si collega con  margincore.new{ name = "...", motif = margincore.loadmotif("....lua") }.
-- Il contesto ctx che riceve draw() è descritto in new(), più sotto.

local M = {}

local fmt = string.format

-- numero compatto per gli operatori PDF (0.300 -> 0.3)
local function num(x)
  local s = fmt("%.3f", x):gsub("0+$", ""):gsub("%.$", "")
  return s
end

-- colore schiarito verso il bianco (a = 1: pieno, a = 0: bianco)
local function col(c, a)
  a = a or 1
  return fmt("%.3f %.3f %.3f", (255-(255-c[1])*a)/255,
             (255-(255-c[2])*a)/255, (255-(255-c[3])*a)/255)
end

M.num, M.col = num, col

-- mulberry32 su interi a 64 bit mascherati a 32
local function rng(seed)
  local s = seed & 0xFFFFFFFF
  return function()
    s = (s + 0x6D2B79F5) & 0xFFFFFFFF
    local t = s
    t = ((t ~ (t >> 15)) * (t | 1)) & 0xFFFFFFFF
    t = (t ~ (t + (((t ~ (t >> 7)) * (t | 61)) & 0xFFFFFFFF))) & 0xFFFFFFFF
    return ((t ~ (t >> 14)) & 0xFFFFFFFF) / 4294967296
  end
end

M.rng = rng

-- Seme casuale: tempo con precisione al microsecondo, indirizzo di una tabella (cambia a
-- ogni processo per la rilocazione della memoria), tempo di CPU e un contatore, rimescolati
-- da mulberry32. Dà un intero tra 1 e 999999999, così si può copiare nel documento
-- (seed=N) per riottenere la stessa composizione.
local ncalls = 0
function M.newseed()
  ncalls = ncalls + 1
  local t = os.gettimeofday and os.gettimeofday() or (os.time() + os.clock())
  local addr = tonumber(tostring({}):match("(%x+)$") or "", 16) or 0
  local r = rng(math.floor(t * 1e6) ~ addr ~ math.floor(os.clock() * 1e6) ~ (ncalls * 2654435761))
  r()
  return 1 + math.floor(r() * 999999999)
end

-- Fattore di scala rispetto al riferimento (A4, margini laterali di 3,6 cm):
-- media geometrica tra scala della pagina e scala del margine laterale più stretto.
local A4W, A4H, REFMARGIN = 595.276, 841.89, 102.05
function M.scale(W, H, tx0, tx1)
  local sp = math.sqrt(W * H / (A4W * A4H))
  local sm = math.max(1, math.min(tx0, W - tx1)) / REFMARGIN
  local s = math.sqrt(sp * sm)
  return math.max(.45, math.min(1.8, s))
end

-- Zone di rispetto: rettangoli d'inchiostro fuori dall'area del testo, allargati
-- di "halo" e fusi quando si toccano. Coordinate in bp, y verso il basso.
function M.zones(rects, TXT, halo, W, mirror)
  local Z = {}
  for _, r in ipairs(rects or {}) do
    local x0, y0, x1, y1 = r[1], r[2], r[3], r[4]
    if mirror then x0, x1 = W - x1, W - x0 end
    if not (x0 >= TXT.x0 and x1 <= TXT.x1 and y0 >= TXT.y0 and y1 <= TXT.y1) then
      Z[#Z+1] = { x0 = x0 - halo, x1 = x1 + halo, y0 = y0 - halo, y1 = y1 + halo }
    end
  end
  local again = true
  while again do
    again = false
    for i = #Z, 2, -1 do
      local a = Z[i]
      for j = i - 1, 1, -1 do
        local b = Z[j]
        if a.x0 <= b.x1 and a.x1 >= b.x0 and a.y0 <= b.y1 and a.y1 >= b.y0 then
          b.x0, b.x1 = math.min(a.x0, b.x0), math.max(a.x1, b.x1)
          b.y0, b.y1 = math.min(a.y0, b.y0), math.max(a.y1, b.y1)
          table.remove(Z, i); again = true
          break
        end
      end
    end
  end
  return Z
end

-- Dove disegnare il motivo (opzione where). Il valore è un elenco, separato da virgole o da
-- "+", di: all, top, bottom, left, right, sides (left+right), topbottom (top+bottom),
-- topleft, topright, bottomleft, bottomright, corners (i quattro angoli).
-- I lati sono fasce lungo tutto il bordo; gli angoli sono chiazze che si fermano dopo
-- una frazione di pagina. Tutti i nomi sono posizioni fisiche sulla pagina.
local WHERE = {
  all = { "top", "bottom", "left", "right" },
  top = { "top" }, bottom = { "bottom" }, left = { "left" }, right = { "right" },
  sides = { "left", "right" }, topbottom = { "top", "bottom" },
  topleft = { "tl" }, topright = { "tr" }, bottomleft = { "bl" }, bottomright = { "br" },
  corners = { "tl", "tr", "bl", "br" },
}
local wcache = {}
function M.parse_where(str, name)
  str = tostring(str or "all")
  if wcache[str] then return wcache[str] end
  local set, any = {}, false
  for tok in str:lower():gmatch("%a+") do
    local v = WHERE[tok]
    if v then
      for _, k in ipairs(v) do set[k] = true end
      any = true
    else
      texio.write_nl("term and log", (name or "margincore") .. ": where, valore sconosciuto '" .. tok .. "' ignorato")
    end
  end
  if not any then
    texio.write_nl("term and log", (name or "margincore") .. ": where='" .. str .. "' non valido, uso all")
    set = { top = true, bottom = true, left = true, right = true }
  end
  wcache[str] = set
  return set
end
function M.is_all(set) return set.top and set.bottom and set.left and set.right end

-- scambia sinistra e destra: la pagina pari si costruisce nel riferimento della dispari
local function swaplr(set)
  return { top = set.top, bottom = set.bottom, left = set.right, right = set.left,
           tl = set.tr, tr = set.tl, bl = set.br, br = set.bl }
end

-- Complemento di un'unione di rettangoli {x0, y0, x1, y1} dentro la pagina W x H,
-- come elenco di rettangoli {x0, y0, x1, y1} disgiunti (compressione delle coordinate).
local function complement(rects, W, H)
  local function uniq(v)
    table.sort(v)
    local u = {}
    for _, x in ipairs(v) do if #u == 0 or x - u[#u] > 1e-6 then u[#u+1] = x end end
    return u
  end
  local xs, ys = { 0, W }, { 0, H }
  for _, r in ipairs(rects) do
    xs[#xs+1] = math.max(0, math.min(W, r[1])); xs[#xs+1] = math.max(0, math.min(W, r[3]))
    ys[#ys+1] = math.max(0, math.min(H, r[2])); ys[#ys+1] = math.max(0, math.min(H, r[4]))
  end
  xs, ys = uniq(xs), uniq(ys)
  local function inside(cx, cy)
    for _, r in ipairs(rects) do
      if cx > r[1] and cx < r[3] and cy > r[2] and cy < r[4] then return true end
    end
    return false
  end
  local out, open = {}, {}
  for j = 1, #ys - 1 do
    local cy = (ys[j] + ys[j+1]) / 2
    local nextopen, i = {}, 1
    while i < #xs do
      if inside((xs[i] + xs[i+1]) / 2, cy) then i = i + 1
      else
        local k = i
        while k + 1 < #xs and not inside((xs[k+1] + xs[k+2]) / 2, cy) do k = k + 1 end
        local key = xs[i] .. ":" .. xs[k+1]
        local r = open[key]
        if r then r.y1 = ys[j+1]
        else
          r = { x0 = xs[i], x1 = xs[k+1], y0 = ys[j], y1 = ys[j+1] }
          out[#out+1] = r
        end
        nextopen[key] = r
        i = k + 1
      end
    end
    open = nextopen
  end
  return out
end

-- Regione attiva per un insieme di lati/angoli (riferimento della pagina, y verso il basso).
-- Restituisce i rettangoli attivi, quelli vietati e la portata delle chiazze d'angolo.
function M.region(set, TXT, W, H)
  local rx, ry = .42 * W, .30 * H
  local R = {}
  if set.top then R[#R+1] = { 0, 0, W, TXT.y0 } end
  if set.bottom then R[#R+1] = { 0, TXT.y1, W, H } end
  if set.left then R[#R+1] = { 0, 0, TXT.x0, H } end
  if set.right then R[#R+1] = { TXT.x1, 0, W, H } end
  if set.tl then R[#R+1] = { 0, 0, rx, ry } end
  if set.tr then R[#R+1] = { W - rx, 0, W, ry } end
  if set.bl then R[#R+1] = { 0, H - ry, rx, H } end
  if set.br then R[#R+1] = { W - rx, H - ry, W, H } end
  return { set = set, rects = R, forbidden = complement(R, W, H), rx = rx, ry = ry }
end


-- Crea l'istanza di un motivo.
--   spec.name   nome del pacchetto, usato nei messaggi del log
--   spec.motif  tabella del motivo (opts, draw)
-- Restituisce un oggetto con opts, set(chiave, valore), build(...), page(...), enabled.
--
-- draw(ctx) riceve (coordinate in bp, origine in alto a sinistra, y verso il basso):
--   ctx.opts            tutte le opzioni (comuni e del motivo)
--   ctx.W, ctx.H        dimensioni della pagina; ctx.s fattore di scala (1 senza autoscale)
--   ctx.ri, ctx.cl      anello esterno (15 bp x s) e distanza dal testo (clear x s)
--   ctx.TXT             area riservata al testo {x0, y0, x1, y1}, già allargata di cl
--   ctx.reg, ctx.set    zone attive (where) e relativi lati/angoli; nil con where=all
--   ctx.c1, ctx.c2      i due angoli di crescita scelti; ctx.clist, ctx.corners
--   ctx.rs, ctx.rd      sequenze casuali: struttura (condivisa dalla coppia di pagine in
--                       fronte/retro) e dettagli (per pagina)
--   ctx.sseed, ctx.dseed  i semi di quelle due sequenze, per chi vuole un generatore proprio
--   ctx.dens(x, y)      densità del disegno nel punto (cresce dagli angoli); ogni chiamata
--                       aggiunge un po' di rumore e consuma ctx.rd
--   ctx.dens0(x, y)     la stessa densità, liscia e senza rumore (non consuma numeri casuali)
--   ctx.EX              rettangoli {x0, y0, x1, y1} dove non si disegna (testo, zone
--                       vietate da where, alone); un motivo può aggiungerne
--   ctx.free(r), ctx.inEx(x, y, m), ctx.clip(a, b, iv), ctx.rowIv(y), ctx.colIv(x)
--                       prove e ritagli rispetto a EX
--   ctx.mirror          true sulle pagine pari in fronte/retro (lo specchio è applicato dal
--                       motore: il motivo disegna sempre come per una pagina dispari)
function M.new(spec)
  local I = { name = spec.name, motif = spec.motif, enabled = true }
  local name = spec.name

  I.opts = { seed = 1, density = 1.15, clear = 10.0, twoside = "auto", autoscale = false,
             halo = 6, where = "all" }
  for k, v in pairs(spec.motif.opts or {}) do I.opts[k] = v end

  -- Senza seed=N il seme è casuale: uno per documento, scelto al caricamento del pacchetto
  -- (un seed= nelle opzioni lo sostituisce) e scritto nel log alla prima pagina.
  I.newseed = M.newseed
  I.seed_random = true
  I.opts.seed = I.newseed()

  function I.set(key, val)
    if key == "seed" then
      local n = tonumber(val)
      if val == "random" or val == "auto" or not n then
        if val ~= "random" and val ~= "auto" then
          texio.write_nl("term and log", name .. ": seed '" .. tostring(val) ..
            "' non è un numero, uso un seme casuale")
        end
        I.opts.seed, I.seed_random = I.newseed(), true
      else
        I.opts.seed, I.seed_random = math.floor(n), false
      end
      return
    end
    if val == "true" then val = true
    elseif val == "false" then val = false
    elseif tonumber(val) then val = tonumber(val) end
    I.opts[key] = val
  end

  -- Restituisce la stringa di operatori PDF (coordinate in bp, origine in basso a sinistra)
  -- e una tabella di statistiche. tx0..ty1: area del testo, y verso il basso.
  -- info (facoltativo): twoside, mirror, ink (rettangoli d'inchiostro della pagina).
  function I.build(pg, W, H, tx0, ty0, tx1, ty1, info)
    info = info or {}
    local o = I.opts
    local mirror = info.mirror and true or false
    -- la pagina pari si costruisce nel riferimento della dispari e si specchia in uscita
    if mirror then tx0, tx1 = W - tx1, W - tx0 end

    local s = o.autoscale and M.scale(W, H, tx0, tx1) or 1
    local base0 = math.floor(o.seed) * 1000003
    local dseed = base0 + pg * 7919 + 17
    local sseed = info.twoside and (base0 + (pg // 2) * 104729 + 31) or dseed
    local rd = rng(dseed)                            -- dettagli, per pagina
    local rs = rd                                    -- struttura
    if info.twoside then rs = rng(sseed) end
    local ri = 15 * s
    local cl = o.clear * s

    -- area riservata al testo (corpo + testatina + piè di pagina), coordinate y verso il basso
    local TXT = { x0 = math.max(ri, tx0 - cl), x1 = math.min(W - ri, tx1 + cl),
                  y0 = math.max(ri, ty0 - cl), y1 = math.min(H - ri, ty1 + cl) }

    -- zone attive (opzione where); reg = nil vuol dire tutto intorno alla pagina
    local reg, set
    do
      local sw = M.parse_where(o.where, name)
      if not M.is_all(sw) then
        set = mirror and swaplr(sw) or sw
        reg = M.region(set, TXT, W, H)
      end
    end

    -- sorgenti di crescita: due angoli (asimmetrici), un punto sul bordo, due bande
    local src = {}
    local function addsrc(cx, cy, sx, sy, a) src[#src+1] = {cx, cy, sx, sy, a} end
    local corners = { {0,1}, {1,0}, {1,1}, {0,0} }
    local ckey = { [0] = { [0] = "tl", [1] = "bl" }, [1] = { [0] = "tr", [1] = "br" } }
    local function viaside(c)
      return reg and ((c[1] == 0 and set.left) or (c[1] == 1 and set.right)
                      or (c[2] == 0 and set.top) or (c[2] == 1 and set.bottom))
    end
    local function active(c) return not reg or viaside(c) or set[ckey[c[1]][c[2]]] end
    local clist = {}
    for _, c in ipairs(corners) do if active(c) then clist[#clist+1] = c end end
    local nc = #clist
    local i1 = 1 + math.floor(rs() * nc)
    local i2 = nc > 1 and ((i1 - 1) + 1 + math.floor(rs() * (nc - 1))) % nc + 1 or i1
    local c1, c2 = clist[i1], clist[i2]
    if not reg then
      addsrc(c1[1]*W, c1[2]*H, .2*W, .65*H, 1.2 + .4*rs())
      addsrc(c2[1]*W, c2[2]*H, .14*W, .42*H, .8 + .3*rs())
      addsrc((rs() < .5 and 0 or 1)*W, (.25 + .5*rs())*H, .12*W, .15*H, .5 + .2*rs())
      addsrc((.2 + .6*rs())*W, .07*H, .3*W, .035*H, .45 + .3*rs())
      addsrc((.2 + .6*rs())*W, .97*H, .3*W, .03*H, .4 + .3*rs())
    else
      -- un angolo scelto solo per nome (topleft...) ha una chiazza che sfuma entro la sua portata;
      -- un angolo che appartiene a un lato attivo cresce come nel disegno completo
      -- con meno lati le sorgenti cadono tutte nella stessa zona: ampiezze dimezzate per
      -- tenere la densità vicina a quella del disegno completo, dove si dividono su quattro lati
      local fa = .5
      local function csrc(c, strong)
        if set[ckey[c[1]][c[2]]] and not viaside(c) then
          addsrc(c[1]*W, c[2]*H, .45*reg.rx, .45*reg.ry, strong and (1.3 + .4*rs()) or (.9 + .3*rs()))
        elseif strong then addsrc(c[1]*W, c[2]*H, .2*W, .65*H, fa * (1.2 + .4*rs()))
        else addsrc(c[1]*W, c[2]*H, .14*W, .42*H, fa * (.8 + .3*rs())) end
      end
      csrc(c1, true)
      if c2 ~= c1 then csrc(c2, false) end
      for _, c in ipairs(corners) do   -- ogni angolo scelto per nome riceve la sua sorgente
        if c ~= c1 and c ~= c2 and set[ckey[c[1]][c[2]]] and not viaside(c) then csrc(c, false) end
      end
      -- una fascia debole lungo ogni lato attivo
      if set.top then addsrc((.25 + .5*rs())*W, .45*TXT.y0, .42*W, .55*TXT.y0, .25 + .2*rs()) end
      if set.bottom then addsrc((.25 + .5*rs())*W, H - .45*(H - TXT.y1), .42*W, .55*(H - TXT.y1), .2 + .2*rs()) end
      if set.left then addsrc(.45*TXT.x0, (.25 + .5*rs())*H, .55*TXT.x0, .42*H, .25 + .2*rs()) end
      if set.right then addsrc(W - .45*(W - TXT.x1), (.25 + .5*rs())*H, .55*(W - TXT.x1), .42*H, .25 + .2*rs()) end
    end

    -- densità liscia (senza rumore): per i motivi che disegnano linee continue
    local function dens0(x, y)
      local d = 0
      for _, q in ipairs(src) do
        local u, v = (x - q[1]) / q[3], (y - q[2]) / q[4]
        d = d + q[5] * math.exp(-(u*u + v*v))
      end
      return d * o.density
    end
    local function dens(x, y)
      return dens0(x, y) + (rd() - .5) * .3
    end

    local EX = { TXT }
    if reg then for _, f in ipairs(reg.forbidden) do EX[#EX+1] = f end end
    local nkeep = 0
    local halo = tonumber(o.halo) or 0
    if info.ink and halo > 0 then
      for _, z in ipairs(M.zones(info.ink, TXT, halo * s, W, mirror)) do
        EX[#EX+1] = z; nkeep = nkeep + 1
      end
    end
    local function ovl(a, b) return a.x0 < b.x1 and a.x1 > b.x0 and a.y0 < b.y1 and a.y1 > b.y0 end
    local function free(r) for _, e in ipairs(EX) do if ovl(r, e) then return false end end return true end
    local function inEx(x, y, m)
      for _, r in ipairs(EX) do
        if x > r.x0 - m and x < r.x1 + m and y > r.y0 - m and y < r.y1 + m then return true end
      end
      return false
    end
    local function clip(a, b, iv)
      local parts = { {a, b} }
      for _, w in ipairs(iv) do
        local nx = {}
        for _, q in ipairs(parts) do
          if q[2] <= w[1] or q[1] >= w[2] then nx[#nx+1] = q
          else
            if q[1] < w[1] then nx[#nx+1] = { q[1], w[1] } end
            if q[2] > w[2] then nx[#nx+1] = { w[2], q[2] } end
          end
        end
        parts = nx
      end
      return parts
    end
    local function rowIv(y)
      local t = {}
      for _, r in ipairs(EX) do if y > r.y0 - 1 and y < r.y1 + 1 then t[#t+1] = { r.x0 - 1, r.x1 + 1 } end end
      return t
    end
    local function colIv(x)
      local t = {}
      for _, r in ipairs(EX) do if x > r.x0 - 1 and x < r.x1 + 1 then t[#t+1] = { r.y0 - 1, r.y1 + 1 } end end
      return t
    end

    local ctx = { name = name, opts = o, pg = pg, W = W, H = H, s = s, ri = ri, cl = cl,
                  mirror = mirror, twoside = info.twoside, TXT = TXT, reg = reg, set = set,
                  c1 = c1, c2 = c2, clist = clist, corners = corners,
                  rs = rs, rd = rd, sseed = sseed, dseed = dseed, dens = dens, dens0 = dens0,
                  EX = EX, ovl = ovl, free = free, inEx = inEx, clip = clip,
                  rowIv = rowIv, colIv = colIv }
    local chunks = spec.motif.draw(ctx)

    local out = { "q" }
    if mirror then out[#out+1] = fmt("-1 0 0 1 %.2f 0 cm", W) end
    for _, c in ipairs(chunks) do out[#out+1] = c end
    out[#out+1] = "Q"
    return table.concat(out, "\n") .. "\n",
      { scale = s, keepout = nkeep, mirror = mirror, allowed = reg and reg.rects or nil, txt = TXT }
  end

  -- Chiamata dallo stile: dimensioni in sp, y verso il basso a partire dal bordo alto.
  -- twoside: valore di \if@twoside; box: registro di \ShipoutBox; ox, oy: sua origine.
  function I.page(pg, Wsp, Hsp, ax, ay, bx, by, twoside, box, ox, oy)
    if not I.enabled then return end
    local k = 1 / 65781.76
    local o = I.opts
    local ts = o.twoside
    if ts ~= true and ts ~= false then ts = twoside and true or false end
    if I.logged_seed ~= o.seed then
      I.logged_seed = o.seed
      texio.write_nl("term and log", I.seed_random
        and fmt("%s: seed %.0f (casuale; per riprodurlo: seed=%.0f)", name, o.seed, o.seed)
        or fmt("%s: seed %.0f (fissato)", name, o.seed))
    end
    local info = { twoside = ts, mirror = ts and pg % 2 == 0 }
    if box and (tonumber(o.halo) or 0) > 0 then
      info.ink = M.ink(box, ox, oy, k, { ax, ay, bx, by }, Wsp * Hsp)
    end
    local s, st = I.build(pg, Wsp * k, Hsp * k, ax * k, ay * k, bx * k, by * k, info)
    texio.write_nl("log", fmt("%s: pagina %d%s; scala %.3f; zone di rispetto %d", name,
      pg, st.mirror and " (pari, specchiata)" or (ts and " (dispari)" or ""), st.scale, st.keepout))
    local n = node.new("whatsit", "pdf_literal")
    n.mode = 1
    n.data = s
    node.write(n)
  end

  return I
end

-- Inchiostro della pagina: rettangoli (bp, y verso il basso dal bordo alto) di glifi,
-- filetti, immagini e riquadri grafici della scatola di uscita, esclusi quelli
-- completamente dentro l'area del testo. box: registro; ox, oy: angolo in alto
-- a sinistra della scatola in sp; area: x0, y0, x1, y1 del testo in sp;
-- pagearea: area della pagina in sp^2 (scatole grafiche più grandi del 15% ignorate).
local IDS
local RUNNING = -1073741824
function M.ink(box, ox, oy, k, area, pagearea)
  local b = tex.box[box]
  if not b then return {} end
  if not IDS then
    IDS = { glyph = node.id("glyph"), hlist = node.id("hlist"), vlist = node.id("vlist"),
            rule = node.id("rule"), glue = node.id("glue"), kern = node.id("kern"),
            disc = node.id("disc"), whatsit = node.id("whatsit"), gfx = {} }
    for i, name in pairs(node.whatsits()) do
      if name == "pdf_literal" or name == "special" or name == "pdf_save" then IDS.gfx[i] = true end
    end
  end
  local GLYPH, HLIST, VLIST, RULE, GLUE, KERN, DISC, WHATSIT =
    IDS.glyph, IDS.hlist, IDS.vlist, IDS.rule, IDS.glue, IDS.kern, IDS.disc, IDS.whatsit
  local eff = node.effective_glue
  local ax0, ay0, ax1, ay1 = area[1], area[2], area[3], area[4]
  local bigbox = (pagearea or 0) * .15
  local out = {}
  local function add(x0, y0, x1, y1)
    if x1 <= x0 or y1 <= y0 then return end
    if x0 >= ax0 and x1 <= ax1 and y0 >= ay0 and y1 <= ay1 then return end
    out[#out+1] = { x0 * k, y0 * k, x1 * k, y1 * k }
  end
  local walkh, walkv
  local function inline(head, parent, x, y)
    if not head then return x end
    for n in node.traverse(head) do
      local id = n.id
      if id == GLYPH then
        add(x, y - n.height, x + n.width, y + n.depth); x = x + n.width
      elseif id == HLIST then walkh(n, x, y + n.shift); x = x + n.width
      elseif id == VLIST then walkv(n, x, y + n.shift); x = x + n.width
      elseif id == RULE then
        local h, d = n.height, n.depth
        if h == RUNNING then h = parent.height end
        if d == RUNNING then d = parent.depth end
        add(x, y - h, x + n.width, y + d); x = x + n.width
      elseif id == GLUE then x = x + eff(n, parent)
      elseif id == KERN then x = x + n.kern
      elseif id == DISC and n.replace then x = inline(n.replace, parent, x, y)
      end
    end
    return x
  end
  local function graphic(box)
    if not box.list or box.width * (box.height + box.depth) > bigbox then return false end
    for n in node.traverse_id(WHATSIT, box.list) do
      if IDS.gfx[n.subtype] then return true end
    end
    return false
  end
  function walkh(box, x, y)
    if graphic(box) then add(x, y - box.height, x + box.width, y + box.depth) end
    inline(box.list, box, x, y)
  end
  function walkv(box, x, ybase)
    if graphic(box) then add(x, ybase - box.height, x + box.width, ybase + box.depth) end
    local y = ybase - box.height
    if not box.list then return end
    for n in node.traverse(box.list) do
      local id = n.id
      if id == HLIST then y = y + n.height; walkh(n, x + n.shift, y); y = y + n.depth
      elseif id == VLIST then y = y + n.height; walkv(n, x + n.shift, y); y = y + n.depth
      elseif id == RULE then
        local w, h, d = n.width, n.height, n.depth
        if w == RUNNING then w = box.width end
        add(x, y, x + w, y + h + d); y = y + h + d
      elseif id == GLUE then y = y + eff(n, box)
      elseif id == KERN then y = y + n.kern
      end
    end
  end
  if b.id == VLIST then walkv(b, ox, oy + b.height)
  elseif b.id == HLIST then walkh(b, ox, oy + b.height) end
  return out
end

-- Carica il file Lua di un motivo (cercato con kpse se non è un percorso) e gli passa il motore
-- come argomento: nel file, `local core = ...`.
function M.loadmotif(file)
  local f = io.open(file, "rb")
  if f then f:close() else file = (kpse and kpse.find_file(file, "lua")) or file end
  local chunk = assert(loadfile(file))
  return chunk(M)
end

return M
