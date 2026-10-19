extends Node

signal dialogue_started(npc: NPC)
signal node_shown(speaker: String, text: String, choices: Array[DialogueChoice])
signal dialogue_ended

var _dialogue: DialogueData
var _npc: NPC
var _current: DialogueNode


func is_active() -> bool:
	return _dialogue != null


func start(dialogue: DialogueData, npc: NPC) -> void:
	if is_active() or dialogue == null:
		return
	var first := dialogue.get_start_node()
	if first == null:
		return

	_dialogue = dialogue
	_npc = npc
	# If the NPC is removed mid-conversation, end the dialogue safely.
	_npc.tree_exiting.connect(end, CONNECT_ONE_SHOT)

	dialogue_started.emit(npc)
	_show(first)


func choose(index: int) -> void:
	if not is_active():
		return
	if index < 0 or index >= _current.choices.size():
		return

	var choice := _current.choices[index]
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
	_current = null
	dialogue_ended.emit()


func _show(node: DialogueNode) -> void:
	_current = node
	node_shown.emit(_resolve_speaker(node), node.text, node.choices)


func _resolve_speaker(node: DialogueNode) -> String:
	if node.speaker != "":
		return node.speaker
	return _npc.display_name 	
