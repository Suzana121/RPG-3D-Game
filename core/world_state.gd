extends Node
## Remembers how the player changed each level ("base + changes"):
##   removed: items placed in the level (.tscn) that were taken
##   dropped: items that didn't exist in the level, created by the player
## On load, SaveManager reloads the level from its .tscn (the base),
## then this script applies the changes on top.

const PICKUP_SCENE := preload("res://systems/items/pickup.tscn")

# scene file path → {"removed": [node paths], "dropped": [{id, qty, position}]}
var _scenes: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")


## Called by a placed Pickup when it's taken.
func mark_removed(node: Node) -> void:
	var scene := get_tree().current_scene
	var entry := _entry(scene.scene_file_path)
	# The node's path inside the level is its identity, e.g. "irondagger1"
	var path := str(scene.get_path_to(node))
	if not path in entry["removed"]:
		entry["removed"].append(path)


## The ONE place that creates pickups at runtime (dropping, loading).
func spawn_pickup(item: ItemData, quantity: int, position: Vector3) -> Pickup:
	var pickup := PICKUP_SCENE.instantiate() as Pickup
	pickup.item = item              # data BEFORE entering the tree
	pickup.quantity = quantity
	pickup.is_dynamic = true
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = position   # position AFTER
	return pickup


# ---------- Save / Load ----------

func get_save_key() -> String:
	return "world"


func save_data() -> Dictionary:
	# Dropped items aren't tracked one by one: the live nodes ARE the truth,
	# so we just take a snapshot of them at save time.
	var entry := _entry(get_tree().current_scene.scene_file_path)
	var dropped := []
	for pickup in get_tree().get_nodes_in_group("pickups"):
		if pickup.is_dynamic and pickup.item and not pickup.is_queued_for_deletion():
			dropped.append({
				"id": str(pickup.item.id),
				"qty": pickup.quantity,
				"position": SaveManager.vec3_to_array(pickup.global_position),
			})
	entry["dropped"] = dropped
	return {"scenes": _scenes.duplicate(true)}


func load_data(data: Dictionary) -> void:
	_scenes.clear()
	var scenes: Dictionary = data.get("scenes", {})
	for scene_path in scenes:
		var saved: Dictionary = scenes[scene_path]
		_scenes[scene_path] = {
			"removed": Array(saved.get("removed", [])),
			"dropped": Array(saved.get("dropped", [])),
		}
	_apply_to_current_scene()


func _apply_to_current_scene() -> void:
	var scene := get_tree().current_scene
	var entry := _entry(scene.scene_file_path)

	for path in entry["removed"]:
		var node := scene.get_node_or_null(NodePath(path))
		if node:
			node.queue_free()
		else:
			# Someone renamed or deleted the node in the editor. Harmless: nothing to remove.
			push_warning("WorldState: no node '%s' to remove" % path)

	for d in entry["dropped"]:
		var item := Database.get_item(StringName(d.get("id", "")))
		if item == null:
			push_warning("WorldState: unknown dropped item '%s', skipping" % d.get("id"))
			continue
		spawn_pickup(item, int(d.get("qty", 1)), SaveManager.array_to_vec3(d.get("position", [])))
	# They're live nodes now; the next save takes a fresh snapshot.
	entry["dropped"] = []


func _entry(scene_path: String) -> Dictionary:
	if not _scenes.has(scene_path):
		_scenes[scene_path] = {"removed": [], "dropped": []}
	return _scenes[scene_path]
