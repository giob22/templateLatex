# SPDX-License-Identifier: MIT
# Copyright (c) 2026 giob22. Vedi il file LICENSE.
"""Bozze di motivi alternativi per i margini (prototipi in Python, non ancora LaTeX).
Uso:  python -I genera_bozze.py [nome ...]      (senza nomi: tutte)"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

W, H = 595.276, 841.89            # A4 in pt
RI = 14.0                         # anello esterno
TXT = (102.0, 100.0, 493.0, 740.0)    # area del testo (margini di 3,6 cm)
CL = 10.0
TX = (TXT[0] - CL, TXT[1] - CL, TXT[2] + CL, TXT[3] + CL)   # zona vietata
OUT = os.path.dirname(os.path.abspath(__file__))     # le immagini vanno accanto allo script


# ---------------------------------------------------------------- base comune
class Canvas:
    def __init__(s, k=4):
        s.k = k
        s.im = Image.new("RGB", (round(W * k), round(H * k)), "white")
        s.d = ImageDraw.Draw(s.im)

    def P(s, pts):
        return [(x * s.k, y * s.k) for x, y in pts]

    def line(s, pts, w, col):
        s.d.line(s.P(pts), fill=col, width=max(1, round(w * s.k)), joint="curve")

    def rect(s, x0, y0, x1, y1, fill=None, outline=None, w=.5):
        s.d.rectangle([x0 * s.k, y0 * s.k, x1 * s.k, y1 * s.k], fill=fill, outline=outline,
                      width=max(1, round(w * s.k)))

    def circ(s, x, y, r, fill=None, outline=None, w=.5):
        s.d.ellipse([(x - r) * s.k, (y - r) * s.k, (x + r) * s.k, (y + r) * s.k], fill=fill,
                    outline=outline, width=max(1, round(w * s.k)))

    def poly(s, pts, fill=None, outline=None, w=.4):
        p = s.P(pts)
        if fill:
            s.d.polygon(p, fill=fill)
        if outline:
            s.d.line(p + [p[0]], fill=outline, width=max(1, round(w * s.k)), joint="curve")

    def save(s, path):
        im = s.im.resize((round(W * 2), round(H * 2)), Image.LANCZOS)
        ImageDraw.Draw(im).rectangle([0, 0, im.width - 1, im.height - 1], outline="#b8b8b8")
        im.save(path)


def gblur(a, s):
    ky = np.fft.fftfreq(a.shape[0])[:, None]
    kx = np.fft.fftfreq(a.shape[1])[None, :]
    g = np.exp(-2 * (math.pi ** 2) * (s ** 2) * (kx ** 2 + ky ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def make_fields():
    ny, nx = int(H) + 1, int(W) + 1
    yy, xx = np.mgrid[0:ny, 0:nx].astype(float)
    srcs = [(0, 0, .22 * W, .60 * H, 1.35), (W, H, .22 * W, .50 * H, 1.15),
            (W, 0, .14 * W, .30 * H, .70), (0, H, .14 * W, .28 * H, .60),
            (.45 * W, 0, .30 * W, .035 * H, .45), (.55 * W, H, .30 * W, .035 * H, .40)]
    d = sum(a * np.exp(-(((xx - cx) / sx) ** 2 + ((yy - cy) / sy) ** 2)) for cx, cy, sx, sy, a in srcs)
    n = gblur(np.random.default_rng(1).standard_normal((ny, nx)), 6)
    dens = np.clip(d + n / n.std() * .12, 0, 1.6)
    free = (xx > RI) & (xx < W - RI) & (yy > RI) & (yy < H - RI)
    free &= ~((xx > TX[0]) & (xx < TX[2]) & (yy > TX[1]) & (yy < TX[3]))
    return dens, free


DENS, FREE = make_fields()


def dn(x, y):
    return float(DENS[min(max(int(y), 0), DENS.shape[0] - 1), min(max(int(x), 0), DENS.shape[1] - 1)])


def fr(x, y):
    return bool(FREE[min(max(int(y), 0), FREE.shape[0] - 1), min(max(int(x), 0), FREE.shape[1] - 1)])


def overlaps(r, e=TX):
    return r[0] < e[2] and r[2] > e[0] and r[1] < e[3] and r[3] > e[1]


def inring(r):
    return r[0] > RI and r[2] < W - RI and r[1] > RI and r[3] < H - RI


def draw_text(c, rnd):
    """Testo finto nell'area riservata."""
    x0, x1 = TXT[0], TXT[2]
    y = TXT[1] + 4
    c.rect(x0 + 60, y + 10, x1 - 60, y + 17, fill="#555555")
    c.rect(x0 + 140, y + 28, x1 - 140, y + 32, fill="#888888")
    y += 62
    while y < TXT[3] - 30:
        n = rnd.randint(5, 9)
        for i in range(n):
            if y > TXT[3] - 30:
                break
            ind = 12 if i == 0 else 0
            end = rnd.uniform(.4, .8) if i == n - 1 else 1
            c.rect(x0 + ind, y, x0 + ind + (x1 - x0 - ind) * end, y + 4.2, fill="#bdbdbd")
            y += 12.3
        y += 4
    c.rect(W / 2 - 3, TXT[3] - 12, W / 2 + 3, TXT[3] - 8, fill="#999999")


