class_name QuestData
extends Resource

enum Status { NOT_STARTED, ACTIVE, COMPLETED, FAILED }
enum QuestType { MAIN, SIDE, MISC }

## Must be unique across all quests: it's the key for runtime state and saves.
@export var id: StringName
@export var title: String = ""
@export_multiline var description: String = ""
@export var quest_type: QuestType = QuestType.SIDE
@export var stages: Array[QuestStage] = []
## Executed once when the quest completes.
@export var rewards: Array[GameAction] = []


func get_stage(stage_id: int) -> QuestStage:
	for stage in stages:
		if stage.stage_id == stage_id:
			return stage
	return null


func get_first_stage() -> QuestStage:
	var first: QuestStage = null
	for stage in stages:
		if first == null or stage.stage_id < first.stage_id:
			first = stage
	return first
