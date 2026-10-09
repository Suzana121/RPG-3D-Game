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
		current_target = new_target
		EventBus.interaction_target_changed.emit(current_target)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current_target:
		current_target.interact(owner)
