# SPDX-License-Identifier: MIT
# Copyright (c) 2026 giob22. Vedi il file LICENSE.
"""Crea l'archivio di rilascio di un pacchetto: releases/<nome>-v<versione>.zip

Uso:   python tools/release.py <pacchetto>      (da qualsiasi cartella)

L'archivio contiene i quattro file da copiare accanto al documento (<nome>.sty, <nome>.lua,
margincore.sty, margincore.lua), la LICENSE, il README del pacchetto e l'esempio con il suo PDF. La versione
si legge dalla riga \\ProvidesPackage del file .sty."""
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main(pkg):
    src = os.path.join(ROOT, pkg)
    sty = open(os.path.join(src, pkg + ".sty"), encoding="utf-8").read()
    m = re.search(r"\\ProvidesPackage\{%s\}\[[^\]]*?\bv(\d+(?:\.\d+)*)" % re.escape(pkg), sty)
    if not m:
        sys.exit("versione non trovata in %s.sty (serve \\ProvidesPackage{%s}[aaaa/mm/gg vX.Y ...])" % (pkg, pkg))
    version = m.group(1)
    files = [
        (os.path.join(src, pkg + ".sty"), pkg + ".sty"),
        (os.path.join(src, pkg + ".lua"), pkg + ".lua"),
        (os.path.join(ROOT, "margincore", "margincore.sty"), "margincore.sty"),
        (os.path.join(ROOT, "margincore", "margincore.lua"), "margincore.lua"),
        (os.path.join(ROOT, "LICENSE"), "LICENSE"),
        (os.path.join(src, "README.md"), "README.md"),
        (os.path.join(src, "esempio.tex"), "esempio.tex"),
        (os.path.join(src, "esempio.pdf"), "esempio.pdf"),
    ]
    os.makedirs(os.path.join(ROOT, "releases"), exist_ok=True)
    out = os.path.join(ROOT, "releases", "%s-v%s.zip" % (pkg, version))
    top = "%s-v%s/" % (pkg, version)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for path, name in files:
            if not os.path.exists(path):
                sys.exit("manca " + path)
            z.write(path, top + name)
    with zipfile.ZipFile(out) as z:
        for i in z.infolist():
            print("%8d  %s" % (i.file_size, i.filename))
    print("->", out)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