# ---------------------------------------------------------------- 1. PCB
def pcb(c, rnd):
    p = 4.4
    nx, ny = int(W / p) + 2, int(H / p) + 2
    ii, jj = np.meshgrid(np.arange(nx), np.arange(ny))
    blocked = ~FREE[np.clip((jj * p).astype(int), 0, FREE.shape[0] - 1),
                    np.clip((ii * p).astype(int), 0, FREE.shape[1] - 1)]
    occ = [np.zeros((ny, nx), bool), np.zeros((ny, nx), bool)]
    DIRS = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
    TR = [("#1f7a52", 1.5), ("#7db89a", 1.1)]
    GOLD = "#c9a24b"
    segs, vias, ends = [[], []], [], []

    def fc(i, j, L):
        return 0 <= i < nx and 0 <= j < ny and not blocked[j, i] and not occ[L][j, i]

    def walk(i, j, d, L, steer, maxlen):
        pts = [(i, j)]
        occ[L][j, i] = True
        for _ in range(maxlen):
            r = steer.random()
            order = ([(d + 1) % 8, d, (d - 1) % 8] if r < .10 else
                     [(d - 1) % 8, d, (d + 1) % 8] if r < .20 else [d, (d + 1) % 8, (d - 1) % 8])
            for dd in order:
                di, dj = DIRS[dd]
                ni, nj = i + di, j + dj
                if not fc(ni, nj, L):
                    continue
                if di and dj and (occ[L][j, ni] or occ[L][nj, i]):
                    continue
                d = dd
                break
            else:
                break
            if di and dj:
                occ[L][j, ni] = True
                occ[L][nj, i] = True
            i, j = ni, nj
            occ[L][j, i] = True
            pts.append((i, j))
            if rnd.random() > min(.985, .50 + dn(i * p, j * p) * .62):
                break
            if rnd.random() < .012 and fc(i, j, 1 - L):
                segs[L].append(pts)
                vias.append((i * p, j * p))
                L = 1 - L
                occ[L][j, i] = True
                pts = [(i, j)]
        segs[L].append(pts)
        if len(pts) > 5 and rnd.random() < .4:
            ends.append((pts[-1][0] * p, pts[-1][1] * p))

    # fori di montaggio
    holes = []
    for (hx, hy) in ((RI + 9, RI + 9), (W - RI - 9, H - RI - 9)):
        holes.append((hx, hy))
        for j in range(ny):
            for i in range(nx):
                if (i * p - hx) ** 2 + (j * p - hy) ** 2 < 12 ** 2:
                    blocked[j, i] = True

    # circuiti integrati con le piste che escono dai piedini
    ics = []
    for _ in range(1500):
        if len(ics) >= 8:
            break
        n = rnd.choice([5, 6, 7])
        s = n * p
        x = round(rnd.uniform(RI + 8, W - RI - 8 - s) / p) * p
        y = round(rnd.uniform(RI + 8, H - RI - 8 - s) / p) * p
        r = (x - 6, y - 6, x + s + 6, y + s + 6)
        if overlaps(r) or not inring(r) or rnd.random() > dn(x + s / 2, y + s / 2) * .9:
            continue
        if any(overlaps(r, (q[0] - 8, q[1] - 8, q[2] + 8, q[3] + 8)) for q in ics):
            continue
        ics.append((x, y, x + s, y + s, n))
    for (x0, y0, x1, y1, n) in ics:
        for j in range(ny):
            for i in range(nx):
                if x0 - 1 <= i * p <= x1 + 1 and y0 - 1 <= j * p <= y1 + 1:
                    occ[0][j, i] = occ[1][j, i] = True
        for side in range(4):
            seed = rnd.random()
            L = 0 if rnd.random() < .6 else 1
            for k in range(1, n):
                if side == 0:
                    pi, pj, d = int(round((x0 + k * p) / p)), int(round(y0 / p)) - 1, 6
                elif side == 1:
                    pi, pj, d = int(round((x0 + k * p) / p)), int(round(y1 / p)) + 1, 2
                elif side == 2:
                    pi, pj, d = int(round(x0 / p)) - 1, int(round((y0 + k * p) / p)), 4
                else:
                    pi, pj, d = int(round(x1 / p)) + 1, int(round((y0 + k * p) / p)), 0
                if fc(pi, pj, L) and rnd.random() < .93:
                    walk(pi, pj, d, L, random.Random(seed), rnd.randint(14, 70))

    # piste libere, spesso a fasci paralleli
    for _ in range(5000):
        i, j = rnd.randrange(nx), rnd.randrange(ny)
        if blocked[j, i] or rnd.random() > dn(i * p, j * p) * .5:
            continue
        L = 0 if rnd.random() < .6 else 1
        d = rnd.choice([0, 2, 4, 6, 0, 2, 4, 6, 1, 3, 5, 7])
        di, dj = DIRS[d]
        nb = rnd.randint(3, 6) if (not (di and dj) and rnd.random() < .3) else 1
        seed = rnd.random()
        for b in range(nb):
            ni, nj = i + (-dj) * b, j + di * b
            if fc(ni, nj, L):
                walk(ni, nj, d, L, random.Random(seed), rnd.randint(8, 60))

    # componenti SMD (resistenze e condensatori)
    comps = []
    for _ in range(900):
        i, j = rnd.randrange(nx - 3), rnd.randrange(ny - 3)
        if dn(i * p, j * p) < .3 or rnd.random() > .5:
            continue
        horiz = rnd.random() < .5
        cells = [(i + a, j + b) for a in range(3 if horiz else 2) for b in range(2 if horiz else 3)]
        if all(fc(a, b, 0) and fc(a, b, 1) for a, b in cells):
            for a, b in cells:
                occ[0][b, a] = occ[1][b, a] = True
            comps.append((i * p, j * p, horiz))

    # riempimento di rame a tratteggio nelle zone povere
    hatch = []
    for j in range(ny):
        for i in range(nx):
            if not blocked[j, i] and not occ[0][j, i] and not occ[1][j, i] and dn(i * p, j * p) < .5 \
                    and rnd.random() < .3:
                hatch.append((i * p, j * p))

    for (x, y) in hatch:
        c.line([(x - 1.4, y + 1.4), (x + 1.4, y - 1.4)], .45, "#bad8c8")
    for L in (1, 0):
        col, w = TR[L]
        for pts in segs[L]:
            if len(pts) > 1:
                c.line([(a * p, b * p) for a, b in pts], w, col)
    for (x, y) in vias:
        c.circ(x, y, 2.0, fill=GOLD)
        c.circ(x, y, .8, fill="white")
    for (x, y) in ends:
        c.circ(x, y, 1.9, fill=GOLD)
        c.circ(x, y, .7, fill="white")
    for (x, y, h) in comps:
        bw, bh = (8.8, 4.4) if h else (4.4, 8.8)
        c.rect(x, y, x + bw, y + bh, fill="#2f3438")
        if h:
            c.rect(x - .8, y, x + 1.6, y + bh, fill=GOLD)
            c.rect(x + bw - 1.6, y, x + bw + .8, y + bh, fill=GOLD)
        else:
            c.rect(x, y - .8, x + bw, y + 1.6, fill=GOLD)
            c.rect(x, y + bh - 1.6, x + bw, y + bh + .8, fill=GOLD)
        c.rect(x + 1, y - 3.2 if h else y + bh + 1.5, x + 6, (y - 2) if h else (y + bh + 2.6), fill="#9aa39e")
    for (x0, y0, x1, y1, n) in ics:
        c.rect(x0, y0, x1, y1, fill="#2b2f33", outline="#555b60", w=.5)
        c.circ(x0 + 3, y0 + 3, 1.1, fill="#d8d8d8")
        for k in range(1, n):
            for (px, py, vert) in ((x0 + k * p, y0, 1), (x0 + k * p, y1, 1), (x0, y0 + k * p, 0), (x1, y0 + k * p, 0)):
                if vert:
                    c.rect(px - .55, py - 2.6 if py == y0 else py, px + .55, py if py == y0 else py + 2.6, fill=GOLD)
                else:
                    c.rect(px - 2.6 if px == x0 else px, py - .55, px if px == x0 else px + 2.6, py + .55, fill=GOLD)
    for (x, y) in holes:
        c.circ(x, y, 6.2, fill=GOLD)
        c.circ(x, y, 3.2, fill="white")
    c.d.rounded_rectangle([(RI - 6) * c.k, (RI - 6) * c.k, (W - RI + 6) * c.k, (H - RI + 6) * c.k],
                          radius=14 * c.k, outline="#1f7a52", width=round(1.1 * c.k))


