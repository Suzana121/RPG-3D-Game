class_name QuestCondition
extends GameCondition

@export var quest: QuestData
@export var required_status: QuestData.Status = QuestData.Status.ACTIVE
## Stage limits, only checked when required_status is ACTIVE. -1 = no limit.
@export var min_stage: int = -1
@export var max_stage: int = -1

func is_met(_player: Node) -> bool:
	if quest == null:
		return false
	if QuestManager.get_status(quest) != required_status:
		return false
	if required_status != QuestData.Status.ACTIVE:
		return true
	var stage := QuestManager.get_stage_id(quest)
	if min_stage >= 0 and stage < min_stage:
		return false
	if max_stage >= 0 and stage > max_stage:
		return false
	return true
