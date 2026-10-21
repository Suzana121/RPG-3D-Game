class_name Pickup
extends StaticBody3D

@export var item: ItemData
@export_range(1, 99999) var quantity: int = 1

## True for pickups created while playing (dropped items).
## False for pickups placed in the level in the editor.
var is_dynamic := false

@onready var _interactable: Interactable = $Interactable
@onready var _placeholder: MeshInstance3D = $Placeholder

func _ready() -> void:
	add_to_group("pickups")
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

func _on_interacted(interactor: Node) -> void:
	if _taken:
		return
	var inv := interactor.get_node_or_null("Inventory") as Inventory
	if inv == null:
		return
	var added := inv.add_item(item, quantity)
	if added > 0:
		_taken = true
		if not is_dynamic:
			WorldState.mark_removed(self)  # remember: this placed item is gone
		EventBus.item_picked_up.emit(item, added)
		queue_free()
