# Wild West — Modular Game Design Document

## Vertical Slice Roadmap

**Data:** 17 ottobre 2026

---

# Obiettivo del documento

Questo documento definisce una roadmap modulare per lo sviluppo di Wild West.

L'obiettivo è costruire prima un **vertical slice giocabile**, invece di rimandare tutte le parti importanti alla fine dello sviluppo.

Dopo circa 30-40 feature il progetto deve già essere una versione ridotta ma completa del gioco finale.

Il vertical slice deve contenere:

- una città funzionante
- un personaggio giocabile
- NPC con routine
- economia base
- combattimenti
- missioni
- eventi casuali
- una UI western definitiva

La filosofia è:

> Ogni feature deve rendere il gioco più vicino al prodotto finale.

---

# Regole sviluppo IA

Leggere sempre questo documento prima di lavorare al progetto.

## Regole

- Implementare una sola feature alla volta.
- Aspettare il comando PROSEGUI prima di iniziare la feature successiva.
- Non riscrivere sistemi già funzionanti senza necessità.
- Creare moduli piccoli e indipendenti.
- Collegare i sistemi tramite dati JSON quando possibile.
- Evitare sistemi creati ma non utilizzati.
- Consegna file (regola fissa, dalla Feature 13): includere solo i file nuovi o modificati, compresi recap.md e, se cambiano, questo documento, in un unico .zip con la stessa alberatura del progetto, così da poterlo estrarre direttamente sulla root.

Ogni feature deve migliorare almeno uno dei seguenti aspetti:

- gameplay
- UI
- atmosfera
- simulazione
- immersione

Alla fine di ogni feature:

- indicare file modificati
- aggiornare recap.md
- consegnare i file in un unico .zip che rispetti l'alberatura delle cartelle del progetto
- descrivere brevemente il risultato

Formato finale:

fatto: X, file: Y

Versione visibile: a ogni feature aggiornare `GAME_VERSION` in `scripts/ui/player_hud.gd`; l'HUD la mostra in alto a destra.

---

# Stato avanzamento

- Completate le Feature 1-27 (Fase 1, Fase 2, Fase 3, Fase 4, Proprietà, sistema gang, criminalità, sistema legge, eventi casuali salvataggio, grafica degli eventi schermata di morte e menu di gioco, polish di UI, logica e grafica), più le correzioni di collegamento e di UI elencate in `recap.md`.
- Versione attuale: **Feature 27**. Le feature della roadmap sono completate; la prossima è la Feature 28 (da definire), solo dopo il comando PROSEGUI.
- Le feature 17, 18, 19 e 20 hanno già UI dedicate (banca con prestiti, pannello proprietà, pannello bande e reputazione con tasto N, pannello malaffare con tasto C).

---

# Struttura sviluppo

Il progetto viene diviso in:

1. Vertical Slice Fondamentale
2. Vita nella città
3. Combattimento e Pericolo
4. Economia e Società
5. Il mondo vive
6. Vertical Slice completo
7. Espansione infinita

---

# FASE 1 — Vertical Slice Fondamentale

## Obiettivo

Creare una prima versione giocabile dove il giocatore può vivere una giornata nel West.

---

# Feature 1 — Sistema mondo base

Creare:

- città iniziale
- coordinate mondo
- sistema tempo
- ciclo giorno/notte
- seed procedurale

Risultato:

- mondo funzionante
- variazioni tra partite
- base per simulazione futura

---

# Feature 2 — Player base

Creare:

- personaggio giocatore
- nome
- salute
- soldi
- inventario
- statistiche

UI:

- HUD giocatore
- pannello informazioni

---

# Feature 3 — Movimento e camera

Implementare:

- movimento giocatore
- esplorazione
- telecamera
- interazione base

---

# Feature 4 — UI principale

## Obiettivo

Eliminare l'aspetto simile a una pagina web.

La UI deve sembrare quella di un vero videogioco.

Creare:

- HUD western
- pannelli grafici
- animazioni
- icone
- font personalizzati
- texture
- cornici
- elementi decorativi

Tecnologie:

- Godot Control Nodes
- Theme personalizzati
- AnimationPlayer
- Sprite
- Shader

---

# Feature 5 — Sistema edifici

Creare:

- Saloon
- Banca
- Ufficio dello Sceriffo
- Casa

Ogni edificio deve avere:

- posizione
- funzione
- interazione
- UI dedicata

---

# FASE 2 — Vita nella città

## Obiettivo

Rendere la città viva.

---

# Feature 6 — NPC cittadini

Ogni NPC possiede:

- nome
- lavoro
- ruolo sociale
- posizione
- statistiche
- relazione con il giocatore

---

# Feature 7 — Routine NPC

Gli NPC seguono una giornata:

Mattina:

- lavoro

Pomeriggio:

- attività
- commissioni

Sera:

- saloon
- incontri sociali

