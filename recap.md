# Recap sviluppo — Wild West

## Regole di consegna (fisse, dalla Feature 13)
- I file di ogni feature vanno consegnati in un unico **.zip con l'alberatura delle cartelle del progetto**, estraibile direttamente sulla root (`data/`, `scripts/...`).
- Lo zip contiene solo i file nuovi o modificati, `recap.md` aggiornato e, se cambiano, `game_design.md`.
- Una sola feature alla volta, si prosegue solo con il comando PROSEGUI. Chiusura di ogni feature: `fatto: X, file: Y`.

## Feature 1 — Sistema mondo base ✅
- Seed procedurale globale (`WorldSeed`, autoload): `rng_for(canale)` dà generatori indipendenti e riproducibili.
- Tempo di gioco e ciclo giorno/notte (`GameTime`, autoload): giorno, ora, fasi (alba/giorno/tramonto/notte), segnali, colore luce.
- Città iniziale (`TownGenerator`): nome, coordinate, strada principale e lotti vuoti nord/sud, tutto come dati.
- Configurazione in `data/world_config.json`.

## Feature 2 — Player base ✅
- `PlayerState` (autoload): nome, salute, soldi, statistiche (forza, mira, agilità, carisma, resistenza), inventario a slot con stack.
- `ItemDB` (autoload): oggetti definiti in `data/items.json`.
- HUD (nome, barra salute, soldi) e scheda personaggio con statistiche e zaino (`scripts/ui/player_hud.gd`).
- API pronta: `damage`, `heal`, `add_money`, `spend_money`, `add_item`, `remove_item`, `use_item`, `to_dict`.

## Feature 3 — Movimento e camera ✅
- `player_avatar.gd`: giocatore in vista dall'alto, WASD/frecce, Shift per correre; velocità = base + Agilità (parametri in `player_config.json`, sezione `movement`).
- Collisioni: i lotti della città sono solidi; il giocatore resta dentro l'area di gioco (`world` in `world_config.json`).
- Camera che segue il giocatore con smoothing, limiti sull'area e zoom con la rotella.
- Esplorazione: l'area è molto più grande della città; `scenery_generator.gd` la riempie di cactus, rocce e cespugli (dipendono dal seed).
- Interazione base: componente riutilizzabile `interactable.gd` (suggerimento "[E] ...", segnale `interacted`) e `interaction_hud.gd` per prompt e messaggi. Per ora ogni lotto è esaminabile; la Feature 5 userà lo stesso componente per gli edifici.
- Mentre la scheda personaggio è aperta il giocatore non si muove.
- Pronto per: Feature 4 (UI principale: stile western, font, texture, cornici, animazioni).

## Feature 4 — UI principale ✅
- `WesternTheme` (`scripts/ui/western_theme.gd`): Theme western generato da `data/ui_theme.json` (palette, font, dimensioni). Stili per Panel, PanelContainer, Label, Button, ProgressBar, ItemList, tooltip, separatori; varianti `PaperPanel`, `InkLabel`, `TitleLabel`. Uso: `WesternTheme.apply(control)`.
- Font: carica `res://assets/fonts/western.ttf` se presente, altrimenti `SystemFont` con serif di ripiego. Per il font definitivo basta aggiungere il file (es. Rye, licenza OFL).
- `WesternPanel` (`scripts/ui/western_panel.gd`): pannello base riutilizzabile con cornice oro, angoli ornamentali, chiodi, banner del titolo, texture via shader e animazione `open()` / `close()` / `toggle()`.
- Shader `shaders/paper_grain.gdshader`: grana e vignettatura per legno/carta.
- `WesternIcon` (`scripts/ui/western_icon.gd`): icone procedurali (cuore, moneta, stella sceriffo, zaino, cappello), sostituibili con sprite.
- `UIFx` (`scripts/ui/ui_fx.gd`): animazioni Tween riutilizzabili (`pop`, `flash`, `shake`, `pulse`, `count_to`).
- Integrazione: in `player_hud.gd` chiamare `WesternTheme.apply(self)` e usare `WesternPanel` per la scheda personaggio; HUD (nome, barra salute, soldi) prende subito lo stile dal tema.
- Pronto per: Feature 5 (sistema edifici: ogni edificio userà `WesternPanel` per la sua UI dedicata).

