class_name Pickup
extends StaticBody3D

@export var item: ItemData
@export_range(1, 99999) var quantity: int = 1

@onready var _interactable: Interactable = $Interactable
@onready var _placeholder: MeshInstance3D = $Placeholder

func _ready() -> void:
	if item == null:
		push_warning("Pickup '%s' has no item assigned." % name)
		return
	_interactable.prompt_text = _build_prompt()
	_interactable.interacted.connect(_on_interacted)
	if item.world_model:
		add_child(item.world_model.instantiate())
		_placeholder.hide()

func _build_prompt() -> String:
	if quantity > 1:
		return "Take %s (%d)" % [item.display_name, quantity]
	return "Take %s" % item.display_name


var _taken := false

func _on_interacted(_interactor = null) -> void:
	if _taken:
		return
	_taken = true
	EventBus.item_picked_up.emit(item, quantity)
	queue_free()
