class_name StartQuestAction
extends GameAction

@export var quest: QuestData

func execute(_player: Node) -> void:
	QuestManager.start_quest(quest)
