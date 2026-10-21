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
const SAVE_VERSION := 2
const QUICKSAVE := "quicksave"
const AUTOSAVE := "autosave"
const MANUAL_PREFIX := "save_"
## Seconds of actual play (paused time doesn't count) between timed autosaves.
const AUTOSAVE_INTERVAL := 300.0

var _is_loading := false
var _autosave_pending := false
var _autosave_timer: Timer


func _ready() -> void:
	# The timer pauses together with the game: time in menus doesn't count.
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL
	_autosave_timer.timeout.connect(request_autosave)
	add_child(_autosave_timer)
	_autosave_timer.start()
	# Story moments are natural autosave points (Skyrim: entering a dungeon, finishing a quest).
	QuestManager.quest_stage_changed.connect(request_autosave.unbind(2))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quicksave"):
		save_game(QUICKSAVE)
	elif event.is_action_pressed("quickload"):
		load_game(QUICKSAVE)


## An autosave is a REQUEST: it waits until saving is safe (e.g. the dialogue ended).
func _process(_delta: float) -> void:
	if _autosave_pending and can_save_or_load() and InputMode.is_free():
		_autosave_pending = false
		save_game(AUTOSAVE)


# ---------- Public API ----------

## Like Skyrim: no saving or loading in the middle of a conversation.
## (Menus don't block it anymore: the pause menu itself is open while you save.)
func can_save_or_load() -> bool:
	if _is_loading:
		return false
	var player := get_tree().get_first_node_in_group("player") as Player
	return player != null and player.state == Player.State.NORMAL


func request_autosave() -> void:
	_autosave_pending = true


func save_game(slot: String) -> bool:
	if not can_save_or_load():
		print("SaveManager: can't save right now")
		return false

	var scene := get_tree().current_scene
	var data := {
		"version": SAVE_VERSION,
		"meta": {
			"title": slot_title(slot),
			"location": scene.name.capitalize(),  # "TestLevel" → "Test Level"
			"saved_at": Time.get_datetime_string_from_system(false, true),
			"unix_time": Time.get_unix_time_from_system(),
		},
		"scene": scene.scene_file_path,
		"nodes": _collect(),
	}
	if not _write_json(_slot_path(slot), data):
		return false
	_autosave_timer.start()  # any save resets the autosave clock
	print("SaveManager: saved '%s'" % slot)
	game_saved.emit(slot)
	return true


func load_game(slot: String) -> bool:
	if not can_save_or_load():
		print("SaveManager: can't load right now")
		return false
	var data := _migrate(_read_json(_slot_path(slot)))
	if data.is_empty():
		return false

	_is_loading = true
	_autosave_pending = false
	# 1. Reload the level: the world goes back to exactly how it was designed.
	var old_scene_id := get_tree().current_scene.get_instance_id()
	get_tree().change_scene_to_file(data["scene"])
	await _wait_for_new_scene(old_scene_id)
	# 2. Give every saveable its piece. Missing piece → {} → defaults.
	_apply(data["nodes"])
	_is_loading = false
	_autosave_timer.start()
	print("SaveManager: loaded '%s'" % slot)
	game_loaded.emit(slot)
	return true


func has_save(slot: String) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_save(slot: String) -> void:
	DirAccess.remove_absolute(_slot_path(slot))


## Every readable save, newest first. Each entry: {slot, title, location, saved_at, unix_time, is_manual}
func list_saves() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return result  # no saves folder yet
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var slot := file.get_basename()
		var data := _migrate(_read_json(_slot_path(slot), true))
		if data.is_empty():
			continue  # damaged file: don't show it
		var meta: Dictionary = data["meta"]
		result.append({
			"slot": slot,
			"title": slot_title(slot),
			"location": meta.get("location", "?"),
			"saved_at": meta.get("saved_at", ""),
			"unix_time": float(meta.get("unix_time", 0)),
			"is_manual": slot.begins_with(MANUAL_PREFIX),
		})
	result.sort_custom(func(a, b): return a["unix_time"] > b["unix_time"])
	return result


## "save_001", "save_002", ... always one more than the highest existing number.
func next_manual_slot() -> String:
	var highest := 0
	for entry in list_saves():
		if entry["is_manual"]:
			highest = maxi(highest, entry["slot"].trim_prefix(MANUAL_PREFIX).to_int())
	return MANUAL_PREFIX + "%03d" % (highest + 1)


func slot_title(slot: String) -> String:
	match slot:
		QUICKSAVE: return "Quicksave"
		AUTOSAVE: return "Autosave"
	if slot.begins_with(MANUAL_PREFIX):
		return "Save %d" % slot.trim_prefix(MANUAL_PREFIX).to_int()
	return slot


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


## quiet = true: don't report problems (the save list checks every file, often).
func _read_json(path: String, quiet := false) -> Dictionary:
	if not FileAccess.file_exists(path):
		if not quiet:
			print("SaveManager: no save at %s" % path)
		return {}
	var json := JSON.new()  # unlike JSON.parse_string, this doesn't print its own errors
	var ok := json.parse(FileAccess.get_file_as_string(path)) == OK
	var parsed = json.data
	if not ok or not (parsed is Dictionary) or not parsed.has("scene") or not parsed.has("nodes"):
		if not quiet:
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
	if version < 2:
		# v1 saves had no "meta" block. Build one from what they do have.
		data["meta"] = {
			"location": String(data["scene"]).get_file().get_basename().capitalize(),
			"saved_at": String(data.get("saved_at", "")).replace("T", " "),
			"unix_time": Time.get_unix_time_from_datetime_string(data.get("saved_at", "")),
		}
		version = 2
	data["version"] = version
	return data
