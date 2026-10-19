class_name NPC
extends CharacterBody3D

@export var display_name: String = "Stranger"
@export var dialogue: DialogueData

@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	_interactable.prompt_text = "Talk to %s" % display_name
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(_interactor: Node) -> void:
	if dialogue == null:
		return
	DialogueManager.start(dialogue, self)
