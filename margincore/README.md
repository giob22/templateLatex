# margincore

Il motore comune dei pacchetti di [margini generativi](../README.md). Non disegna nulla da solo:
fa tutto ciò che non dipende dal motivo, e ogni motivo è un file Lua che gira sopra di lui.

## Cosa fa il motore

- **Seme**: casuale se omesso (tempo al microsecondo, indirizzo di memoria, tempo di CPU), fissabile
  con `seed=N`, scritto nel `.log`. Ogni pagina ha una sequenza casuale propria.
- **Area del testo**: corpo, testatina e piè di pagina, letti da `geometry`, più la distanza `clear`.
- **Zone `where`**: lati e angoli in cui disegnare; il resto diventa zona vietata.
- **Alone**: misura ciò che è stampato fuori dal testo (numeri di pagina, testatine, note, grafica) e
  ci lascia attorno una zona libera.
- **Densità**: campo che cresce da due angoli scelti a caso, con fasce deboli lungo i bordi.
- **Fronte/retro**: le pagine affiancate condividono la struttura e la pagina pari è specchiata.
- **Scala automatica** secondo formato e margini.
- **Aggancio alla pagina**: inserisce gli operatori PDF nello sfondo di ogni pagina e crea i comandi
  `\<nome>setup`, `\<nome>on`, `\<nome>off`.

## Come si scrive un motivo

Un pacchetto di motivo ha tre file: `<nome>.lua`, `<nome>.sty` e i test in `test/`.

`<nome>.lua` restituisce una tabella con le opzioni proprie e una funzione `draw`:

```lua
local core = ...                       -- il motore, passato da margincore.loadmotif
local M = { opts = { dotsize = 1.5 } } -- valori predefiniti delle opzioni del motivo

function M.draw(ctx)
  local out = { "0.2 0.4 0.8 rg" }
  for x = ctx.ri, ctx.W - ctx.ri, 6 do
    for y = ctx.ri, ctx.H - ctx.ri, 6 do
      if not ctx.inEx(x, y, 0) and ctx.rs() < ctx.dens(x, y) then
        out[#out + 1] = string.format("%.2f %.2f %.2f %.2f re f",
          x, ctx.H - y, ctx.opts.dotsize * ctx.s, ctx.opts.dotsize * ctx.s)
      end
    end
  end
  return out                           -- elenco di operatori PDF; q/Q e lo specchio li aggiunge il motore
end

return M
```

`<nome>.sty` è corto:

```latex
\ProvidesPackage{<nome>}[2026/11/07 v0.1 ...]
\RequirePackage{margincore}
\MarginCoreDeclare{<nome>}{<nome>.lua}      % opzioni comuni: seed, where, density, clear, ...
\DeclareKeys[<nome>]{
  dotsize.code = {\directlua{<nome>.set("dotsize","#1")}},   % opzioni proprie
}
\MarginCoreFinish{<nome>}
```

### Cosa riceve `draw(ctx)`

Coordinate in bp con l'origine in alto a sinistra (y verso il basso); per l'output PDF l'origine è in
basso a sinistra, quindi si scrive `H - y`.

| Campo | Contenuto |
|---|---|
| `ctx.opts` | tutte le opzioni, comuni e del motivo |
| `ctx.W`, `ctx.H`, `ctx.s` | pagina e fattore di scala (1 senza `autoscale`) |
| `ctx.ri`, `ctx.cl` | anello esterno (15 bp × s) e distanza dal testo |
| `ctx.TXT` | area riservata al testo `{x0, y0, x1, y1}` |
| `ctx.reg`, `ctx.set` | zone attive (`where`); `nil` con `where=all` |
| `ctx.c1`, `ctx.c2`, `ctx.clist` | gli angoli di crescita scelti e quelli attivi |
| `ctx.rs`, `ctx.rd` | sequenze casuali: struttura (uguale per la coppia di pagine) e dettagli (per pagina) |
| `ctx.sseed`, `ctx.dseed` | i semi di quelle due sequenze, per chi vuole un generatore proprio (`core.rng`) |
| `ctx.dens(x, y)` | densità del disegno nel punto, con un po' di rumore (consuma `ctx.rd`) |
| `ctx.dens0(x, y)` | la stessa densità, liscia e senza numeri casuali |
| `ctx.EX` | rettangoli dove non si disegna (testo, zone vietate, alone); un motivo può aggiungerne |
| `ctx.free(r)`, `ctx.inEx(x, y, m)`, `ctx.clip(a, b, iv)`, `ctx.rowIv(y)`, `ctx.colIv(x)` | prove e ritagli rispetto a `EX` |
| `ctx.mirror` | `true` sulle pagine pari in fronte/retro; il motivo disegna comunque come per una dispari |

Il motore offre anche `core.num` (numero compatto per i PDF), `core.col` (colore schiarito verso il
bianco) e `core.rng(seme)` (generatore deterministico).

### Prove

`../tools/testlib.lua` ha tutto il necessario: compila i documenti `test-*.tex`, legge il `.log`, e
offre le prove senza TeX sul seme (`unit_seed`) e sulle zone (`unit_where`). Il runner di un nuovo
pacchetto si ricava da quello di [`topomargins`](../topomargins/test/run-tests.lua) in poche righe.

### Regola di compatibilità

Una modifica al motore non deve cambiare l'aspetto dei pacchetti esistenti: dopo ogni modifica si
rilanciano i test di tutti i pacchetti e si confronta il risultato con quello di prima.

## Licenza

MIT, vedi [LICENSE](../LICENSE). Il copyright è di giob22.