Notte:

- casa

---

# Feature 8 — Sistema dialoghi

Creare:

- conversazioni
- risposte multiple
- informazioni
- reputazione

---

# Feature 9 — Sistema reputazione

Il giocatore influenza:

- cittadini
- commercianti
- gang
- legge

---

# Feature 10 — Missioni base

Tipologie:

- consegna
- recupero
- protezione
- caccia semplice

---

# FASE 3 — Combattimento e Pericolo

## Obiettivo

Creare il lato western d'azione.

---

# Feature 11 — Sistema combattimento

Creare un pannello separato.

Elementi:

- schermata combattimento dedicata
- turni
- azioni
- nemici
- statistiche

---

# Feature 12 — Sistema armi

Gestione tramite dati JSON.

Ogni arma possiede:

- nome
- danno
- precisione
- tipo
- rarità

---

# Feature 13 — Sistema ferite

Aggiungere:

- sanguinamento
- ferite
- penalità
- recupero

---

# Feature 14 — Duelli western

Eventi speciali:

- mezzogiorno
- strada principale
- pubblico presente
- reputazione coinvolta

---

# FASE 4 — Economia e Società

## Obiettivo

Creare una simulazione sociale.

---

# Feature 15 — Sistema lavori

Lavori iniziali:

- minatore
- barista
- cacciatore
- mercenario
- commerciante

---

# Feature 16 — Economia dinamica

Gestire:

- prezzi
- domanda
- offerta
- mercato locale

---

# Feature 17 — Sistema banca

Funzioni:

- deposito
- prestiti
- debiti
- interessi

---

# Feature 18 — Proprietà

Possibilità di acquistare:

- casa
- negozio
- terreno

---

# FASE 5 — Il mondo vive

## Obiettivo

Creare conflitti e simulazione emergente.

---

# Feature 19 — Sistema gang

Ogni gang possiede:

- territorio
- membri
- obiettivi
- reputazione
- nemici

---

# Feature 20 — Criminalità

Azioni:

- rapine
- furti
- ricatti
- contrabbando

---

# Feature 21 — Sistema legge

Lo sceriffo reagisce tramite:

- taglie
- arresti
- inseguimenti
- caccia al giocatore

---

# Feature 22 — Eventi casuali

Esempi:

- rapina banca
- incendio
- aggressione
- carovana
- duello casuale
- incontro misterioso

---

# Feature 23 — Salvataggio e caricamento

F5 salva, F6 carica il salvataggio più recente (era F9: l'editor di Godot lo intercettava e fermava il tempo), autosalvataggio a ogni nuovo giorno. Si salva solo lo stato che cambia (il mondo si rigenera dal seed).

---

# Feature 24 — Grafica degli eventi in mappa

Fuoco, rapinatori, carovana, rissa, duellante e straniero compaiono in strada durante gli eventi casuali.

---

# Feature 25 — Schermata di morte

A salute 0 il gioco si ferma: carica l'ultimo salvataggio o nuova partita.

---

# Feature 26 — Menu di gioco e comandi

F1 apre un menu con l'elenco dei comandi e i pulsanti Riprendi, Salva, Carica.

---

# Feature 27 — Miglioramento UI, ottimizzazione logica e abbellimento grafico

HUD e messaggi in stile western con animazioni, aggiornamenti a evento invece che a ogni fotogramma, terreno, strada e scenario rifiniti, luci notturne, vignettatura. Nessuna nuova meccanica di gioco.

---

# FASE 6 — Vertical Slice completo

Dopo circa 30-40 feature il gioco deve essere già divertente.

Deve avere:

- città funzionante
- esplorazione
- NPC vivi
- routine
- lavori
- economia
- combattimento
- missioni
- gang
- eventi casuali

---

# UI Vertical Slice

La UI deve avere:

- HUD definitivo
- menu grafici
- pannelli dedicati
- combattimento cinematografico
- stile western coerente

---

# FASE 7 — Espansione infinita

## Vita del personaggio

- famiglia
- matrimonio
- figli
- eredità
- vecchiaia
- morte

---

## Società

- politica
- elezioni
- territori
- guerre tra città

---

## Simulazione avanzata

- generazione procedurale infinita
- economie autonome
- NPC con memoria
- eventi concatenati
- storie emergenti

---

# Filosofia UI

La UI non deve essere una feature finale.

Deve crescere insieme al gioco.

Progressione:

Feature 4:

HUD base.

Feature 11:

UI combattimento.

Feature 15:

UI lavori ed economia.

Feature 19:

UI gang e reputazione.

Feature 30+:

Polish generale.

---

# Obiettivo finale

Creare un simulatore western procedurale dove:

- ogni città sembra viva
- ogni NPC ha una storia
- ogni scelta modifica il mondo
- ogni partita genera situazioni diverse

Il vertical slice deve essere già un gioco, non una demo tecnica.