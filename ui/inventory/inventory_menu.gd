extends CanvasLayer

@onready var item_list: ItemList = %ItemList
@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var stats_label: Label = %StatsLabel
@onready var weight_label: Label = %WeightLabel
@onready var category_tabs: TabBar = %CategoryTabs

var _inventory: Inventory
var _player: Player
var _current_tab := 0

func _ready() -> void:
	visible = false
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player:
		_inventory = _player.inventory
		_inventory.changed.connect(_refresh)
	item_list.item_activated.connect(_on_item_activated)
	
	category_tabs.add_tab("All")
	for key in ItemData.Category.keys():
		category_tabs.add_tab(key.capitalize())
	category_tabs.tab_changed.connect(_on_tab_changed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if not visible and _player and not _player.can_open_menus():
			get_viewport().set_input_as_handled()
			return
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("drop_item"):
		_drop_selected()
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
		if not _matches_tab(stack.item):
			continue
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
	
func _on_tab_changed(tab: int) -> void:
	_current_tab = tab
	_refresh()


func _matches_tab(item: ItemData) -> bool:
	return _current_tab == 0 or item.category == _current_tab - 1
	
func _on_item_activated(index: int) -> void:
	var stack: ItemStack = item_list.get_item_metadata(index)
	_player.use_item(stack.item)
	
func _drop_selected() -> void:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return
	var stack: ItemStack = item_list.get_item_metadata(selected[0])
	_player.drop_item(stack.item)
