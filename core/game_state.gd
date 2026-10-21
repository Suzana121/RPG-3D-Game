extends Node

signal flag_changed(flag: StringName, value: bool)

var _flags: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")


func get_flag(flag: StringName) -> bool:
	return _flags.get(flag, false)


func set_flag(flag: StringName, value: bool = true) -> void:
	if get_flag(flag) == value:
		return
	_flags[flag] = value
	flag_changed.emit(flag, value)


# ---------- Save / Load ----------

func get_save_key() -> String:
	return "game_state"


func save_data() -> Dictionary:
	return {"flags": _flags.duplicate()}


## Silent restore: no flag_changed signals. The world is being restored, not changed.
func load_data(data: Dictionary) -> void:
	_flags.clear()
	var flags: Dictionary = data.get("flags", {})
	for key in flags:
		# JSON turned our StringName keys into Strings, so convert them back
		_flags[StringName(key)] = bool(flags[key])
