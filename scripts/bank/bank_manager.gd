class_name BankManager
extends Node
## Fa scorrere i giorni della banca (BankSystem): interessi sul deposito, interessi e scadenze dei
## prestiti, penali e insolvenza, anche dopo salti di tempo (dormire, svenire). Creato da world.gd;
## il segnale message va collegato all'HUD come per gli altri manager.

signal message(text: String)


func _process(_delta: float) -> void:
	var day := int(GameTime.day)
	if day == BankSystem.last_day:
		return
	var msgs := BankSystem.advance_to(day)
	if not msgs.is_empty():
		message.emit("\n".join(msgs))
