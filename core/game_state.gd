extends Node

signal flag_changed(flag: StringName, value: bool)

var _flags: Dictionary = {}


func get_flag(flag: StringName) -> bool:
	return _flags.get(flag, false)


func set_flag(flag: StringName, value: bool = true) -> void:
	if get_flag(flag) == value:
		return
	_flags[flag] = value
	flag_changed.emit(flag, value)