# ---------------------------------------------------------------- 2. albero di clock
def clock(c, rnd):
    BL, LB, OR = "#1d4f9f", "#5f8fd6", "#d9822b"
    ytop, ybot = (RI + TX[1]) / 2, (TX[3] + H - RI) / 2
    xl, xr = (RI + TX[0]) / 2, (TX[2] + W - RI) / 2
    mt, mb = (TX[1] - RI) / 2 - 4, (H - RI - TX[3]) / 2 - 4
    ml, mr = (TX[0] - RI) / 2 - 4, (W - RI - TX[2]) / 2 - 4
    ft, fl, fb, fr_ = .60, .58, .62, .60
    lx, ly = xr - xl, ybot - ytop
    spines = [((xl, ytop), (xl + ft * lx, ytop), mt), ((xr, ytop), (xr - (1 - ft - .03) * lx, ytop), mt),
              ((xl, ytop), (xl, ytop + fl * ly), ml), ((xl, ybot), (xl, ybot - (1 - fl - .03) * ly), ml),
              ((xr, ybot), (xr - fb * lx, ybot), mb), ((xl, ybot), (xl + (1 - fb - .03) * lx, ybot), mb),
              ((xr, ybot), (xr, ybot - fr_ * ly), mr), ((xr, ytop), (xr, ytop + (1 - fr_ - .03) * ly), mr)]
    sinks = []
    for (a, b, hw) in spines:
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        u = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
        n = (-u[1], u[0])
        t = 22 + rnd.uniform(0, 4)
        while t < L - 6:
            pt = (a[0] + u[0] * t, a[1] + u[1] * t)
            for side in (-1, 1):
                if rnd.random() < min(.97, dn(*pt) * 1.15 + .15):
                    lb = hw * rnd.uniform(.55, 1.0)
                    e = (pt[0] + n[0] * side * lb, pt[1] + n[1] * side * lb)
                    if rnd.random() < .25:        # meandro per pareggiare i ritardi
                        pts, q = [pt], 4.0
                        sgn = 1
                        while q < lb - 3:
                            pts.append((pt[0] + n[0] * side * q + u[0] * 2.4 * sgn, pt[1] + n[1] * side * q + u[1] * 2.4 * sgn))
                            sgn = -sgn
                            q += 3.2
                        pts.append(e)
                        c.line(pts, .7, LB)
                    else:
                        c.line([pt, e], .8, LB)
                    s1 = (e[0] - u[0] * 4, e[1] - u[1] * 4)
                    s2 = (e[0] + u[0] * 4, e[1] + u[1] * 4)
                    c.line([s1, s2], .5, LB)
                    sinks += [s1, s2]
            t += rnd.uniform(11, 15)
        # dorsale con spessore decrescente
        steps = max(1, int(L // 6))
        for k in range(steps):
            q0, q1 = k / steps, (k + 1) / steps
            c.line([(a[0] + u[0] * L * q0, a[1] + u[1] * L * q0), (a[0] + u[0] * L * q1, a[1] + u[1] * L * q1)],
                   1.9 - 1.0 * q0, BL)
        tb = 40 + rnd.uniform(0, 20)
        while tb < L - 10:      # buffer
            pt = (a[0] + u[0] * tb, a[1] + u[1] * tb)
            c.poly([(pt[0] - n[0] * 3.2, pt[1] - n[1] * 3.2), (pt[0] + n[0] * 3.2, pt[1] + n[1] * 3.2),
                    (pt[0] + u[0] * 5.5, pt[1] + u[1] * 5.5)], fill=BL)
            tb += rnd.uniform(62, 85)
        tg = 95 + rnd.uniform(0, 30)
        while tg < L - 20:      # clock gating
            pt = (a[0] + u[0] * tg, a[1] + u[1] * tg)
            hw_, hh_ = (6, 3.4) if abs(u[0]) > .5 else (3.4, 6)
            c.rect(pt[0] - hw_, pt[1] - hh_, pt[0] + hw_, pt[1] + hh_, fill="white", outline=BL, w=.7)
            tg += rnd.uniform(110, 150)
    for (sx, sy) in sinks:
        c.rect(sx - 1.2, sy - 1.2, sx + 1.2, sy + 1.2, fill=OR)
    for (hx, hy, s) in ((xl, ytop, 13), (xr, ybot, 13), (xr, ytop, 8), (xl, ybot, 8)):    # PLL
        c.rect(hx - s, hy - s, hx + s, hy + s, fill="white", outline=BL, w=1.1)
        c.circ(hx, hy, s * .5, outline=BL, w=.8)
        c.line([(hx - s * .3, hy), (hx - s * .1, hy - s * .3), (hx + s * .1, hy + s * .3), (hx + s * .3, hy)], .7, OR)


# ---------------------------------------------------------------- 3. FPGA
def fpga(c, rnd):
    t, g = 20.0, 8.0
    pitch = t + g
    x0, y0 = RI + 2, RI + 2
    cols, rows = int((W - 2 * RI - 4) // pitch), int((H - 2 * RI - 4) // pitch)
    SL = "#7a8fb3"
    pres = {}
    for j in range(rows):
        for i in range(cols):
            x, y = x0 + i * pitch, y0 + j * pitch
            r = (x - 1, y - 1, x + t + 1, y + t + 1)
            if overlaps(r) or not inring((x, y, x + t, y + t)):
                continue
            if rnd.random() > min(1, dn(x + t / 2, y + t / 2) * 1.05):
                continue
            typ = ("io" if i in (0, cols - 1) or j in (0, rows - 1) else "bram" if i % 7 == 3
                   else "dsp" if i % 11 == 6 else "clb")
            pres[(i, j)] = typ
    # canali di instradamento
    for j in range(rows):
        i = 0
        while i < cols:
            if (i, j) in pres:
                k = i
                while (k + 1, j) in pres:
                    k += 1
                for f in (.25, .5, .75):
                    yy = y0 + j * pitch + t + g * f
                    c.line([(x0 + i * pitch, yy), (x0 + k * pitch + t, yy)], .45, SL)
                i = k + 1
            else:
                i += 1
    for i in range(cols):
        j = 0
        while j < rows:
            if (i, j) in pres:
                k = j
                while (i, k + 1) in pres:
                    k += 1
                for f in (.25, .5, .75):
                    xx = x0 + i * pitch + t + g * f
                    c.line([(xx, y0 + j * pitch), (xx, y0 + k * pitch + t)], .45, SL)
                j = k + 1
            else:
                j += 1
    for (i, j), typ in pres.items():
        x, y = x0 + i * pitch, y0 + j * pitch
        if typ == "clb":
            c.rect(x, y, x + t, y + t, fill="#e8effb", outline="#6b86b8", w=.6)
            for a in (0, 1):
                for b in (0, 1):
                    c.rect(x + 3 + a * 7.2, y + 3 + b * 7.2, x + 7 + a * 7.2, y + 7 + b * 7.2, fill="#a9bde6")
        elif typ == "bram":
            c.rect(x, y, x + t, y + t, fill="#fbeedd", outline="#c58a3b", w=.6)
            for k in range(1, 7):
                c.line([(x + 2, y + k * 2.7), (x + t - 2, y + k * 2.7)], .35, "#d9a460")
        elif typ == "dsp":
            c.rect(x, y, x + t, y + t, fill="#e6f3e9", outline="#4f9a6a", w=.6)
            c.line([(x + 3, y + 3), (x + t - 3, y + t - 3)], .5, "#79b48d")
            c.line([(x + t - 3, y + 3), (x + 3, y + t - 3)], .5, "#79b48d")
            c.circ(x + t / 2, y + t / 2, 3, outline="#4f9a6a", w=.5)
        else:
            c.rect(x + 3, y + 3, x + t - 3, y + t - 3, fill="#efe3bd", outline="#b79a3c", w=.6)
    for (i, j) in pres:      # switch box
        x, y = x0 + i * pitch + t, y0 + j * pitch + t
        c.rect(x + 1, y + 1, x + g - 1, y + g - 1, fill="white", outline=SL, w=.45)
        c.line([(x + 1, y + 1), (x + g - 1, y + g - 1)], .35, SL)
        c.line([(x + g - 1, y + 1), (x + 1, y + g - 1)], .35, SL)


# ---------------------------------------------------------------- 4. diagrammi temporali
def timing(c, rnd):
    INK, ACC, GR, LAB = "#1e3a8a", "#d9822b", "#d7dcea", "#9aa4bb"
    P, T, AMP = 9.5, 20.0, 3.0
    bands = [("h", RI + 5, TX[1] - 4, RI + 4, W - RI - 4), ("h", TX[3] + 4, H - RI - 5, RI + 4, W - RI - 4),
             ("v", RI + 5, TX[0] - 4, TX[1] - 2, TX[3] + 2), ("v", TX[2] + 4, W - RI - 5, TX[1] - 2, TX[3] + 2)]

    def pt(o, u, v):
        return (u, v) if o == "h" else (v, u)

    for (o, v0, v1, u0, u1) in bands:
        n = int((v1 - v0) / P)
        off = (v1 - v0 - n * P) / 2
        ph = rnd.uniform(0, T)
        ug = u0 + ph
        while ug < u1:    # griglia dei fronti di clock
            if dn(*pt(o, ug, (v0 + v1) / 2)) > .3:
                c.line([pt(o, ug, v0 - 1), pt(o, ug, v1 + 1)], .3, GR)
            ug += T
        for k in range(n):
            v = v0 + off + (k + .5) * P
            kind = "clock" if k == 0 else rnd.choice(["data", "data", "bus", "bus", "pulse", "div"])
            acc = rnd.random() < .1
            col, w = (ACC, 1.0) if acc else (INK, .75)
            th = (.14 + rnd.uniform(0, .10)) if o == "h" else (.36 + rnd.uniform(0, .22))
            runs, cur = [], None
            u = u0
            while u < u1:
                if dn(*pt(o, u, v)) > th:
                    cur = [u, u] if cur is None else cur
                    cur[1] = u
                elif cur is not None:
                    runs.append(cur)
                    cur = None
                u += 3
            if cur:
                runs.append(cur)
            first = True
            for (a, b) in runs:
                a = u0 + ph + math.ceil((a - u0 - ph) / (T / 2)) * (T / 2)
                b = u0 + ph + math.floor((b - u0 - ph) / (T / 2)) * (T / 2)
                if b - a < T:
                    continue
                if first:
                    c.line([pt(o, a - 11, v), pt(o, a - 3, v)], 1.0, LAB)
                    first = False
                lv = rnd.randint(0, 1)
                edges = []
                e = a
                if kind == "bus":
                    pts_top, pts_bot = [], []
                    while e < b:
                        ln = min(b - e, rnd.choice([2, 3, 4, 6]) * T / 2)
                        s0, s1 = e, e + ln
                        poly = [pt(o, s0 + 1.8, v - AMP), pt(o, s1 - 1.8, v - AMP), pt(o, s1, v), pt(o, s1 - 1.8, v + AMP),
                                pt(o, s0 + 1.8, v + AMP), pt(o, s0, v)]
                        c.poly(poly, fill="#eef1fa", outline=col, w=w)
                        if ln > 14:
                            c.line([pt(o, s0 + 5, v), pt(o, s0 + 5 + min(ln - 10, rnd.uniform(4, 9)), v)], .5, LAB)
                        e = s1
                    continue
                pts = []
                while e < b:
                    if kind == "clock":
                        lv = 1 - lv
                    elif kind == "div":
                        lv = lv if int((e - a) / (T / 2)) % 2 else 1 - lv
                    elif kind == "data":
                        lv = 1 - lv if rnd.random() < .45 else lv
                    else:
                        lv = 1 if (rnd.random() < .12) else 0
                    pts.append((e, lv))
                    e += T / 2
                path = []
                prev = None
                for (uu, l) in pts:
                    vv = v - AMP if l else v + AMP
                    if prev is not None:
                        path.append(pt(o, uu, prev))
                    path.append(pt(o, uu, vv))
                    prev = vv
                if prev is not None:
                    path.append(pt(o, b, prev))
                if len(path) > 1:
                    c.line(path, w, col)


# ---------------------------------------------------------------- 5. wafer
def wafer(c, rnd):
    for (cx, cy, R) in ((38, 44, 215), (W - 30, H - 36, 195), (W - 24, 30, 125), (28, H - 44, 135)):
        dw, dh = 11.5, 14.5
        sx, sy = cx + R * .35, cy + R * .45          # chiazza di difetti
        n = int(R / dw) + 2
        m = int(R / dh) + 2
        for gx in range(-n, n + 1):
            for gy in range(-m, m + 1):
                x0, y0 = cx + gx * dw - dw / 2, cy + gy * dh - dh / 2
                x1, y1 = x0 + dw, y0 + dh
                r = (x0, y0, x1, y1)
                if overlaps(r) or not inring(r):
                    continue
                cs = [(x0, y0), (x1, y0), (x0, y1), (x1, y1)]
                dmax = max(math.hypot(a - cx, b - cy) for a, b in cs)
                dmin = min(math.hypot(a - cx, b - cy) for a, b in cs)
                if dmin > R:
                    continue
                if dmax > R - 5:
                    c.rect(x0 + .35, y0 + .35, x1 - .35, y1 - .35, fill="#ececec", outline="#a8a8a8", w=.3)
                    continue
                dc = math.hypot((x0 + x1) / 2 - cx, (y0 + y1) / 2 - cy) / R
                pb = .04 + .30 * dc ** 2 + (.75 if math.hypot((x0 + x1) / 2 - sx, (y0 + y1) / 2 - sy) < 30 else 0)
                q = rnd.random()
                if q < pb:
                    c.rect(x0 + .35, y0 + .35, x1 - .35, y1 - .35, fill="#f3cbc6", outline="#c0584c", w=.3)
                elif q < pb + .10:
                    c.rect(x0 + .35, y0 + .35, x1 - .35, y1 - .35, fill="#f5e6b8", outline="#b89a3c", w=.3)
                else:
                    shade = rnd.choice(["#cfe8d7", "#bfe0cb", "#d8eddc", "#a9d6b8"])
                    c.rect(x0 + .35, y0 + .35, x1 - .35, y1 - .35, fill=shade, outline="#5d8f6d", w=.3)
        pts, cur = [], []
        for a in range(0, 3601):
            ang = math.radians(a / 10)
            x, y = cx + R * math.cos(ang), cy + R * math.sin(ang)
            if fr(x, y):
                cur.append((x, y))
            else:
                if len(cur) > 1:
                    pts.append(cur)
                cur = []
        if len(cur) > 1:
            pts.append(cur)
        for seg in pts:
            c.line(seg, 1.4, "#3b3b3b")
        inner, cur2 = [], []
        for a in range(0, 3601, 2):          # anello di esclusione ai bordi
            ang = math.radians(a / 10)
            x, y = cx + (R - 4) * math.cos(ang), cy + (R - 4) * math.sin(ang)
            if fr(x, y):
                cur2.append((x, y))
            else:
                if len(cur2) > 1:
                    inner.append(cur2)
                cur2 = []
        if len(cur2) > 1:
            inner.append(cur2)
        for seg in inner:
            c.line(seg, .4, "#8a8a8a")


# ---------------------------------------------------------------- 6. curve di livello
TABLE = {1: [(3, 0)], 2: [(0, 1)], 3: [(3, 1)], 4: [(1, 2)], 5: [(3, 0), (1, 2)], 6: [(0, 2)], 7: [(3, 2)],
         8: [(3, 2)], 9: [(0, 2)], 10: [(0, 1), (3, 2)], 11: [(1, 2)], 12: [(3, 1)], 13: [(0, 1)], 14: [(3, 0)]}


def contour_segments(z, level):
    b = z >= level
    v00, v10, v11, v01 = b[:-1, :-1], b[:-1, 1:], b[1:, 1:], b[1:, :-1]
    code = v00 * 1 + v10 * 2 + v11 * 4 + v01 * 8
    ys, xs = np.nonzero((code > 0) & (code < 15))
    if len(ys) == 0:
        return []
    z00, z10, z11, z01 = z[ys, xs], z[ys, xs + 1], z[ys + 1, xs + 1], z[ys + 1, xs]
    cd = code[ys, xs]
    with np.errstate(divide="ignore", invalid="ignore"):
        t0 = (level - z00) / (z10 - z00)
        t1 = (level - z10) / (z11 - z10)
        t2 = (level - z01) / (z11 - z01)
        t3 = (level - z00) / (z01 - z00)
    E = [np.stack([xs + t0, ys + 0.0], 1), np.stack([xs + 1.0, ys + t1], 1),
         np.stack([xs + t2, ys + 1.0], 1), np.stack([xs + 0.0, ys + t3], 1)]
    out = []
    for cs, lst in TABLE.items():
        m = cd == cs
        if not m.any():
            continue
        for (ea, eb) in lst:
            out.append((E[ea][m], E[eb][m]))
    return out


def topo(c, rnd):
    ny, nx = int(H) + 1, int(W) + 1
    r = np.random.default_rng(5)
    z = np.zeros((ny, nx))
    for s, a in ((90, 1.0), (45, .5), (22, .22), (11, .08)):
        nn = gblur(r.standard_normal((ny, nx)), s)
        z += a * nn / nn.std()
    yy, xx = np.mgrid[0:ny, 0:nx]
    for (cx, cy, s, a) in ((60, 70, 140, 2.6), (W - 50, H - 60, 130, 2.4), (W - 30, 60, 80, 1.3), (40, H - 80, 90, 1.2)):
        z += a * np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * s * s)))
    sp = (z.max() - z.min()) / 40
    levels = np.arange(z.min() + sp, z.max(), sp)
    for li, L in enumerate(levels):
        idx = (li % 5 == 0)
        off = rnd.uniform(0, .22)
        for (A, B) in contour_segments(z, L):
            mid = (A + B) / 2
            mx = np.clip(mid[:, 0].astype(int), 0, nx - 1)
            my = np.clip(mid[:, 1].astype(int), 0, ny - 1)
            keep = FREE[my, mx] & (DENS[my, mx] > .10 + off)
            for a, b in zip(A[keep], B[keep]):
                c.line([tuple(a), tuple(b)], .85 if idx else .42, "#8a5226" if idx else "#b0793f")
    # quote dei picchi
    for (cx, cy) in ((60, 70), (W - 50, H - 60)):
        if fr(cx, cy):
            c.line([(cx - 3, cy), (cx + 3, cy)], .6, "#6b3d1b")
            c.line([(cx, cy - 3), (cx, cy + 3)], .6, "#6b3d1b")


