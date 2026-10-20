extends Node
## The ONLY place that writes get_tree().paused and Input.mouse_mode.
## Screens request what they need and release it when they close.

signal mode_changed

# requester (Node) → {"pause": bool, "mouse": bool, "on_exit": Callable}
var _requests: Dictionary = {}


func _ready() -> void:
	_apply()


func request(requester: Node, pause_game: bool, show_mouse: bool) -> void:
	if _requests.has(requester):
		_requests[requester]["pause"] = pause_game
		_requests[requester]["mouse"] = show_mouse
	else:
		# If the requester is freed without releasing (scene change, save/load),
		# release automatically so the game never gets stuck paused.
		var on_exit := release.bind(requester)
		requester.tree_exiting.connect(on_exit)
		_requests[requester] = {"pause": pause_game, "mouse": show_mouse, "on_exit": on_exit}
	_apply()


func release(requester: Node) -> void:
	if not _requests.has(requester):
		return
	requester.tree_exiting.disconnect(_requests[requester]["on_exit"])
	_requests.erase(requester)
	_apply()


## True when no screen holds a request: gameplay has full control.
func is_free() -> bool:
	return _requests.is_empty()


func _apply() -> void:
	var pause := false
	var mouse := false
	for entry in _requests.values():
		pause = pause or entry["pause"]
		mouse = mouse or entry["mouse"]
	get_tree().paused = pause
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mouse else Input.MOUSE_MODE_CAPTURED
	mode_changed.emit()
