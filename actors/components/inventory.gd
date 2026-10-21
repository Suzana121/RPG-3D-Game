class_name Inventory
extends Node

## Emitted whenever the contents change. UI listens to this.
signal changed

@export var max_weight: float = 300.0

var _stacks: Array[ItemStack] = []

func _ready() -> void:
	changed.connect(func(): EventBus.inventory_changed.emit(self))


func add_item(item: ItemData, amount: int = 1) -> int:
	var added := _add_silent(item, amount)
	if added > 0:
		changed.emit()
	return added


## The stacking rules, without emitting. Used by add_item and load_data.
func _add_silent(item: ItemData, amount: int) -> int:
	if item == null or amount <= 0:
		return 0

	var remaining := amount
	# 1. Top up existing stacks of the same item
	for stack in _stacks:
		if remaining == 0:
			break
		if stack.item.id == item.id and stack.quantity < item.max_stack:
			var moved := mini(item.max_stack - stack.quantity, remaining)
			stack.quantity += moved
			remaining -= moved
	# 2. Whatever is left goes into new stacks
	while remaining > 0:
		var moved := mini(item.max_stack, remaining)
		_stacks.append(ItemStack.new(item, moved))
		remaining -= moved

	return amount - remaining


func remove_item(item_id: StringName, amount: int = 1) -> bool:
	# Validate first: all-or-nothing
	if amount <= 0 or count_of(item_id) < amount:
		return false

	var remaining := amount
	# Loop backwards so removing stacks doesn't skip any
	for i in range(_stacks.size() - 1, -1, -1):
		if remaining == 0:
			break
		var stack := _stacks[i]
		if stack.item.id != item_id:
			continue
		var taken := mini(stack.quantity, remaining)
		stack.quantity -= taken
		remaining -= taken
		if stack.quantity == 0:
			_stacks.remove_at(i)

	changed.emit()
	return true


func count_of(item_id: StringName) -> int:
	var total := 0
	for stack in _stacks:
		if stack.item.id == item_id:
			total += stack.quantity
	return total


func has_item(item_id: StringName, amount: int = 1) -> bool:
	return count_of(item_id) >= amount


func get_total_weight() -> float:
	var total := 0.0
	for stack in _stacks:
		total += stack.item.weight * stack.quantity
	return total


func is_overencumbered() -> bool:
	return get_total_weight() > max_weight


func get_stacks() -> Array[ItemStack]:
	return _stacks


# ---------- Save / Load ----------

func save_data() -> Dictionary:
	var items := []
	for stack in _stacks:
		items.append({"id": str(stack.item.id), "qty": stack.quantity})
	return {"items": items}


func load_data(data: Dictionary) -> void:
	_stacks.clear()
	for entry in data.get("items", []):
		var item: ItemData = Database.get_item(StringName(entry.get("id", "")))
		if item == null:
			push_warning("Inventory: unknown item '%s' in save, skipping" % entry.get("id"))
			continue
		# Goes through the normal stacking rules, so a save stays valid even if max_stack changes
		_add_silent(item, int(entry.get("qty", 0)))
	changed.emit()  # once, after everything is restored
