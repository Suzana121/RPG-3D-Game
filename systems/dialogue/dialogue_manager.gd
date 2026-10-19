extends Node

signal dialogue_started(npc: NPC)
signal node_shown(speaker: String, text: String, choices: Array[DialogueChoice])
signal dialogue_ended

var _dialogue: DialogueData
var _npc: NPC
var _player: Player
var _current: DialogueNode
var _visible_choices: Array[DialogueChoice] = []


func is_active() -> bool:
	return _dialogue != null


func start(dialogue: DialogueData, npc: NPC, player: Player) -> void:
	if is_active() or dialogue == null:
		return
	var first := dialogue.get_start_node()
	if first == null:
		return

	_dialogue = dialogue
	_npc = npc
	_player = player
	# If the NPC is removed mid-conversation, end the dialogue safely.
	_npc.tree_exiting.connect(end, CONNECT_ONE_SHOT)

	dialogue_started.emit(npc)
	_show(first)


func choose(index: int) -> void:
	if not is_active():
		return
	if index < 0 or index >= _visible_choices.size():
		return

	var choice := _visible_choices[index]
	for action in choice.actions:
		if action != null:
			action.execute(_player)

	if choice.ends_dialogue():
		end()
		return

	var next := _dialogue.get_node_by_id(choice.next_id)
	if next == null:
		end()
		return
	_show(next)


func end() -> void:
	if not is_active():
		return
	if is_instance_valid(_npc) and _npc.tree_exiting.is_connected(end):
		_npc.tree_exiting.disconnect(end)

	_dialogue = null
	_npc = null
	_player = null
	_current = null
	_visible_choices = []
	dialogue_ended.emit()


func _show(node: DialogueNode) -> void:
	_current = node
	_visible_choices = _get_visible_choices(node)
	node_shown.emit(_resolve_speaker(node), node.text, _visible_choices)


func _get_visible_choices(node: DialogueNode) -> Array[DialogueChoice]:
	var result: Array[DialogueChoice] = []
	for choice in node.choices:
		if _is_available(choice):
			result.append(choice)
	if result.is_empty():
		result.append(_make_end_choice())
	return result


func _is_available(choice: DialogueChoice) -> bool:
	for condition in choice.conditions:
		if condition != null and not condition.is_met(_player):
			return false
	return true


func _make_end_choice() -> DialogueChoice:
	var choice := DialogueChoice.new()
	choice.text = "[End conversation]"
	return choice


func _resolve_speaker(node: DialogueNode) -> String:
	if node.speaker != "":
		return node.speaker
	return _npc.display_name