# ---------------------------------------------------------------- 7. radici / vene
def roots(c, rnd):
    rng = np.random.default_rng(11)
    pts = []
    while len(pts) < 9000:
        x, y = rng.uniform(RI, W - RI), rng.uniform(RI, H - RI)
        if fr(x, y) and rng.random() < min(1, dn(x, y)) ** 1.2:
            pts.append((x, y))
    A = np.array(pts)
    R_, KD, D = 30.0, 6.5, 2.8
    N = np.zeros((40000, 2))
    par = np.full(40000, -1)
    seeds = [(RI + 22, RI + 22), (W - RI - 22, H - RI - 22), (W - RI - 22, RI + 22), (RI + 22, H - RI - 22),
             (RI + 8, H * .5), (W - RI - 8, H * .45), (W * .5, RI + 8), (W * .55, H - RI - 8)]
    cnt = 0
    for s in seeds:
        N[cnt] = s
        cnt += 1
    best_d = np.full(len(A), np.inf)
    best_n = np.zeros(len(A), int)
    alive = np.ones(len(A), bool)

    def upd(lo, hi):
        d = np.linalg.norm(A[:, None, :] - N[None, lo:hi, :], axis=2)
        k = d.argmin(1)
        dm = d[np.arange(len(A)), k]
        m = dm < best_d
        best_d[m] = dm[m]
        best_n[m] = k[m] + lo

    upd(0, cnt)
    for it in range(1200):
        act = alive & (best_d < R_)
        if not act.any():
            break
        idx = np.nonzero(act)[0]
        ni = best_n[idx]
        vec = A[idx] - N[ni]
        vec /= np.linalg.norm(vec, axis=1, keepdims=True) + 1e-9
        sums = np.zeros((cnt, 2))
        np.add.at(sums, ni, vec)
        lo = cnt
        for n in np.unique(ni):
            dv = sums[n] / (np.linalg.norm(sums[n]) + 1e-9)
            q = N[n] + D * dv + rng.normal(0, .25, 2)
            if fr(*q) and cnt < len(N):
                N[cnt] = q
                par[cnt] = n
                cnt += 1
        if cnt == lo:
            alive[idx] = False
            continue
        upd(lo, cnt)
        kill = best_d < KD
        alive &= ~kill
        best_d[kill] = np.inf
    size = np.ones(cnt)
    for i in range(cnt - 1, -1, -1):
        if par[i] >= 0:
            size[par[i]] += size[i]
    for i in range(cnt):
        if par[i] < 0:
            continue
        s = size[i]
        w = min(3.0, .32 + .075 * s ** .55)
        col = "#1d3f5c" if s > 60 else "#2f6f8f" if s > 12 else "#5aa0b8"
        c.line([tuple(N[par[i]]), tuple(N[i])], w, col)
    child = np.zeros(cnt, int)
    for i in range(cnt):
        if par[i] >= 0:
            child[par[i]] += 1
    for i in range(cnt):
        if par[i] >= 0 and child[i] == 0 and rnd.random() < .5:
            d = N[i] - N[par[i]]
            d /= np.linalg.norm(d) + 1e-9
            nrm = np.array([-d[1], d[0]])
            L_, Wd = 7.5, 2.4
            tip = N[i] + d * L_
            mid = N[i] + d * L_ * .5
            c.poly([tuple(N[i]), tuple(mid + nrm * Wd), tuple(tip), tuple(mid - nrm * Wd)],
                   fill=rnd.choice(["#a9d3e0", "#bfe0e8", "#8fc2d4"]), outline="#3a7a94", w=.3)


