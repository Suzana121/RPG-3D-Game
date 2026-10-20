class_name SetQuestStageAction
extends GameAction

@export var quest: QuestData
@export var stage: int = 10

func execute(_player: Node) -> void:
	QuestManager.set_stage(quest, stage)
