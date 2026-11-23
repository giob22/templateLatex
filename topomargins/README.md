# topomargins

Margini a curve di livello per LuaLaTeX: una mappa topografica diversa a ogni pagina, con le
curve che sfumano dagli angoli verso il testo. Fa parte della raccolta di
[margini generativi](../README.md) e gira sul motore comune [`margincore`](../margincore/).

## Uso

```latex
\documentclass{article}
\usepackage[a4paper,margin=3.6cm]{geometry}
\usepackage[seed=7]{topomargins}
\begin{document}
...
\end{document}
```

Compilare con `lualatex`. Copiare accanto al documento `topomargins.sty`, `topomargins.lua`,
`margincore.sty` e `margincore.lua` (o metterli in `texmf/tex/lualatex/margins/`).
Un esempio è in `esempio.tex`.

## Opzioni

I valori booleani vanno scritti per esteso (`peaks=false`). Le lunghezze sono in bp; il suffisso
`pt` è accettato e ignorato.

Opzioni del motivo:

| Opzione | Default | Effetto |
|---|---|---|
| `palette` | sepia | `sepia` (marrone), `ink` (blu con curve maestre dorate), `mono`, `sea` (carta nautica) |
| `levels` | 40 | Numero di curve: quote equidistanti sul rilievo della pagina |
| `index` | 5 | Una curva ogni `index` è maestra (più spessa) |
| `feature` | 200 | Dimensione in bp delle forme più grandi del rilievo; più basso = terreno più mosso |
| `step` | 3 | Passo in bp della griglia di calcolo; più basso = curve più lisce, ma più lente |
| `hills` | true | Colline negli angoli di crescita; `false` = solo rilievo casuale |
| `peaks` | true | Crocette sulle quote dei picchi |
| `weight` | 1 | Moltiplica lo spessore dei tratti |

Opzioni comuni a tutti i pacchetti della raccolta:

| Opzione | Default | Effetto |
|---|---|---|
| `seed` | casuale | Intero che fissa tutti i margini; senza `seed=` se ne sceglie uno a caso a ogni compilazione e lo scrive nel `.log` |
| `where` | all | Dove disegnare: `top`, `bottom`, `topbottom`, `left`, `right`, `sides`, `topleft`, `topright`, `bottomleft`, `bottomright`, `corners`, anche in elenco: `where={topleft,bottomright}` |
| `density` | 1.15 | Fino a che distanza dagli angoli arrivano le curve |
| `clear` | 10 | Distanza minima dal testo in bp |
| `twoside` | auto | `auto` segue l'opzione `twoside` della classe; `true`/`false` la forzano |
| `autoscale` | false | Scala griglia, colline e spessori secondo formato della pagina e margini |
| `halo` | 6 | Distanza in bp attorno a ciò che è stampato fuori dal testo (numeri, testatine, note); `0` disattiva |

Comandi: `\topomarginssetup{<opzioni>}` (le opzioni si accumulano da quella pagina in poi),
`\topomarginsoff`, `\topomarginson`.

Seme, `where`, fronte/retro, alone e scala automatica sono descritti nel
[README di `asicmargins`](../asicmargins/README.md): funzionano allo stesso modo.

## Come funziona

Il rilievo è la somma di quattro ottave di rumore liscio più una collina forte sull'angolo
principale, una sul secondo e altre più deboli sugli altri. Le curve sono le isoipse a quote
equidistanti, calcolate con i *marching squares* su una griglia e collegate in polilinee, che
tengono piccolo il PDF. Ogni curva si vede finché la densità del margine supera una soglia
propria: per questo sfuma a una distanza diversa dall'angolo.

In fronte/retro le pagine 2|3, 4|5, … condividono il rilievo e la pagina pari è specchiata: la
doppia pagina è un paesaggio solo, con piccole differenze nel punto in cui le curve sfumano.

## Prove

```
cd test
texlua run-tests.lua            # tutti i test
texlua run-tests.lua unit-topo  # uno solo
```

Il runner compila in `test/build/` i documenti A4, A5, US letter, fronte/retro, seme casuale, zone
(`where`, una per pagina), alone e opzioni, e controlla dal `.log` scala, specchiatura e seme. Le prove
senza TeX verificano che stesso seme e stessa pagina diano lo stesso disegno, che ogni punto delle curve
stia nella zona richiesta e mai nell'area del testo, e che le pagine di una coppia condividano il rilievo
mentre quelle di coppie diverse no. Se c'è `pdftoppm`, ogni pagina è rasterizzata in `test/build/*.png`.

## Note

- Costo: circa 150 ms per pagina A4 e circa 25 KB in più nel PDF per pagina.
- Nelle fasce strette (sopra e sotto il testo) le curve attraversano la fascia quasi in
  perpendicolare e danno un tratteggio fitto: è il comportamento normale delle curve di livello.
- Con `where` e una sola zona piccola le curve sono poche: è voluto, sfumano dall'angolo.
- Non c'è ancora una cornice di mappa (`ring`) né la graduazione sul bordo.

## Licenza

MIT, vedi [LICENSE](../LICENSE). Il copyright è di giob22.
