class_name Player
extends CharacterBody3D
enum State { NORMAL, IN_DIALOGUE }

const PICKUP_SCENE := preload("res://systems/items/pickup.tscn")

@export var walk_speed := 4.0
@export var sprint_speed := 7.0
@export var jump_velocity := 4.5
@export var acceleration := 10.0
@export var turn_speed := 10.0

@onready var camera_rig: CameraRig = $CameraRig
@onready var model: Node3D = $Model
@onready var inventory: Inventory = $Inventory
@onready var health: Health = $Health


var state: State = State.NORMAL

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	camera_rig.camera_mode_changed.connect(_on_camera_mode_changed)
	inventory.changed.connect(_on_inventory_changed)
	health.changed.connect(func(cur, mx): print("Health: %d / %d" % [cur, mx]))
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_inventory_changed() -> void:
	print("--- Inventory ---")
	for stack in inventory.get_stacks():
		print("  %s x%d" % [stack.item.display_name, stack.quantity])
	print("  Weight: %.1f / %.1f" % [inventory.get_total_weight(), inventory.max_weight])



func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if state == State.NORMAL and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Movement direction relative to the camera, not the world
	var input_dir := Vector2.ZERO
	if state == State.NORMAL:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (camera_rig.get_flat_basis() * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	velocity.x = lerp(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = lerp(velocity.z, direction.z * speed, acceleration * delta)

	_rotate_model(direction, delta)
	move_and_slide()


func _rotate_model(direction: Vector3, delta: float) -> void:
	if camera_rig.is_first_person:
		# First person: the body always faces where the camera faces
		model.rotation.y = camera_rig.rotation.y
	elif direction.length() > 0.01:
		# Third person: the character gradually turns toward the walking direction
		var target_yaw := atan2(-direction.x, -direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, turn_speed * delta)


func _on_camera_mode_changed(is_first_person: bool) -> void:
	model.visible = not is_first_person	
	
	
func use_item(item: ItemData) -> void:
	if item.use(self):
		inventory.remove_item(item.id)
		
func _unhandled_input(event: InputEvent) -> void:

	if event is InputEventKey and event.pressed and event.keycode == KEY_K:
		health.take_damage(30)
		
func drop_item(item: ItemData, amount: int = 1) -> void:
	# Remove first: if it fails, nothing spawns (no duping)
	if not inventory.remove_item(item.id, amount):
		return
	var pickup := PICKUP_SCENE.instantiate() as Pickup
	pickup.item = item              # data BEFORE entering the tree
	pickup.quantity = amount
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = _get_drop_position()   # position AFTER


func _get_drop_position() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	return global_position + forward * 1.5 + Vector3.UP * 0.5
	
func _on_dialogue_started(_npc: NPC) -> void:
	state = State.IN_DIALOGUE
	camera_rig.input_enabled = false
	InputMode.request(self, false, true)

func _on_dialogue_ended() -> void:
	state = State.NORMAL
	camera_rig.input_enabled = true
	InputMode.release(self)
	
	
func can_open_menus() -> bool:
	print("state: ", State.keys()[state], " | requests: ", InputMode._requests.keys())
	return state == State.NORMAL and InputMode.is_free()
