extends CanvasLayer

const TAB_STATUSES := [QuestData.Status.ACTIVE, QuestData.Status.COMPLETED]

@onready var tabs: TabBar = %Tabs
@onready var quest_list: ItemList = %QuestList
@onready var title_label: Label = %TitleLabel
@onready var details_label: Label = %DetailsLabel

var _player: Player
var _shown: Array[QuestData] = []


func _ready() -> void:
	visible = false
	_player = get_tree().get_first_node_in_group("player") as Player

	tabs.add_tab("Active")
	tabs.add_tab("Completed")
	tabs.tab_changed.connect(func(_i): _refresh())
	quest_list.item_selected.connect(_show_details)

	# Model–View: redraw when the quest model changes.
	QuestManager.quest_started.connect(_on_quests_changed.unbind(1))
	QuestManager.quest_stage_changed.connect(_on_quests_changed.unbind(2))
	QuestManager.quest_completed.connect(_on_quests_changed.unbind(1))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		if visible:
			close()
		elif _player and _player.can_open_menus():
			open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	InputMode.request(self, true, true)
	_refresh()
	quest_list.grab_focus()


func close() -> void:
	visible = false
	InputMode.release(self)


func _on_quests_changed() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	var status: QuestData.Status = TAB_STATUSES[tabs.current_tab]
	_shown = QuestManager.get_quests_with_status(status)
	_shown.sort_custom(func(a, b): return a.quest_type < b.quest_type)  # MAIN first

	quest_list.clear()
	for quest in _shown:
		var prefix := "★ " if quest.quest_type == QuestData.QuestType.MAIN else ""
		quest_list.add_item(prefix + quest.title)

	if _shown.is_empty():
		title_label.text = "No quests"
		details_label.text = ""
	else:
		quest_list.select(0)  # select() doesn't emit item_selected,
		_show_details(0)      # so we show the details ourselves


func _show_details(index: int) -> void:
	var quest := _shown[index]
	title_label.text = quest.title
	var text := quest.description
	match QuestManager.get_status(quest):
		QuestData.Status.ACTIVE:
			var stage := QuestManager.get_current_stage(quest)
			if stage:
				text += "\n\nObjective: " + stage.objective_text
		QuestData.Status.COMPLETED:
			text += "\n\nCompleted."
	details_label.text = text	