## Feature 5 — Sistema edifici ✅
- Dati in `data/buildings.json`: ordine (`layout`) e definizione di Saloon, Banca, Ufficio dello Sceriffo e Casa (nome, insegna, colori, orari, azioni, ricercati). `BuildingDB` li carica.
- `BuildingManager` (`scripts/buildings/building_manager.gd`): `spawn(lotti)` assegna i 4 edifici ai lotti vuoti in base al seed (canale `buildings`, quindi cambia tra partite), crea facciata e ingresso, e tiene la lista `buildings` con posizione, rettangolo e ingresso. Imposta `street_y` per orientare la porta verso la strada.
- `BuildingFacade`: aspetto dell'edificio (tetto, porta, finestre, insegna) disegnato da codice.
- `BuildingEntrance`: zona davanti alla porta con suggerimento "[E] Entra — nome" o "Chiuso (apre alle ...)"; emette `interacted` come `interactable.gd`.
- `BuildingPanel` (`scripts/ui/building_panel.gd`): UI dedicata basata su `WesternPanel`, generata dai dati: descrizione, soldi, pulsanti azione, bacheca ricercati; Esc o "Esci" per chiudere. Il gioco va in pausa mentre è aperta.
- Funzioni: Saloon (whiskey, stufato, stanza), Banca (deposito/prelievo con saldo, solo in memoria per ora), Sceriffo (manifesti dei ricercati, battuta sulla legge), Casa (dormi fino all'alba). Orari di apertura letti da `GameTime.hour` se disponibile.
- Azioni gestite da `BuildingActions` (`buy_heal`, `rest`, `bank_deposit`, `bank_withdraw`, `info`): per nuove azioni basta un nuovo `type` lì e una riga nel JSON.
- Pronto per: Feature 6 (NPC cittadini: lavori e luoghi legati agli edifici).

## Feature 6 — NPC cittadini ✅
- Dati in `data/npcs.json`: numero di cittadini, nomi e soprannomi, lavori (Sceriffo, Banchiere, Barista, Minatore, Cacciatore, Commerciante, Mercenario) con ruolo sociale, luogo di lavoro, bonus statistiche, età e colori; livelli di relazione. `NPCDB` li carica.
- `NPCGenerator`: crea i cittadini in base al seed (canale `npcs`). Sceriffo, banchiere e barista sono garantiti e stanno davanti al loro edificio; gli altri si distribuiscono lungo la strada. Ogni NPC ha id, nome, età, lavoro, ruolo, luogo di lavoro, posizione, statistiche (forza, mira, agilita, carisma, resistenza), relazione col giocatore (-100..100) e aspetto.
- `NPCRegistry`: archivio centrale con `get_npc`, `by_job`, `at_workplace`, `change_relationship`, `relationship_label` (Nemico/Ostile/Neutrale/Amichevole/Alleato). Base per routine (F7), dialoghi (F8) e reputazione (F9).
- `NPCAvatar`: figura vista dall'alto disegnata da codice, con nome e "[E] Parla con ...". Per ora ferma.
- `NPCPanel` (`scripts/ui/npc_panel.gd`): scheda in stile western con lavoro, ruolo, età, luogo di lavoro, barre statistiche e relazione. Il pulsante "Saluta" è provvisorio: la prima volta dà un bonus di relazione.
- `NPCManager`: `spawn(buildings, street_y)` dopo `BuildingManager.spawn`; apre la scheda e mette il gioco in pausa mentre è aperta.
- Pronto per: Feature 7 (routine NPC: mattina lavoro, sera saloon, notte casa).

## Feature 7 — Routine NPC ✅
- Dati in `data/npc_routines.json`: fasce orarie (notte 22-6, mattina 6-12, pomeriggio 12-18, sera 18-22), attività pesate per fascia, eccezioni per lavoro (barista di sera al saloon, sceriffo di guardia anche di notte, banchiere in banca nel pomeriggio), velocità di camminata, commissioni e testi. `NPCRoutineDB` li carica.
- `NPCScheduler`: legge `GameTime.hour` ogni mezzo secondo e, al cambio di fascia, avvisa le routine. Se il tempo salta in avanti (es. dormire) gli NPC compaiono subito al posto giusto invece di camminare.
- `NPCRoutine` (componente di ogni NPCAvatar): sceglie l'attività con il seed (canale `routine_<id>`) e la esegue. Attività: lavoro (resta al suo posto), passeggiata, chiacchiere davanti al saloon, serata dentro il saloon, commissione in banca/ufficio/saloon e ritorno, casa per la notte. Cammina lungo la corsia della strada senza attraversare i lotti ed entra/esce dagli edifici (invisibile e non interagibile mentre è dentro).
- `NPCAvatar`: nuovo stato "dentro", ondeggiamento mentre cammina e distintivo girato secondo la direzione.
- Dati NPC aggiornati in tempo reale nel registro: `position`, `post`, `home`, `slot`, `activity`, `inside`. Dialoghi (F8) e missioni (F10) possono usarli.
- `NPCPanel`: mostra l'attività attuale ("Ora: Sta lavorando").
- `NPCManager`: crea scheduler e routine e posiziona tutti all'avvio secondo l'ora.
- Pronto per: Feature 8 (sistema dialoghi: conversazioni, risposte multiple, informazioni, reputazione).

## Feature 8 — Sistema dialoghi ✅
- Dati in `data/dialogues.json`: gruppi di reputazione (cittadini, commercianti, legge, gang), informazioni apprendibili (`info`) e un albero di nodi per lavoro (`generic`, sceriffo, barista, banchiere, minatore, cacciatore, commerciante, mercenario). `DialogueDB` li carica; se un lavoro non ha un dialogo si usa `generic`.
- Ogni nodo ha testo, varianti condizionate (es. tono diverso se la relazione è alta o bassa) e risposte multiple. Le risposte possono avere condizioni (`min_rel`, `max_rel`, `min_money`, `slot`, `info`, `no_info`, `stat`, `rep`), essere uniche (`once`) o mostrarsi bloccate (`show_locked`).
- Effetti delle risposte: `relationship` (con l'NPC), `reputation` (per gruppo), `info` (nuova informazione), `money`.
- `DialogueRunner` (`scripts/dialogue/dialogue_runner.gd`): logica pura senza UI (`start`, `current`, `choose`, `finished`, `messages`). Segnaposto nei testi: `{name}`, `{player}`, `{job}`, `{workplace}`. La prima conversazione dà il bonus di presentazione (prima fatto dal vecchio "Saluta").
- `DialogueState`: informazioni apprese e reputazione per gruppo, solo in memoria. La Feature 9 li userà per il sistema reputazione completo.
- `DialoguePanel` (`scripts/ui/dialogue_panel.gd`): basato su `WesternPanel`, testo a macchina da scrivere su carta, risposte come pulsanti (tasti 1-9), Spazio/Invio/clic saltano l'animazione, Esc chiude; mostra gli esiti dell'ultima scelta.
- `NPCPanel`: il pulsante "Saluta" provvisorio è sostituito da "Parla" (segnale `talk_requested`).
- Pronto per: Feature 9 (sistema reputazione: cittadini, commercianti, gang, legge).
- Integrazione: `world.gd` ora crea `BuildingManager` e `NPCManager` (edifici sui lotti, NPC con routine) e segna il giocatore nel gruppo `player` (serve a ingressi e NPC per rilevarlo); i lotti senza edificio restano segnaposto. `NPCManager` apre `DialoguePanel` dal pulsante "Parla" della scheda NPC e sblocca la pausa alla chiusura del dialogo.

## Feature 9 — Sistema reputazione ✅
- Dati in `data/reputation.json`: gruppi (cittadini, commercianti, legge, gang), fasce (Odiato, Malvisto, Sconosciuto, Rispettato, Leggenda) con moltiplicatore prezzi, lavoro -> gruppo, collegamenti tra gruppi (legge/gang si oppongono, i cittadini influenzano i commercianti).
- `ReputationSystem` (`scripts/reputation/reputation_system.gd`): `value`, `tier`, `tier_label`, `add` (limitata a -100..100, propaga ai gruppi collegati, segnala il cambio di fascia), `price`, `price_mult`, `on_relationship`. I valori restano in `DialogueState.reputation` (solo in memoria); `DialogueState.add_reputation` ora delega qui.
- Effetti attivi: i prezzi di saloon e simili (`buy_heal`, `rest`) dipendono dalla reputazione presso i commercianti, anche nelle etichette dei pulsanti; ogni variazione di relazione in un dialogo sposta un po' la reputazione del gruppo del lavoro dell'NPC; a ogni cambio di fascia il dialogo avvisa ("Ora per i commercianti sei: ..."); le condizioni `rep` dei dialoghi usano gli stessi valori.
- UI: `ReputationPanel` (`scripts/ui/reputation_panel.gd`, basato su `WesternPanel`) con barra e fascia per gruppo e effetto sui prezzi; `ReputationManager` lo apre con **P** (pausa mentre è aperto, Esc chiude); suggerimento aggiunto all'HUD.
- Per nuovi effetti basta usare `ReputationSystem.add(gruppo, valore)` e `ReputationSystem.tier(gruppo)`.
- Pronto per: Feature 10 (missioni base: consegna, recupero, protezione, caccia semplice), che userà `ReputationSystem.add` per le ricompense.

## Feature 10 — Missioni base ✅
- Dati in `data/quests.json`: quattro tipi (consegna, recupero, protezione, caccia semplice) con titoli, testi, suggerimenti e ricompense (soldi, relazione, reputazione), pesi per lavoro dell'NPC (il cacciatore chiede caccia, il commerciante consegne, ecc.), numero massimo di missioni attive (3). `QuestDB` li carica.
- `QuestGenerator`: crea la missione di un NPC in base al seed (canale `quest_<npc>_<n>`), con bersaglio, oggetto, animale e ricompensa. `QuestState` (solo in memoria): missioni attive/pronte, proposte, completate; `complete()` paga soldi e assegna relazione e reputazione (`ReputationSystem.add`, quindi anche i prezzi cambiano).
- Dialoghi: ogni NPC ha le scelte "Hai del lavoro per me?", "Ho un pacco da consegnarti." e "Ho finito il lavoro che mi hai affidato."; i nodi condivisi `q_offer`, `q_accepted`, `q_done` stanno in `generic` (i nodi `q_*` mancanti ricadono lì). Nuove condizioni `quest_available`, `quest_ready`; nuovi effetti `quest_offer`, `quest_accept`, `quest_decline`, `quest_complete`; segnaposto `{quest_title}`, `{quest_text}`, `{quest_hint}`, `{quest_giver}`, `{quest_reward}`.
- `QuestManager` (`scripts/quests/quest_manager.gd`, creato da `world.gd`): recupero = oggetto nel deserto da raccogliere con E; caccia = animali fuori città, E per sparare (probabilità legata alla Mira); protezione = restare entro 160 px dall'NPC per il tempo richiesto; consegna = parlare con il destinatario. Tracker in alto a destra, diario con **Q** (`QuestPanel`, pausa mentre è aperto).
- Le missioni si riavviano con una nuova partita (R). Nessun salvataggio per ora.
- Pronto per: Feature 11 (sistema combattimento: pannello separato a turni), che potrà sostituire la caccia semplice con scontri veri.

## Feature 11 — Sistema combattimento ✅
- Dati in `data/combat.json`: formule (precisione, copertura, critici, resistenza, fuga), azioni, arma di partenza provvisoria (Revolver, sostituita dalla Feature 12), nemici (bandito, capobanda, coyote, lupo) con salute, statistiche, attacco, bottino e reputazione, e la tabella degli incontri casuali. `CombatDB` li carica.
- `CombatSystem` (`scripts/combat/combat_system.gd`): logica a turni senza UI. Il giocatore sceglie un'azione (Spara con la Mira, Pugno con la Forza, Ripararsi, Bende, Fuggi con l'Agilità), poi agiscono i nemici. Restituisce eventi `{text, who, hp, kind}` che la UI mostra in sequenza. Il danno al giocatore si applica a `PlayerState` solo alla fine (`apply_results`): vittoria = bottino e reputazione (`ReputationSystem.add`), fuga = nessun bottino, sconfitta = svenimento (salute 10, perdi metà dei soldi, ti risvegli in città al mattino). Nessuna morte per ora: arriverà con le ferite (Feature 13).
- `CombatPanel` (`scripts/ui/combat_panel.gd`, basato su `WesternPanel`): schermata dedicata con sfondo scuro, carte nemico con barra salute (clic per scegliere il bersaglio), registro eventi su carta, salute del giocatore, azioni con tasti 1-5, animazioni (`UIFx.shake`, `flash`, `pop`) e schermata finale con "Continua".
- `CombatManager` (`scripts/combat/combat_manager.gd`, creato da `world.gd`): `start_encounter(nemici, titolo, imboscata)`, imboscate casuali quando il giocatore si muove a più di 650 px dalla città (controllo ogni 3 s, 10%, pausa di 120 s tra un incontro e l'altro), gioco in pausa durante lo scontro. Debug: tasto **X** avvia un incontro casuale.
- Pronto per: Feature 12 (sistema armi in JSON: nome, danno, precisione, tipo, rarità), che sostituirà `weapon` e `punch` in `combat.json`.

## Feature 12 — Sistema armi ✅
- Dati in `data/weapons.json`: tipi (pistola, fucile, doppietta, lama, contundente; ognuno `ranged` o `melee`), rarità (comune, non comune, raro, leggendario, con colore e peso per i drop) e 11 armi con nome, danno `[min, max]`, precisione (modificatore alla probabilità di colpire), tipo, rarità, prezzo, descrizione e critico opzionale (`crit_bonus`). Per una nuova arma basta una voce nel JSON.
- `WeaponDB` (`scripts/combat/weapon_db.gd`): accesso ai dati (`weapon`, `kind`, `damage`, `accuracy`, `crit_bonus`, `price`, `stats_text`, `rarity_label/color`, `hit_text`, `pick_from` = scelta pesata dalla rarità, `random_id`). Le armi sono anche oggetti dello zaino: `ItemDB.get_item` ricade su `WeaponDB.item_def`, quindi `add_item`/`has_item` funzionano senza altre modifiche (non impilabili, un'arma per slot).
- `PlayerState`: arma equipaggiata (`equipped_weapon`), `get_weapon()` (vuoto se non è più nello zaino), `equip_weapon`, `unequip_weapon`, segnale `equipment_changed`; `to_dict` include l'arma. Il giocatore parte con il Revolver usato (`start_weapon` e `start_items` in `player_config.json`), identico al vecchio revolver provvisorio (6-12).
- Combattimento (`CombatSystem`): arma da fuoco in mano → azione "Spara (nome arma)" con Mira; arma bianca in mano → il "Pugno" diventa "Colpisci (nome arma)" con Forza; senza arma da fuoco "Spara" è disattivata (e non costa il turno). Precisione e critico dell'arma si sommano alle formule; il suggerimento del pulsante mostra le statistiche dell'arma; i testi usano il verbo del tipo ("Fai fuoco con il Colt Navy e centri"). Rimossa la voce provvisoria `weapon` da `combat.json` (resta `punch` per i pugni).
- Bottino: i nemici hanno `weapon_drop` (chance + pool) in `combat.json`; il Bandito lascia armi comuni/non comuni (20%), il Capobanda anche rare e leggendarie (50%). L'arma trovata compare nella schermata finale e finisce nello zaino (se pieno, la lasci).
- Acquisto: l'Ufficio dello Sceriffo ha una piccola armeria (Colt Navy, Winchester 1873, Doppietta, Coltello da caccia) con nuova azione `buy_weapon` in `BuildingActions` (prezzo base dal JSON, modificato dalla reputazione presso i commercianti; blocca se zaino pieno o arma già posseduta; equipaggia subito la prima arma da fuoco se si è disarmati). `BuildingPanel` usa `action_label/action_cost/action_tooltip`.
- UI: HUD con riga "Arma: ...", scheda personaggio con arma in mano e statistiche, zaino con armi colorate per rarità e "(in mano)"; doppio click su un'arma = equipaggia, doppio click sull'arma in mano = riponi.
- Caccia (missioni): per sparare agli animali serve un'arma da fuoco in mano e la sua precisione si somma alla probabilità di colpire.
- Debug: tasto **G** regala un'arma casuale.
- Pronto per: Feature 13 (sistema ferite: sanguinamento, ferite, penalità, recupero); le armi potranno avere effetti sulle ferite.

## Feature 13 — Sistema ferite ✅
- Dati in `data/wounds.json`: gravità (ferita leggera, ferita, ferita grave) con danno minimo, probabilità, sanguinamento (salute persa per ora di gioco), penalità e ore di guarigione; parti del corpo (braccio -> Mira, spalla -> Forza, gamba -> Agilità, torso -> Resistenza, testa -> Carisma). Per nuove ferite o parti basta il JSON.
- `WoundSystem` (`scripts/wounds/wound_system.gd`, logica senza UI, stato in memoria): `try_wound(danno, rng)`, `add_wound`, `bandage` (ferma l'emorragia peggiore), `bandage_all`, `stat_penalty`, `is_bleeding`, `tick_hour`, descrizioni (`wound_name`, `penalty_text`, `status_text`). Segnali su PlayerState: `wounds_changed`, `wound_message`.
- Penalità: `PlayerState.get_stat()` ora restituisce la statistica effettiva (base meno ferite, mai sotto 0), quindi combattimento, movimento (Agilità) e caccia ne risentono; `get_base_stat()` dà il valore senza penalità.
- Combattimento: un colpo subito può causare una ferita (subito attiva, con penalità già nello scontro e riga nel registro); l'azione Bende ferma anche un'emorragia; dopo una sconfitta qualcuno ti fascia.
- Sanguinamento e recupero: `WoundManager` (creato da `world.gd`) applica a ogni ora di gioco sanguinamento e guarigione, anche se il tempo salta (dormire). La salute per sanguinamento non scende sotto 1: a 1 svieni, ti risvegli in città al mattino, fasciato, con metà dei soldi in meno. Le ferite che sanguinano non guariscono finché non sono fasciate; una ferita fasciata guarisce 2x più in fretta. Avviso sotto i 20 di salute.
- Cure: le Bende (oggetto con `bandage: true`) curano salute e fermano un'emorragia anche a salute piena (doppio click nello zaino); dormire (stanza del saloon, casa) fascia di fortuna le ferite e fa passare le ore. Il giocatore parte con 2 bende; l'Ufficio dello Sceriffo le vende (`buy_item` in `BuildingActions`, riutilizzabile per altri negozi).
- UI: HUD con riga "Ferite" (rossa se sanguini), scheda personaggio con elenco ferite, stato e penalità, statistiche penalizzate in rosso con "(ferite -N)". Debug: tasto **V** infligge una ferita casuale.
- Correzione a `GameTime` (`scripts/core/game_time.gd`): aggiunti `hour` e `skip_to_hour()`, che le Feature 5, 7 e 11 già davano per esistenti ("se disponibile"). Effetti: gli orari di apertura degli edifici ora valgono, le routine NPC seguono davvero l'ora, dormire e svenire fanno passare il tempo.
- Pronto per: Feature 14 (duelli western: mezzogiorno, strada principale, pubblico, reputazione coinvolta).

## Feature 14 — Duelli western ✅
- Dati in `data/duels.json`: ora del duello (mezzogiorno), tempi (attesa del segnale casuale 1,6-4,4 s, finestra di reazione, bonus Agilità/Mira), velocità di estrazione dell'avversario (stat, fama, rumore), probabilità di colpire, riserve di colpi, posta, pubblico, tabelle di reputazione (vittoria, vittoria scorretta, sconfitta, parità, rifiuto), variazione relazione, fama per lavoro (lo sceriffo non duella), generatore di pistoleri di passaggio, sfide casuali e tutti i testi. `DuelDB` (`scripts/duel/duel_db.gd`) li carica.
- `DuelSystem` (`scripts/duel/duel_system.gd`, logica senza UI): `from_npc`, `make_stranger`, `suggest_stake`, `setup`, `resolve(reazione_ms, scorretto)`, `refuse()`, `apply_results()`. Vince chi estrae prima e poi gli scambi di colpi (fino a 4 a testa) sono decisi da Mira, precisione dell'arma e Agilità dell'avversario; chi estrae per primo ha un bonus sul primo colpo. Sparare prima del segnale è un fallo: colpisce per primo ma con penalità e conseguenze di reputazione pesanti. Serve un'arma da fuoco in mano (le armi bianche non bastano). Il duello non è mortale: la salute del giocatore non scende sotto 5.
- Reputazione coinvolta: ogni esito sposta cittadini, commercianti, gang e legge via `ReputationSystem.add`. L'effetto cresce con il pubblico e con la fama dell'avversario; se lo sceriffo è in strada vede tutto (fallo = ulteriore penalità con la legge, duello leale = piccolo bonus). Rifiutare costa reputazione. La relazione con l'NPC sfidante cambia (`NPCRegistry.change_relationship`). Posta in denaro: la vinci o la perdi (massimo metà dei tuoi soldi).
- Ferite: i colpi subiti passano dal `WoundSystem` (`try_wound`) alla fine del duello; salute persa con `PlayerState.damage`.
- `DuelPanel` (`scripts/ui/duel_panel.gd`): schermata dedicata disegnata da codice: strada principale a mezzogiorno (sole a picco, ombre sotto i piedi), edifici, pubblico (con la stella dello sceriffo se presente), due sagome, barre di resistenza, lampo dello sparo e scossa. Fasi: sfida (Accetta/Rifiuta, tasti 1-2) -> intro (se è mattina il tempo salta a mezzogiorno con `GameTime.skip_to_hour`) -> attesa -> **SPARA!** (Spazio, Invio o clic) -> scambio di colpi -> esito con soldi, salute e reputazione.
- `DuelManager` (`scripts/duel/duel_manager.gd`): `challenge_npc(npc_id)`, `challenge_stranger()`, `setup(avatar, origin)` (come gli altri manager, segnale `message`), pausa del gioco durante il duello, segnali `duel_started` / `duel_finished`. Sfide casuali: a mezzogiorno, se la fama del giocatore (max valore assoluto di cittadini, gang, legge) è almeno 15, un pistolero lo sfida (una verifica al giorno, pausa di 3 giorni). Debug: tasto **T** avvia una sfida.
- Integrazione in `world.gd` (una riga nei manager esistenti): `var duel_manager := DuelManager.new(); add_child(duel_manager)`; facoltativo `duel_manager.setup(town_center, raggio)` per limitare le sfide casuali alla città.
- Assunzioni sulle API esistenti (da verificare): `PlayerState.health/money/get_weapon()/get_stat("agilita"|"mira"|"resistenza")`, `WeaponDB.weapon(id)` (campi `type`, `damage`, `accuracy`, `name`), `WoundSystem.try_wound(danno, rng)` statico, `NPCRegistry.by_job`, `GameTime.hour/day/skip_to_hour`, `WorldSeed.rng_for`, `WesternTheme.apply`.
- `world.gd` aggiornato: crea `DuelManager` e documenta il tasto **T** nell'intestazione.
- Pronto per: Feature 15 (sistema lavori). La Feature 22 (eventi casuali) potrà riusare `DuelManager.challenge_npc/challenge_stranger` per il "duello casuale".

## Feature 15 — Sistema lavori ✅
- Dati in `data/jobs.json`: ordine dei mestieri, ranghi (Apprendista, Esperto dopo 5 turni, Maestro dopo 15, con moltiplicatore di paga), raggio della città (600 px), bonus paga per punto di statistica e cinque lavori con nome, descrizione, statistica chiave, paga base, durata del turno, fascia oraria, zona (`town`, `wilds`, `any`), requisiti (`needs_weapon`, `min_money`), reputazione per turno ed eventi. `JobDB` (`scripts/jobs/job_db.gd`) li carica; per nuovi lavori o eventi basta il JSON.
- Lavori: **Minatore** (fuori città, mattina, Forza: filoni ricchi e crolli con ferite), **Barista** (in città, pomeriggio/sera, Carisma: mance e risse), **Cacciatore** (fuori città, all'alba, serve arma da fuoco, Mira: pelli e predatori), **Mercenario** (ovunque, giorno, serve arma da fuoco: scorte, ingaggio pagato anche se scatta un'imboscata), **Commerciante** (in città, giorno, capitale minimo $30: investe fino al 40% dei soldi, max $150, e rivende con un ricarico che dipende da Carisma e reputazione presso i commercianti; il carico può essere rubato).
- Eventi nel JSON: probabilità, prova su statistica (`stat`/`diff`), rami `ok`/`fail` con testo, paga, danno, reputazione, perdita di carico; oppure `combat` (nemici e titolo).
- `JobState` (`scripts/jobs/job_state.gd`, solo in memoria): lavoro attuale, turni per lavoro (determinano il rango), guadagno di oggi e totale. Si azzera a ogni nuova partita (`JobManager.setup`).
- `JobSystem` (`scripts/jobs/job_system.gd`, logica senza UI): `can_work` (lavoro attivo, salute ≥ 15, fascia oraria, zona, arma, capitale), `run_shift` (simula il turno), `apply_result` (paga, danno con minimo salute 5, ferite via `WoundSystem.try_wound`, reputazione via `ReputationSystem.add`, rango e passaggio del tempo con `GameTime.skip_to_hour`).
- `JobPanel` (`scripts/ui/job_panel.gd`): elenco mestieri con rango, dettagli (paga, orari, zona, requisiti, rischi), "Prendi servizio / Lascia il lavoro", "Lavora un turno" con motivo del blocco nel suggerimento e nella riga di stato, cronaca del turno riga per riga, guadagno di oggi e totale. Esc o **L** chiudono.
- `JobManager` (`scripts/jobs/job_manager.gd`): tasto **L** apre il pannello (gioco in pausa). Se un turno provoca uno scontro (lupo, banditi), alla chiusura del pannello parte `CombatManager.start_encounter(nemici, titolo, false)`; finché non lo affronti non puoi iniziare un altro turno.
- Integrazione in `world.gd`: `JobManager` creato in `_build_town_nodes()` dopo `DuelManager`, con `message.connect(_prompt_hud.show_message)` e `setup(avatar, origin, _combat)`; suggerimento "L lavoro" nella riga informativa.
- Assunzioni da verificare: `CombatManager.start_encounter` accetta una lista di id nemici (`["lupo"]`, `["bandito"]`); `WeaponDB.weapon(id)`, `PlayerState.get_stat("forza"|"mira"|"carisma"|"resistenza")`, `ReputationSystem.value`.
- Pronto per: Feature 16 (economia dinamica: prezzi, domanda, offerta, mercato locale). I guadagni dei lavori e il ricarico del commerciante potranno dipendere dal mercato.

## Correzione collegamenti — NPC fermi ✅
- `data/npc_routines.json`: nuova sezione `idle_stroll` (intervallo 4-10 s, raggio 20-60 px); minatore, cacciatore, commerciante e mercenario ora la mattina alternano lavoro (60%) e passeggiata (40%) invece di restare fermi per tutta la fascia.
- `NPCRoutine`: da fermi (attività lavoro o chiacchiere) gli NPC fanno ogni tanto pochi passi lungo la strada intorno al loro posto (`_idle_tick`), senza uscire dall'area dei lotti.
- `NPCAvatar`: commento aggiornato (non è più "fermo").
- Lista correzioni collegamenti completata.

## Correzione collegamenti — Nuova partita (R) ✅
- `DialogueState.reset()` azzera informazioni apprese e reputazione (che vive lì); `BuildingActions.reset()` azzera il saldo della banca.
- `world.gd` (`_new_game`) li chiama dopo `PlayerState.new_character()`, quindi R riparte davvero da zero (missioni, lavori e ferite erano già azzerati).

## Correzione collegamenti — Duelli raggiungibili ✅
- `NPCPanel`: nuovo pulsante "Sfida a duello" (segnale `duel_requested`), nascosto per chi non duella (sceriffo, da `duels.json`).
- `NPCManager`: nasconde la scheda, toglie la pausa e inoltra `duel_requested`; `world.gd` lo collega a `DuelManager.challenge_npc`. Se manca un'arma da fuoco lo dice già la schermata del duello.

## Correzione collegamenti — Pubblico dei duelli ✅
- `DuelManager._audience_size` conta i cittadini realmente in strada entro `street_radius` (500 px) dal giocatore, non dentro edifici e senza lo sfidante, più 0-2 passanti e, a mezzogiorno, il bonus curiosi.
- `data/duels.json` (`audience`): tolti `base_min/base_max`, aggiunti `street_radius`, `passers_min`, `passers_max`; `noon_bonus` da 4 a 2.
- Nota: se il duello fa saltare il tempo a mezzogiorno, il pubblico è quello presente al momento della sfida.

## Correzione collegamenti — Caccia nel combattimento ✅
- Gli animali delle missioni di caccia ora si affrontano con il combattimento a turni: `QuestManager._on_animal` avvia `CombatManager.start_encounter([animale], ...)` e conta la preda solo se lo scontro finisce con vittoria (fuga: l'animale resta, si può riprovare). Niente più formula di tiro a parte; l'arma da fuoco o bianca in mano conta come in ogni scontro.
- `data/combat.json`: nuovi nemici `cervo` e `lepre` (insieme a `coyote`, i tre animali delle missioni).
- `data/quests.json`: rimossi `hunt_hit_base` / `hunt_hit_per_aim` (non più usati); suggerimento aggiornato.
- `world.gd`: `_quests.set_combat(_combat)` dopo la creazione del CombatManager.

## Correzione collegamenti — Lavori legati ai luoghi ✅
- `data/jobs.json`: nuova chiave `place` (kind `building`/`site`, id, raggio 170 px, label). Barista -> Saloon, Commerciante -> Banca, Minatore -> miniera fuori città (`site`: id e distanza 720-1000 px dalla città). Nuovo testo `need_place`.
- `JobSites` (`scripts/jobs/job_sites.gd`): registro dei luoghi (ingressi degli edifici + miniera); `JobSystem.can_work` blocca il turno se il giocatore non è nel raggio e dice dove andare. Cacciatore e mercenario restano legati alla sola zona.
- `JobManager.set_world(edifici, limiti)` (chiamato da `world.gd` dopo `setup`) registra i luoghi e crea il segnale della miniera (`JobSiteMarker`, posizione dal seed, quindi cambia tra partite).
- `JobPanel`: nei dettagli compare "Luogo: devi trovarti presso ...".

## Correzione collegamenti — Suggerimenti missioni con posizione ✅
- `QuestState.whereabouts(npc_id)`: dice dove si trova ora l'NPC leggendo i dati delle routine (`inside`, `position`): "a casa, di solito esce al mattino", "dentro: <edificio>", "in strada, davanti a: <edificio>" oppure "in strada".
- Tracker (in alto a destra), diario (Q) e testo di avanzamento di consegna e protezione mostrano la posizione del destinatario (o di chi ha dato la missione, quando va riportata) aggiornata ogni mezzo secondo. Nuovo `QuestState.ready_text` unifica i testi delle missioni pronte.

- Correzione miniera: nel primo test la miniera era comparsa dentro un lotto della città (la strada è lunga fino a 2600 px, più del raggio 720-1000 usato). `JobManager.set_world` ora riceve strada e lotti da evitare (margine 150 px) e fa fino a 120 tentativi; ripiego sotto la città.

## Correzione collegamenti — Pulizia funzioni inutilizzate ✅
- Rimosse perché mai chiamate (regola "niente sistemi creati ma non usati"): `NPCRegistry.at_workplace`, `GameTime.is_night`, `BuildingManager.get_building`, `DialogueDB.reputation_label`, `DialogueState.add_reputation`, `DuelManager.is_active`, `PlayerState.to_dict`, `UIFx.pulse`, `UIFx.count_to`, `WesternPanel.toggle`.
- Da riscrivere quando serviranno: `PlayerState.to_dict` va sostituito da un vero sistema di salvataggio (stato di giocatore, ferite, missioni, lavori, reputazione, banca); `UIFx.pulse/count_to` possono tornare per salute bassa e contatore soldi nell'HUD.

## Feature 16 — Economia dinamica ✅
- Dati in `data/economy.json`: 7 beni (cibo, alloggio, medicine, armi per ciò che compri; minerali, pelli, merci per ciò che il tuo lavoro vende), limiti dell'indice prezzo (0,6-1,8), elasticità, ritorno all'equilibrio, rumore giornaliero, dispersione locale e 7 eventi di mercato (carestia, carovana, nuovo filone, fame di minerali, inverno rigido, tensione in città, fiera).
- `EconomySystem` (`scripts/economy/economy_system.gd`, logica senza UI): ogni bene ha livello locale (dal seed, canale `economy`: ogni città ha prezzi diversi), offerta e domanda. `index(bene)` = locale x (domanda/offerta)^elasticità; `price(bene, base)` = indice di mercato poi reputazione presso i commercianti; `on_purchase` alza la domanda, `on_supply` alza l'offerta; `advance_to(giorno)` fa tornare domanda/offerta all'equilibrio, aggiunge rumore ed estrae eventi (deterministico per giorno); `trend`, `pct_text`, `news` per l'interfaccia.
- `EconomyManager` (`scripts/economy/economy_manager.gd`, creato da `world.gd`): azzera il mercato a ogni nuova partita, avanza i giorni (anche con salti di tempo, max 10) e mostra le notizie dal mercato nel messaggio a schermo; tasto **M** apre `MarketPanel` (`scripts/ui/market_panel.gd`, pausa mentre è aperto): indice di ogni bene con tendenza e colore (verde = conviene a te, rosso = no) e la notizia attuale.
- Negozi: `data/buildings.json` ha `good` sulle azioni (whiskey e stufato -> cibo, stanza -> alloggio, bende -> medicine, armi -> armi). `BuildingActions.price(azione)` sostituisce `ReputationSystem.price` ovunque; `execute` alza la domanda dopo ogni acquisto riuscito; `BuildingPanel` aggiorna i prezzi dei pulsanti dopo ogni acquisto.
- Lavori: `data/jobs.json` ha `good` e `supply` (minatore -> minerali, cacciatore -> pelli, commerciante -> merci, barista -> cibo). La paga di base del turno è moltiplicata per l'indice del bene, con riga "Mercato (...): +X%" nella cronaca; il ricarico del commerciante dipende dal mercato delle merci (`margin_market`); ogni turno aumenta l'offerta del bene (i prezzi calano se lavori sempre lo stesso mestiere). `JobPanel` mostra il mercato attuale.
- `world.gd`: crea `EconomyManager` e aggiunge M alla riga informativa.
- Pronto per: Feature 17 (sistema banca: deposito, prestiti, debiti, interessi); i tassi potranno dipendere dal mercato e dalla reputazione.

## Feature 17 — Sistema banca ✅
- Dati in `data/bank.json`: interesse del deposito (0,4% al giorno, tetto $25), fido per fascia di reputazione presso i commercianti (Odiato 0, Malvisto 40, Sconosciuto 100, Rispettato 300, Leggenda 600) più il deposito in cassa come garanzia, importi, tre durate (5, 10, 20 giorni con tasso diverso), tasso base 2% al giorno, commissione di apertura 3%, penali, effetti sulla reputazione e tutti i testi.
- `BankSystem` (`scripts/bank/bank_system.gd`, logica senza UI, stato in memoria): `deposit`, `withdraw`, `max_loan`, `block_reason`, `quote` (preventivo), `take_loan`, `repay`, `advance_to(giorno)`, `debt_total`, `has_debt`, `has_overdue`, `hud_text`. Il tasso del prestito = tasso base x reputazione (stessa fascia dei prezzi, `ReputationSystem.price_mult`) x mercato (media dell'indice dei beni che compri, `EconomySystem`) x durata scelta.
- Debiti: ogni giorno il debito matura interessi. Il giorno prima della scadenza arriva un avviso. Dopo la scadenza: penale del 5%, tasso doppio, reputazione presso i commercianti -4 e poi -1 al giorno. Dopo 5 giorni di ritardo la banca dichiara l'insolvenza: sequestra il deposito, reputazione -20 presso i commercianti e -6 presso i cittadini, rapporto con il banchiere -15, lista nera di 10 giorni senza credito; il debito residuo resta da saldare. Saldare in tempo dà +3 di reputazione (+1 se in ritardo). Massimo 2 prestiti aperti; con un debito scaduto non se ne ottengono altri.
- `BankManager` (`scripts/bank/bank_manager.gd`, creato da `world.gd`): fa scorrere i giorni della banca (anche dopo salti di tempo come dormire o svenire) e mostra gli avvisi a schermo.
- UI: `BankSection` (`scripts/ui/bank_section.gd`) dentro `BuildingPanel` per gli edifici con `"bank_ui": true` (la banca): deposito e ritiro rapidi, interessi guadagnati, elenco dei debiti con "Paga" ed "Estingui", nuovo prestito con scelta della durata (tasso di oggi) e dell'importo (anteprima di quanto restituirai). Tutto in uno ScrollContainer. L'HUD mostra la riga "Debito banca: $X" (rossa se scaduto), aggiornata ogni secondo.
- Dialoghi: nuove condizioni `debt` e `overdue`, segnaposto `{debt}`; il banchiere ha la scelta "Parliamo del mio debito." e una battuta diversa se il debito è scaduto; testi dei prestiti aggiornati.
- Modifiche a codice esistente: `BuildingActions` non ha più `bank_balance` né le azioni `bank_deposit`/`bank_withdraw` (ora in `BankSystem`); `BuildingActions.reset()` chiama `BankSystem.reset()` (nuova partita con R azzera conto e debiti). `buildings.json`: la banca ha `actions: []` e `bank_ui: true`.
- Da includere nel futuro salvataggio: `BankSystem` (`balance`, `interest_frac`, `interest_earned`, `loans`, `next_id`, `blacklist_until`, `last_day`).
- Pronto per: Feature 18 (proprietà: casa, negozio, terreno). Gli acquisti potranno finanziarsi con i prestiti della banca.

## Correzione — Errore di tipo nel pannello del mercato ✅
- `MarketPanel` (`scripts/ui/market_panel.gd`, riga 35): `var arrow := [...][indice]` non permette a GDScript di dedurre il tipo; ora è `var arrow: String = ...`. Errore presente dalla Feature 16.
- Controllati tutti gli script del progetto: non ci sono altri `:=` su valori non tipizzati dello stesso genere.
