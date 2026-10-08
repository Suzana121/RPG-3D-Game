class_name CameraRig
extends Node3D

signal camera_mode_changed(is_first_person: bool)

@export var mouse_sensitivity := 0.003
@export var third_person_distance := 3.5
@export var zoom_speed := 10.0
@export var min_pitch_deg := -80.0
@export var max_pitch_deg := 70.0

@onready var pitch: Node3D = $Pitch
@onready var spring_arm: SpringArm3D = $Pitch/SpringArm3D

var is_first_person := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Keep the arm from "colliding" with the player's own body
	spring_arm.add_excluded_object(get_parent().get_rid())
	spring_arm.spring_length = third_person_distance


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch.rotation.x = clamp(
			pitch.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(min_pitch_deg),
			deg_to_rad(max_pitch_deg)
		)
	elif event.is_action_pressed("toggle_camera"):
		is_first_person = not is_first_person
		camera_mode_changed.emit(is_first_person)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var target_length := 0.0 if is_first_person else third_person_distance
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_length, zoom_speed * delta)


## The "flat" direction the camera is facing, used by movement
func get_flat_basis() -> Basis:
	return global_transform.basis
