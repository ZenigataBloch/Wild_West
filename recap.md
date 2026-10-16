# Recap sviluppo — Wild West

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
