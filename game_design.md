# Wild West — Modular Game Design Document

## Vertical Slice Roadmap

**Data:** 16 ottobre 2026

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

Ogni feature deve migliorare almeno uno dei seguenti aspetti:

- gameplay
- UI
- atmosfera
- simulazione
- immersione

Alla fine di ogni feature:

- indicare file modificati
- aggiornare recap.md
- descrivere brevemente il risultato

Formato finale:

fatto: X, file: Y

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