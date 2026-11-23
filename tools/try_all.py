# SPDX-License-Identifier: MIT
# Copyright (c) 2026 giob22. Vedi il file LICENSE.
"""Compila ogni configurazione di un file di prova (prova/configurazioni*.tex), una per volta
decommentata, controlla il log e produce fogli di anteprima con le pagine 2|3 di ciascuna.

Uso:   python -I tools/try_all.py <file.tex> <pacchetto> [cartella-fogli]

Le righe da provare sono quelle del tipo   %\\def\\opzioni{...}   e   %\\def\\formato{...}.
Ogni formato viene provato insieme alla riga  %\\def\\opzioni{seed=7,autoscale=true}.
Esce con 0 solo se tutte le configurazioni compilano senza errori né avvisi."""
import os
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main(cfg, pkg, sheets):
    path = os.path.join(ROOT, "prova", cfg)
    src = open(path, encoding="utf-8").read().split("\n")
    pat = re.compile(r"^%(\\def\\(opzioni|formato)\{.*\})\s*(?:%.*)?$")
    AUTOSCALE = r"\def\opzioni{seed=7,autoscale=true}"
    variants = []
    for i, line in enumerate(src):
        m = pat.match(line)
        if not m:
            continue
        d, kind = m.group(1), m.group(2)
        edits, label = {i: d}, d
        if kind == "formato":
            j = next(k for k, l in enumerate(src) if l.strip().startswith("%" + AUTOSCALE))
            edits[j] = AUTOSCALE
            label = d + "  " + AUTOSCALE
        variants.append((label, edits))

    work = os.path.join(sheets, "try_all_work")
    shutil.rmtree(work, ignore_errors=True)
    os.makedirs(work)
    files = [pkg + ".sty", pkg + ".lua", "margincore.sty", "margincore.lua"]
    srcdirs = [os.path.join(ROOT, pkg), os.path.join(ROOT, "margincore")]

    def run(k):
        label, edits = variants[k]
        d = os.path.join(work, "v%02d" % k)
        os.makedirs(d)
        for f in files:
            for sd in srcdirs:
                if os.path.exists(os.path.join(sd, f)):
                    shutil.copy(os.path.join(sd, f), d)
        lines = list(src)
        for i, t in edits.items():
            lines[i] = t
        open(os.path.join(d, "c.tex"), "w", encoding="utf-8").write("\n".join(lines))
        p = subprocess.run(["lualatex", "-interaction=nonstopmode", "-halt-on-error", "c.tex"],
                           cwd=d, capture_output=True, timeout=600)
        lp = os.path.join(d, "c.log")
        log = open(lp, encoding="utf-8", errors="replace").read() if os.path.exists(lp) else ""
        err = [l for l in log.split("\n") if l.startswith("!")]
        seed = re.search(pkg + r": seed (\d+) \((\w+)", log)
        warn = [l for l in log.split("\n") if pkg + ":" in l and ("sconosciuto" in l or "non valido" in l or "non è" in l)]
        pages = re.search(r"\((\d+) pages?", log)
        png = None
        if p.returncode == 0:
            subprocess.run(["pdftoppm", "-r", "26", "-png", "-f", "2", "-l", "3", "c.pdf", "pg"], cwd=d, check=True)
            png = [os.path.join(d, f) for f in sorted(os.listdir(d)) if f.startswith("pg") and f.endswith(".png")]
        return dict(k=k, label=label, rc=p.returncode, err=err, seed=seed.groups() if seed else None,
                    warn=warn, pages=int(pages.group(1)) if pages else None, png=png)

    with ThreadPoolExecutor(4) as ex:
        res = list(ex.map(run, range(len(variants))))

    bad = 0
    for r in res:
        problems = []
        if r["rc"] != 0 or r["err"]:
            problems.append("ERRORE " + (r["err"][0] if r["err"] else "rc=%d" % r["rc"]))
        if not r["seed"]:
            problems.append("nessuna riga seed nel log")
        if r["warn"]:
            problems.append("avvisi: " + "; ".join(r["warn"]))
        if r["pages"] is None or r["pages"] < 4:
            problems.append("pagine: %s" % r["pages"])
        fixed = "seed=" in r["label"] and "seed=random" not in r["label"]
        if r["seed"] and fixed != (r["seed"][1] == "fissato"):
            problems.append("tipo di seme inatteso: %s" % (r["seed"],))
        bad += bool(problems)
        print("%2d %-4s %-72s %s" % (r["k"], "ok" if not problems else "KO", r["label"][:72], " | ".join(problems)))
    print("\nconfigurazioni:", len(res), " con problemi:", bad)

    CAP, per_sheet, cols = 24, 15, 5
    for s in range(0, len(res), per_sheet):
        ims = []
        for r in res[s:s + per_sheet]:
            if not r["png"]:
                continue
            pg = [Image.open(f).convert("RGB") for f in r["png"]]
            w, h = sum(i.width for i in pg) + 4, max(i.height for i in pg)
            c = Image.new("RGB", (w, h + CAP), (255, 255, 255))
            x = 0
            for i in pg:
                c.paste(i, (x, CAP))
                x += i.width + 4
            d = ImageDraw.Draw(c)
            txt = r["label"].replace(r"\def\opzioni", "").replace(r"\def\formato", "F:")[:46]
            d.text((2, 2), "%d %s" % (r["k"], txt), fill=(0, 0, 0))
            ims.append(c)
        if not ims:
            continue
        cw, ch = max(i.width for i in ims), max(i.height for i in ims)
        rows = (len(ims) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * (cw + 8), rows * (ch + 8)), (120, 120, 120))
        for n, i in enumerate(ims):
            sheet.paste(i, ((n % cols) * (cw + 8), (n // cols) * (ch + 8)))
        out = os.path.join(sheets, "cfg-%d.png" % (s // per_sheet + 1))
        sheet.save(out)
        print(out, sheet.size)
    return 1 if bad else 0


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else os.getcwd()))
