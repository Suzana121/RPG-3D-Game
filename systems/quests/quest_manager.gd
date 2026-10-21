extends Node

signal quest_started(quest: QuestData)
signal quest_stage_changed(quest: QuestData, stage: QuestStage)
signal quest_completed(quest: QuestData)

# Runtime state only. Key: quest id → {"quest", "status", "stage"}
var _states: Dictionary = {}
var _check_queued := false


func _ready() -> void:
	add_to_group("persist")
	# unbind(N) drops the N arguments the signal sends. We only care THAT something changed.
	GameState.flag_changed.connect(_queue_check.unbind(2))
	EventBus.inventory_changed.connect(_queue_check.unbind(1))


# ---------- Commands ----------

func start_quest(quest: QuestData) -> void:
	if quest == null:
		push_error("QuestManager: start_quest called with null quest")
		return
	if get_status(quest) != QuestData.Status.NOT_STARTED:
		return  # idempotent: starting twice does nothing
	var first := quest.get_first_stage()
	if first == null:
		push_error("QuestManager: quest '%s' has no stages" % quest.id)
		return

	_states[quest.id] = {"quest": quest, "status": QuestData.Status.ACTIVE, "stage": -1}
	quest_started.emit(quest)
	set_stage(quest, first.stage_id)


func set_stage(quest: QuestData, stage_id: int) -> void:
	if get_status(quest) != QuestData.Status.ACTIVE:
		push_warning("QuestManager: set_stage on inactive quest '%s'" % quest.id)
		return
	var state: Dictionary = _states[quest.id]
	if stage_id <= state["stage"]:
		return  # forward-only: repeated dialogue can't rewind a quest
	var stage := quest.get_stage(stage_id)
	if stage == null:
		push_error("QuestManager: quest '%s' has no stage %d" % [quest.id, stage_id])
		return

	state["stage"] = stage_id
	quest_stage_changed.emit(quest, stage)

	var player := _get_player()
	for action in stage.on_enter_actions:
		if action:
			action.execute(player)

	if stage.completes_quest:
		_complete(quest)
	else:
		_queue_check()  # the new stage might already be satisfied (ore collected earlier)


# ---------- Queries ----------

func get_status(quest: QuestData) -> QuestData.Status:
	if quest == null or not _states.has(quest.id):
		return QuestData.Status.NOT_STARTED
	return _states[quest.id]["status"]


func get_stage_id(quest: QuestData) -> int:
	if quest == null or not _states.has(quest.id):
		return -1
	return _states[quest.id]["stage"]


func get_current_stage(quest: QuestData) -> QuestStage:
	return quest.get_stage(get_stage_id(quest))


func get_quests_with_status(status: QuestData.Status) -> Array[QuestData]:
	var result: Array[QuestData] = []
	for id in _states:
		if _states[id]["status"] == status:
			result.append(_states[id]["quest"])
	return result


# ---------- Save / Load ----------

func get_save_key() -> String:
	return "quests"


func save_data() -> Dictionary:
	var quests := {}
	for id in _states:
		var state: Dictionary = _states[id]
		quests[str(id)] = {
			# Enums are saved by NAME: reordering the enum later won't break old saves
			"status": QuestData.Status.keys()[state["status"]],
			"stage": state["stage"],
		}
	return {"quests": quests}


## Restore, don't replay: no signals, no on_enter_actions, no rewards.
## Those already happened before the save. Running them again would duplicate them.
func load_data(data: Dictionary) -> void:
	_states.clear()
	var quests: Dictionary = data.get("quests", {})
	for id in quests:
		var quest: QuestData = Database.get_quest(StringName(id))
		if quest == null:
			push_warning("QuestManager: save mentions unknown quest '%s', skipping" % id)
			continue
		var entry: Dictionary = quests[id]
		var status_name: String = entry.get("status", "")
		if not QuestData.Status.has(status_name):
			push_warning("QuestManager: quest '%s' has unknown status '%s', skipping" % [id, status_name])
			continue
		_states[quest.id] = {
			"quest": quest,
			"status": QuestData.Status[status_name],
			"stage": int(entry.get("stage", -1)),
		}


# ---------- Internals ----------

func _complete(quest: QuestData) -> void:
	_states[quest.id]["status"] = QuestData.Status.COMPLETED
	var player := _get_player()
	for reward in quest.rewards:
		if reward:
			reward.execute(player)
	quest_completed.emit(quest)


## Batches many changes in one frame into a single check, and avoids
## re-entrancy (an action changing a flag while we're mid-check).
func _queue_check() -> void:
	if _check_queued:
		return
	_check_queued = true
	_check_active_quests.call_deferred()


func _check_active_quests() -> void:
	_check_queued = false
	var player := _get_player()
	if player == null:
		return
	# Iterate over a COPY of the keys: an on_enter action might start a new quest.
	for id in _states.keys():
		var state: Dictionary = _states[id]
		if state["status"] != QuestData.Status.ACTIVE:
			continue
		var quest: QuestData = state["quest"]
		var stage := quest.get_stage(state["stage"])
		if stage == null or stage.conditions.is_empty():
			continue  # empty conditions = manual advance only
		if _all_met(stage.conditions, player):
			if stage.next_stage < 0:
				push_error("QuestManager: '%s' stage %d has conditions but no next_stage" % [id, stage.stage_id])
				continue
			set_stage(quest, stage.next_stage)


func _all_met(conditions: Array[GameCondition], player: Node) -> bool:
	for condition in conditions:
		if condition == null or not condition.is_met(player):
			return false
	return true


func _get_player() -> Node:
	return get_tree().get_first_node_in_group("player")
