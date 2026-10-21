extends Node
## Saves and loads the game.
##
## Every node in the "persist" group is a saveable. It must have:
##   get_save_key() -> String      a unique, stable name for its piece of the save
##   save_data() -> Dictionary     its state, using JSON-friendly values only
##   load_data(data: Dictionary)   restore that state ({} means "go back to defaults")
##
## SaveManager doesn't know what a quest or an inventory is. It only collects and hands back.

signal game_saved(slot: String)
signal game_loaded(slot: String)

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 1
const QUICKSAVE := "quicksave"

var _is_loading := false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quicksave"):
		save_game(QUICKSAVE)
	elif event.is_action_pressed("quickload"):
		load_game(QUICKSAVE)


# ---------- Public API ----------

## Like Skyrim: no saving in the middle of a conversation or with a menu open.
func can_save_or_load() -> bool:
	if _is_loading:
		return false
	var player := get_tree().get_first_node_in_group("player") as Player
	return player != null and player.state == Player.State.NORMAL and InputMode.is_free()


func save_game(slot: String) -> bool:
	if not can_save_or_load():
		print("SaveManager: can't save right now")
		return false

	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"scene": get_tree().current_scene.scene_file_path,
		"nodes": _collect(),
	}
	if not _write_json(_slot_path(slot), data):
		return false
	print("SaveManager: saved '%s'" % slot)
	game_saved.emit(slot)
	return true


func load_game(slot: String) -> bool:
	if not can_save_or_load():
		print("SaveManager: can't load right now")
		return false
	var data := _read_json(_slot_path(slot))
	data = _migrate(data)
	if data.is_empty():
		return false

	_is_loading = true
	# 1. Reload the level: the world goes back to exactly how it was designed.
	var old_scene_id := get_tree().current_scene.get_instance_id()
	get_tree().change_scene_to_file(data["scene"])
	await _wait_for_new_scene(old_scene_id)
	# 2. Give every saveable its piece. Missing piece → {} → defaults.
	_apply(data["nodes"])
	_is_loading = false
	print("SaveManager: loaded '%s'" % slot)
	game_loaded.emit(slot)
	return true


func has_save(slot: String) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


# ---------- Helpers for saveables (JSON has no Vector3) ----------

func vec3_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func array_to_vec3(a: Array, fallback := Vector3.ZERO) -> Vector3:
	if a.size() != 3:
		return fallback
	return Vector3(a[0], a[1], a[2])


# ---------- Internals ----------

func _collect() -> Dictionary:
	var nodes := {}
	for node in get_tree().get_nodes_in_group("persist"):
		if not node.has_method("save_data"):
			push_warning("SaveManager: %s is in 'persist' but has no save_data()" % node.name)
			continue
		var key: String = node.get_save_key()
		if nodes.has(key):
			push_error("SaveManager: duplicate save key '%s'" % key)
			continue
		nodes[key] = node.save_data()
	return nodes


func _apply(nodes: Dictionary) -> void:
	for node in get_tree().get_nodes_in_group("persist"):
		if node.has_method("load_data"):
			node.load_data(nodes.get(node.get_save_key(), {}))


## change_scene_to_file is deferred: the new scene only appears at the end of the frame.
func _wait_for_new_scene(old_scene_id: int) -> void:
	while true:
		var current := get_tree().current_scene
		if current != null and current.get_instance_id() != old_scene_id:
			return
		await get_tree().process_frame


func _slot_path(slot: String) -> String:
	return SAVE_DIR.path_join(slot + ".json")


func _write_json(path: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	# Write to a temp file first, then swap it in.
	# If the game crashes mid-write, the old save is still intact.
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: can't write %s (%s)" % [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		push_error("SaveManager: can't finish writing %s (%s)" % [path, error_string(err)])
		return false
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		print("SaveManager: no save at %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not parsed.has("scene") or not parsed.has("nodes"):
		push_error("SaveManager: %s is damaged or not a save file" % path)
		return {}
	return parsed


## Upgrades old saves to the current format, one version at a time.
func _migrate(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var version := int(data.get("version", 0))
	if version > SAVE_VERSION:
		push_error("SaveManager: save is from a newer game version (%d)" % version)
		return {}
	# When the format changes, bump SAVE_VERSION and add a step here, e.g.:
	# if version < 2:
	#     data["nodes"]["player"]["stamina"] = 100
	#     version = 2
	data["version"] = version
	return data