# ---------------------------------------------------------------- 8. mappa stradale
def clip_hp(poly, a, b, cc):
    out = []
    n = len(poly)
    for k in range(n):
        p, q = poly[k], poly[(k + 1) % n]
        fp, fq = a * p[0] + b * p[1] - cc, a * q[0] + b * q[1] - cc
        if fp <= 0:
            out.append(p)
        if fp * fq < 0:
            t = fp / (fp - fq)
            out.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
    return out


def inset(poly, d):
    cen = (sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly))
    out = poly
    for k in range(len(poly)):
        p, q = poly[k], poly[(k + 1) % len(poly)]
        ex, ey = q[0] - p[0], q[1] - p[1]
        L = math.hypot(ex, ey)
        if L < 1e-6:
            continue
        nx_, ny_ = ey / L, -ex / L
        if nx_ * (cen[0] - p[0]) + ny_ * (cen[1] - p[1]) > 0:
            nx_, ny_ = -nx_, -ny_
        out = clip_hp(out, nx_, ny_, nx_ * p[0] + ny_ * p[1] - d)
        if len(out) < 3:
            return []
    return out


def poly_hits_rect(poly, r):
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    if max(xs) < r[0] or min(xs) > r[2] or max(ys) < r[1] or min(ys) > r[3]:
        return False
    rc = [(r[0], r[1]), (r[2], r[1]), (r[2], r[3]), (r[0], r[3])]
    for shape in (poly, rc):
        for k in range(len(shape)):
            p, q = shape[k], shape[(k + 1) % len(shape)]
            ax, ay = q[1] - p[1], p[0] - q[0]
            pa = [ax * v[0] + ay * v[1] for v in poly]
            pb = [ax * v[0] + ay * v[1] for v in rc]
            if max(pa) < min(pb) or max(pb) < min(pa):
                return False
    return True


