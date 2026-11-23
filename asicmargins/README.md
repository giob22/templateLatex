# asicmargins

Margini per LuaLaTeX generati come un layout di chip: celle standard con rail VDD/VSS,
macro di memoria, tre livelli di metallo (M1/M2/M3) con via, bond pad, dummy fill e seal ring.
Ogni pagina ha un proprio margine, asimmetrico, che cresce dagli angoli verso il testo.
Ispirato a [Flora](https://flora.alpacasoft.dev) (margini floreali per LuaLaTeX).

## Uso

```latex
\documentclass{article}
\usepackage[a4paper,margin=3.6cm]{geometry}
\usepackage[seed=7]{asicmargins}
\begin{document}
...
\end{document}
```

Compilare con `lualatex`. Copiare accanto al documento `asicmargins.sty`, `asicmargins.lua`,
`margincore.sty` e `margincore.lua` (o metterli in `texmf/tex/lualatex/margins/`).

Dalla v0.3 il pacchetto gira sul motore comune [`margincore`](../margincore/): seme, `where`,
fronte/retro, alone e scala automatica sono del motore, e il disegno del chip è lo stesso di prima
(le pagine delle prove sono identiche pixel per pixel a quelle della v0.2). Il resto di questo README
vale anche per gli altri pacchetti della [raccolta](../README.md).

## Opzioni

I valori booleani vanno scritti per esteso (`ring=false`). Le lunghezze sono in bp; il suffisso
`pt` è accettato e ignorato.

| Opzione | Default | Effetto |
|---|---|---|
| `seed` | casuale | Intero che fissa tutti i margini del documento; senza `seed=` ne viene scelto uno a caso a ogni compilazione (`seed=random` lo chiede esplicitamente) |
| `density` | 1.15 | Moltiplica la densità delle piste |
| `pitch` | 3.2 | Passo della griglia in bp (più basso = più fitto) |
| `clear` | 10 | Distanza minima dal testo in bp |
| `blockwidth` | 48 | Larghezza massima di celle e macro in bp |
| `palette` | chip | `chip`, `ink` (blu e oro, alla Flora), `mono` |
| `ring`, `blocks`, `macros`, `pads`, `dummy`, `metalthree` | true | Attiva/disattiva i singoli elementi |
| `twoside` | auto | `auto` segue l'opzione `twoside` della classe; `true`/`false` la forzano |
| `autoscale` | false | Scala passo, blocchi, macro, anello e spessori secondo pagina e margini |
| `halo` | 6 | Distanza in bp attorno a ciò che è stampato fuori dal testo; `0` disattiva |
| `where` | all | Dove disegnare il motivo: lati, angoli, sopra, sotto (vedi sotto) |

Comandi: `\asicmarginssetup{<opzioni>}`, `\asicmarginsoff`, `\asicmarginson`.

### Seme (`seed`)

Ogni pagina ha un margine diverso: il seme di ciascuna deriva dal seme del documento e dal numero
di pagina. Se non scrivi `seed=`, a ogni compilazione il pacchetto sceglie un seme casuale
(tempo al microsecondo, indirizzo di memoria del processo e tempo di CPU, rimescolati) e lo scrive
nel `.log` e sul terminale alla prima pagina:

    asicmargins: seed 345527039 (casuale; per riprodurlo: seed=345527039)

Per riavere la stessa composizione basta copiare quel numero nelle opzioni. Con `seed=N` il
risultato è sempre lo stesso, anche su un'altra macchina. Attenzione: documenti che richiedono più
passate (indici, riferimenti) cambiano margine a ogni passata, e vale l'ultima. Per un PDF
riproducibile, per esempio sotto controllo di versione, fissa il seme.

### Dove disegnare il motivo (`where`)

`where` accetta un nome o un elenco di nomi. L'elenco va tra graffe se è nelle opzioni di
`\usepackage`, e i nomi si separano con virgole o con `+`:

```latex
\usepackage[seed=7, where=top]{asicmargins}
\usepackage[seed=7, where={topleft,bottomright}]{asicmargins}
\asicmarginssetup{where=sides}      % da questa pagina in poi
```

| Valore | Dove |
|---|---|
| `all` | tutto intorno alla pagina (default) |
| `top`, `bottom` | solo la fascia sopra, o sotto, il testo |
| `topbottom` | sopra e sotto |
| `left`, `right`, `sides` | solo il lato sinistro, o destro, o tutti e due |
| `topleft`, `topright`, `bottomleft`, `bottomright` | solo quell'angolo |
| `corners` | i quattro angoli |

Le fasce corrono per tutto il bordo; gli angoli sono chiazze che partono dall'angolo e sfumano
dopo il 42% della larghezza lungo il bordo alto o basso e il 30% dell'altezza lungo quelli laterali.
Si possono combinare: `top,bottomleft` dà la fascia in alto più l'angolo in basso a sinistra, e un
angolo dentro un lato attivo (`top,topleft`) non aggiunge nulla.

L'anello (`ring`) segue la zona: corre lungo i lati attivi e lungo la portata degli angoli. Con
`where=all` resta il doppio rettangolo di prima. Blocchi, macro e pad compaiono solo se la loro
posizione cade in una zona attiva: con `top` ci sono celle e pad ma niente macro, che stanno sui lati.

I nomi sono posizioni fisiche: `topleft` è sempre l'angolo in alto a sinistra, anche sulle pagine
pari in fronte/retro. Per questo, con nomi asimmetrici come `topleft`, le due pagine affiancate non
condividono più la struttura (vedi sotto); con `top`, `bottom`, `sides`, `topbottom`, `corners`
e `all` sì. Un nome sconosciuto è ignorato con un avviso nel log. Se non ne resta nessuno vale `all`.

### Fronte/retro (`twoside`)

In fronte/retro le due pagine affiancate (2|3, 4|5, …) condividono la struttura del margine:
angoli di crescita, blocchi di celle, macro, pad e bande. La pagina pari è disegnata specchiata,
quindi la doppia pagina è simmetrica rispetto alla piega. Piste, via e riempimento usano invece
il seme della singola pagina, e ogni pagina resta diversa nei dettagli. La pagina 1 è da sola.
In solo fronte, con lo stesso `seed=N` e `where=all`, il disegno è identico a quello della v0.1.
La v0.1 usava `seed=1` come default; ora senza `seed=` il seme è casuale.

### Scala automatica (`autoscale`)

I valori di `pitch`, `blockwidth`, `clear` e `halo` sono riferiti ad A4 con margini laterali di
3,6 cm. Con `autoscale=true` vengono moltiplicati per un fattore

    s = sqrt( sqrt(area pagina / area A4) × margine laterale più stretto / 3,6 cm ),  limitato a [0,45; 1,8]

che si applica anche ad anello, pad, macro e spessori dei tratti. Valori tipici: A4 con 3,6 cm → 1,00;
US letter con 1 in → 0,83; A5 con 1,7 cm → 0,58. Il fattore usato è scritto nel `.log`.

### Alone attorno a testatine, numeri e note (`halo`)

L'area riservata comprende corpo, testatina e piè di pagina letti da `geometry`. In più, a ogni
pagina il pacchetto misura cosa è stampato davvero fuori da quell'area (glifi, filetti, immagini,
riquadri con grafica come TikZ) e ci lascia attorno una zona libera di `halo` bp. Rientrano qui i
numeri di pagina nel margine esterno, le testatine allargate con `\fancyhfoffset` e le note
`\marginpar`. Blocchi, macro e pad evitano queste zone e il routing le aggira.

