extends CanvasLayer

@onready var item_list: ItemList = %ItemList
@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var stats_label: Label = %StatsLabel
@onready var weight_label: Label = %WeightLabel

var _inventory: Inventory


func _ready() -> void:
	visible = false
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_inventory = player.get_node("Inventory")
		_inventory.changed.connect(_refresh)
	item_list.item_selected.connect(_on_item_selected)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	item_list.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh() -> void:
	# No point redrawing a hidden screen; open() refreshes anyway
	if not visible or _inventory == null:
		return
	item_list.clear()
	for stack in _inventory.get_stacks():
		var text := stack.item.display_name
		if stack.quantity > 1:
			text += "  (%d)" % stack.quantity
		var index := item_list.add_item(text, stack.item.icon)
		item_list.set_item_metadata(index, stack)
	weight_label.text = "Weight: %.1f / %.1f" % [_inventory.get_total_weight(), _inventory.max_weight]
	_show_details(null)


func _on_item_selected(index: int) -> void:
	_show_details(item_list.get_item_metadata(index))


func _show_details(stack: ItemStack) -> void:
	if stack == null:
		name_label.text = ""
		description_label.text = ""
		stats_label.text = ""
		return
	var item := stack.item
	name_label.text = item.display_name
	description_label.text = item.description
	var stats := "Weight: %.1f    Value: %d" % [item.weight, item.value]
	if item is WeaponData:
		stats += "\nDamage: %s    Speed: %s" % [item.damage, item.attack_speed]
	stats_label.text = stats
