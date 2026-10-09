class_name InteractionRay
extends RayCast3D

@export var max_reach: float = 2.5

var current_target: Interactable = null

func _ready() -> void:
	add_exception(owner)

func _physics_process(_delta: float) -> void:
	var new_target: Interactable = null
	if is_colliding():
		new_target = get_collider() as Interactable
		if new_target and owner.global_position.distance_to(get_collision_point()) > max_reach:
			new_target = null

	if new_target != current_target:
		_set_target(new_target)

func _set_target(new_target: Interactable) -> void:
	if current_target and current_target.tree_exiting.is_connected(_on_target_exiting):
		current_target.tree_exiting.disconnect(_on_target_exiting)
	current_target = new_target
	if current_target:
		current_target.tree_exiting.connect(_on_target_exiting)
	EventBus.interaction_target_changed.emit(current_target)

func _on_target_exiting() -> void:
	_set_target(null)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and is_instance_valid(current_target):
		current_target.interact(owner)
