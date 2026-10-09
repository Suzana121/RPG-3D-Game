class_name Interactable
extends Area3D

signal interacted(interactor: Node)

@export var prompt_text: String = "Interact"

func interact(interactor: Node) -> void:
	interacted.emit(interactor)
