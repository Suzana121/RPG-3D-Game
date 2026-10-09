extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.item_picked_up.connect(
		func(item, qty): print("Picked up %s x%d" % [item.display_name, qty]))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
