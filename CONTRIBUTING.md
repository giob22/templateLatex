# Contribuire

Grazie dell'interesse: idee, segnalazioni e miglioramenti sono benvenuti.

## Segnalare un problema

Apri una issue indicando:

- il pacchetto e la sua versione;
- il motore e la distribuzione TeX (`lualatex --version`);
- un documento minimo che riproduce il problema (basta `\usepackage` più `lipsum`);
- la riga `<pacchetto>: seed N` del file `.log`: con quel seme il disegno si riproduce identico.

## Proporre una modifica

1. Fai un fork e lavora su un ramo.
2. Rilancia i test dei pacchetti che tocchi: `cd <pacchetto>/test && texlua run-tests.lua`.
3. Una modifica a `margincore/` non deve cambiare l'aspetto degli altri pacchetti: i test devono
   continuare a passare e le pagine di esempio devono restare identiche.
4. Per un motivo nuovo, segui `margincore/README.md`: bastano un file `.lua`, un `.sty` corto e i test.

README e commenti della repo sono in italiano; per codice, issue e discussioni va bene anche l'inglese.

## Licenza dei contributi

Inviando un contributo accetti che venga rilasciato con la stessa licenza MIT della repo (vedi `LICENSE`).

## Cosa non includere

- Immagini, font, codice o testo di altri, a meno che la loro licenza lo consenta e sia indicata nel README.
- Dati personali nei file e nei commit (nomi, email, percorsi del tuo computer, screenshot con interfacce
  o metadati): per l'email dei commit usa l'indirizzo `noreply` di GitHub.