def streets(c, rnd):
    # fiume lungo i margini
    ctrl = [(W - 45, -10), (W - 52, 200), (W - 40, 420), (W - 62, 620), (W - 125, 790), (250, H - 44), (-10, H - 58)]
    river = []
    for k in range(len(ctrl) - 1):
        for s in range(0, 21):
            t = s / 20
            river.append(((1 - t) * ctrl[k][0] + t * ctrl[k + 1][0], (1 - t) * ctrl[k][1] + t * ctrl[k + 1][1]))
    for _ in range(3):
        river = [river[0]] + [((river[i - 1][0] + 2 * river[i][0] + river[i + 1][0]) / 4,
                               (river[i - 1][1] + 2 * river[i][1] + river[i + 1][1]) / 4) for i in range(1, len(river) - 1)] + [river[-1]]
    pr = [p for p in river if fr(*p)]
    # semi: distanza locale più piccola dove la densità è alta
    seeds = []
    for _ in range(40000):
        if len(seeds) >= 1100:
            break
        x, y = rnd.uniform(RI - 4, W - RI + 4), rnd.uniform(RI - 4, H - RI + 4)
        if overlaps((x - 18, y - 18, x + 18, y + 18)):
            continue
        d = dn(x, y)
        if rnd.random() > min(1, d * 1.1 + .1):
            continue
        r_loc = 9 + 26 * (1 - min(1, d))
        if seeds:
            S = np.array(seeds)
            if np.min((S[:, 0] - x) ** 2 + (S[:, 1] - y) ** 2) < r_loc * r_loc:
                continue
        seeds.append((x, y))
    S = np.array(seeds)
    cells = []
    for k, (x, y) in enumerate(seeds):
        dist = (S[:, 0] - x) ** 2 + (S[:, 1] - y) ** 2
        near = np.argsort(dist)[1:18]
        poly = [(x - 70, y - 70), (x + 70, y - 70), (x + 70, y + 70), (x - 70, y + 70)]
        for j in near:
            nx_, ny_ = S[j]
            a, b = nx_ - x, ny_ - y
            poly = clip_hp(poly, a, b, (nx_ * nx_ + ny_ * ny_ - x * x - y * y) / 2)
            if len(poly) < 3:
                break
        if len(poly) < 3:
            continue
        for (a, b, cc) in ((1, 0, W - RI), (-1, 0, -RI), (0, 1, H - RI), (0, -1, -RI)):
            poly = clip_hp(poly, a, b, cc)
            if len(poly) < 3:
                break
        if len(poly) < 3 or poly_hits_rect(poly, TX):
            continue
        cells.append(poly)
    if pr:
        c.line(pr, 9.5, "#bcd8ec")
        c.line(pr, 6, "#cfe4f3")
    rv = np.array(pr) if pr else None
    COL = ["#e3dfd6", "#d9d5ca", "#e8e2d2", "#d7ddd0"]
    verts = {}

    def key(p):
        return (round(p[0] * 2) / 2, round(p[1] * 2) / 2)

    for poly in cells:
        cen = (sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly))
        if rv is not None and np.min(np.hypot(rv[:, 0] - cen[0], rv[:, 1] - cen[1])) < 11:
            continue
        for k in range(len(poly)):
            a, b = key(poly[k]), key(poly[(k + 1) % len(poly)])
            ring = ((abs(a[0] - RI) < .8 and abs(b[0] - RI) < .8) or (abs(a[0] - (W - RI)) < .8 and abs(b[0] - (W - RI)) < .8)
                    or (abs(a[1] - RI) < .8 and abs(b[1] - RI) < .8) or (abs(a[1] - (H - RI)) < .8 and abs(b[1] - (H - RI)) < .8))
            if ring:
                continue       # i tagli sul bordo della pagina non sono strade
            verts.setdefault(a, set()).add(b)
            verts.setdefault(b, set()).add(a)
        ins = inset(poly, 2.1)
        if len(ins) < 3:
            continue
        area = abs(sum(ins[k][0] * ins[(k + 1) % len(ins)][1] - ins[(k + 1) % len(ins)][0] * ins[k][1]
                       for k in range(len(ins)))) / 2
        park = rnd.random() < .06 and area > 120
        c.poly(ins, fill="#cfe3c3" if park else rnd.choice(COL), outline="#bdb7a6" if not park else "#a7c797", w=.3)
        if not park and area > 160:
            ins2 = inset(ins, 2.6)
            if len(ins2) >= 3:
                c.poly(ins2, fill=None, outline="#c6c0b0", w=.3)
    # arterie: percorsi quasi rettilinei sul grafo delle strade
    ks = [q for q in verts if len(verts[q]) >= 3]        # solo incroci veri
    starts = []
    for corner in ((RI, RI), (W - RI, H - RI), (W - RI, RI), (RI, H - RI)):
        near = sorted(ks, key=lambda q: (q[0] - corner[0]) ** 2 + (q[1] - corner[1]) ** 2)
        starts += near[:2]
    starts += [rnd.choice(ks) for _ in range(5)]
    for s0 in starts:
        for rep in range(2):
            prev, cur = None, s0
            path = [cur]
            seen = {cur}
            heading = None
            for _ in range(90):
                nb = [q for q in verts[cur] if q != prev and q not in seen]
                if not nb:
                    break
                if heading is None:
                    nxt = rnd.choice(nb)
                else:
                    def sc(q):
                        v = (q[0] - cur[0], q[1] - cur[1])
                        nrm = math.hypot(*v) + 1e-9
                        return (v[0] * heading[0] + v[1] * heading[1]) / nrm + rnd.uniform(0, .25)
                    nxt = max(nb, key=sc)
                v = (nxt[0] - cur[0], nxt[1] - cur[1])
                nrm = math.hypot(*v) + 1e-9
                heading = (v[0] / nrm, v[1] / nrm)
                prev, cur = cur, nxt
                seen.add(cur)
                path.append(cur)
            if len(path) > 4:
                c.line(path, 4.4, "white")
                c.line(path, 2.6, "#e0993e")


MOTIVI = [("01-pcb", "PCB", pcb), ("02-albero-di-clock", "Albero di clock", clock), ("03-fpga", "FPGA", fpga),
          ("04-diagrammi-temporali", "Diagrammi temporali", timing), ("05-wafer", "Wafer map", wafer),
          ("06-curve-di-livello", "Curve di livello", topo), ("07-radici", "Radici e vene", roots),
          ("08-mappa-stradale", "Mappa stradale", streets)]

if __name__ == "__main__":
    want = sys.argv[1:]
    os.makedirs(OUT, exist_ok=True)
    for (name, label, fn) in MOTIVI:
        if want and not any(w in name for w in want):
            continue
        rnd = random.Random(7)
        c = Canvas(4)
        fn(c, rnd)
        draw_text(c, random.Random(3))
        c.save(os.path.join(OUT, name + ".png"))
        print("ok", name)
