# fpgamargins

Margini a matrice di interconnessione FPGA per LuaLaTeX: piste orizzontali e verticali con punti di
connessione programmabili agli incroci, blocchi logici (CLB, BRAM, DSP) e alcune connessioni già instradate
in arancione. Ogni pagina è diversa. Fa parte della raccolta di [margini generativi](../README.md) e gira sul
motore comune [`margincore`](../margincore/).

## Uso

```latex
\documentclass{article}
\usepackage[a4paper,margin=3.6cm]{geometry}
\usepackage[seed=7]{fpgamargins}
\begin{document}
...
\end{document}
```

Compilare con `lualatex`. Copiare accanto al documento `fpgamargins.sty`, `fpgamargins.lua`,
`margincore.sty` e `margincore.lua`. Un esempio è in `esempio.tex`.

## Opzioni del motivo

| Opzione | Default | Effetto |
|---|---|---|
| `palette` | blue | `blue`, `ink` (blu da stilografica con connessioni dorate), `mono` |
| `pitch` | 4.6 | Passo in bp della griglia delle piste; più basso = più fitto |
| `blocks` | true | Blocchi logici: CLB (quattro celle), BRAM (righe), DSP (croce) |
| `nets` | true | Connessioni già instradate, in arancione |
| `pips` | true | Punti di connessione agli incroci (scuri se attivi) |
| `weight` | 1 | Moltiplica lo spessore dei tratti |

Le opzioni comuni (`seed`, `where`, `density`, `clear`, `twoside`, `autoscale`, `halo`) e i comandi
`\fpgamarginssetup`, `\fpgamarginsoff`, `\fpgamarginson` sono descritti nel
[README di `asicmargins`](../asicmargins/README.md).

## Come funziona

Piste e blocchi vengono dal seme di struttura: in fronte/retro le pagine affiancate (2|3, 4|5, ...) hanno la
stessa matrice specchiata. I punti attivi e le connessioni instradate vengono dal seme della pagina, come due
configurazioni diverse dello stesso dispositivo.

## Prove

```
cd test
texlua run-tests.lua
```

## Note

- Nelle fasce strette sopra e sotto il testo le piste sono poche: il disegno è più ricco ai lati e negli angoli.
- I blocchi compaiono dove il margine è abbastanza largo e denso.

## Licenza

MIT, vedi [LICENSE](../LICENSE). Il copyright è di giob22.