## Prove

```
cd test
texlua run-tests.lua            # tutti i test
texlua run-tests.lua test-a5    # uno solo
```

Il runner compila in `test/build/` i documenti A4, A5, US letter, fronte/retro, seme casuale, zone
(`where`, una per pagina) e alone. Poi controlla dal `.log` il fattore di scala, la specchiatura delle
pagine pari, il seme e la presenza delle zone di rispetto. Due prove non usano TeX: `unit-seed`
(stesso seme e stessa pagina danno lo stesso disegno, semi o pagine diverse no, il default è
casuale) e `unit-where` (ogni elemento disegnato sta nella zona richiesta, mai nell'area del testo).
Se c'è `pdftoppm`, rasterizza ogni pagina in `test/build/*.png` per il controllo visivo.

Il `.log` contiene una riga per pagina:

    asicmargins: pagina 2 (pari, specchiata); scala 1.000; zone di rispetto 2

## Note

- Il margine è disegnato con operatori PDF diretti. La v0.2, rilevamento dell'alone compreso,
  costa quanto la v0.1 (differenza entro il 5% nel tempo speso in `asicmargins.page`).
- Le zone di rispetto vedono il contenuto della pagina (`\ShipoutBox`), non ciò che altri
  pacchetti aggiungono negli hook `shipout/background` o `shipout/foreground`.
- Le "opacità" della palette sono schiarimenti verso il bianco, non trasparenze PDF: le
  sovrapposizioni non si mescolano come acquerelli veri.
- Compatibilità: richiede LuaLaTeX con kernel LaTeX 2022-06 o successivo (`\DeclareKeys`).
  Provato con MiKTeX (LuaHBTeX 1.25, LaTeX 2026-06); con TeX Live 2023 va ancora verificato.

## Licenza

MIT, vedi [LICENSE](../LICENSE). Il copyright è di giob22.
