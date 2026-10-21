extends Label

const FADE_TIME := 0.4
const SHOW_TIME := 2.5

var _queue: Array[String] = []
var _showing := false


func _ready() -> void:
	modulate.a = 0.0
	QuestManager.quest_started.connect(func(q): _push("Quest started: %s" % q.title))
	QuestManager.quest_stage_changed.connect(_on_stage_changed)
	QuestManager.quest_completed.connect(func(q): _push("Quest completed: %s" % q.title))
	SaveManager.game_saved.connect(func(_slot): _push("Game saved"))
	SaveManager.game_loaded.connect(func(_slot): _push("Game loaded"))


func _on_stage_changed(_quest: QuestData, stage: QuestStage) -> void:
	if stage.completes_quest:
		return  # "Quest completed" already covers the final stage
	_push(stage.objective_text)


func _push(message: String) -> void:
	_queue.append(message)
	if not _showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	text = _queue.pop_front()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	tween.tween_interval(SHOW_TIME)
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.finished.connect(_show_next)
