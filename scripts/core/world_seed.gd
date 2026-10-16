extends Node
## Seed procedurale globale.
## Ogni sistema chiede il proprio generatore con rng_for("nome"):
## stesso seed + stesso canale = stessa sequenza, canali diversi = sequenze indipendenti.

signal seed_changed(new_seed: int)

var world_seed: int = 0

func new_game(forced_seed: int = 0) -> void:
	if forced_seed != 0:
		world_seed = forced_seed
	else:
		var r := RandomNumberGenerator.new()
		r.randomize()
		world_seed = r.randi_range(1, 999999999)
	seed_changed.emit(world_seed)

func rng_for(channel: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d:%s" % [world_seed, channel])
	return r
