class_name Interactable
extends Node2D
## Punto interattivo nel mondo. Il giocatore, avvicinandosi (entro "radius"),
## vede "[E] <prompt>"; premendo E scatta il segnale "interacted".
## Le feature future (edifici, NPC, bacheca) useranno questo componente.

signal interacted

@export var prompt: String = "Interagisci"
@export var message: String = ""
@export var radius: float = 90.0

func _ready() -> void:
	add_to_group("interactable")

func interact() -> void:
	interacted.emit()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 7, Color(1.0, 0.85, 0.3, 0.85))
	draw_arc(Vector2.ZERO, 11, 0.0, TAU, 24, Color(0.2, 0.1, 0.0, 0.9), 2.0)
