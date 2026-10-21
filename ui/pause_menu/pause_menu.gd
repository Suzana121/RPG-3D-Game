extends CanvasLayer
## The Esc menu: Resume / Save / Load / Quit. Pauses the game through InputMode.

enum Mode { MAIN, SAVE, LOAD }

@onready var title_label: Label = %TitleLabel
@onready var main_buttons: VBoxContainer = %MainButtons
@onready var resume_button: Button = %ResumeButton
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var quit_button: Button = %QuitButton
@onready var slot_panel: VBoxContainer = %SlotPanel
@onready var slot_list: ItemList = %SlotList
@onready var confirm_button: Button = %ConfirmButton
@onready var delete_button: Button = %DeleteButton
@onready var back_button: Button = %BackButton
@onready var confirm_dialog: ConfirmationDialog = %ConfirmDialog

var _player: Player
var _mode := Mode.MAIN
## What each row of slot_list means. {} = the "New Save" row.
var _rows: Array[Dictionary] = []
## What to do if the player clicks OK in the confirm dialog.
var _on_confirmed := Callable()


func _ready() -> void:
	visible = false
	_player = get_tree().get_first_node_in_group("player") as Player

	resume_button.pressed.connect(close)
	save_button.pressed.connect(_show_slots.bind(Mode.SAVE))
	load_button.pressed.connect(_show_slots.bind(Mode.LOAD))
	quit_button.pressed.connect(func(): get_tree().quit())
	back_button.pressed.connect(_show_main)
	confirm_button.pressed.connect(_on_confirm_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	slot_list.item_selected.connect(_update_buttons.unbind(1))
	slot_list.item_activated.connect(_on_confirm_pressed.unbind(1))  # double-click / Enter
	confirm_dialog.confirmed.connect(func(): _on_confirmed.call())


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if not visible:
		if _player and _player.can_open_menus():
			open()
			get_viewport().set_input_as_handled()
		# Otherwise don't touch the event: the inventory or journal uses this Esc to close.
		return
	if _mode == Mode.MAIN:
		close()
	else:
		_show_main()  # Esc in a sub-screen goes back one level, like Skyrim
	get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	InputMode.request(self, true, true)
	_show_main()


func close() -> void:
	visible = false
	InputMode.release(self)


# ---------- Screens ----------

func _show_main() -> void:
	_mode = Mode.MAIN
	title_label.text = "Paused"
	main_buttons.show()
	slot_panel.hide()
	load_button.disabled = SaveManager.list_saves().is_empty()
	resume_button.grab_focus()


func _show_slots(mode: Mode) -> void:
	_mode = mode
	title_label.text = "Save Game" if mode == Mode.SAVE else "Load Game"
	confirm_button.text = "Save" if mode == Mode.SAVE else "Load"
	main_buttons.hide()
	slot_panel.show()
	_refresh_slots()
	slot_list.grab_focus()


func _refresh_slots() -> void:
	_rows.clear()
	if _mode == Mode.SAVE:
		_rows.append({})  # "New Save" always on top
	for entry in SaveManager.list_saves():
		# You can overwrite only your own saves; autosave/quicksave belong to the game.
		if _mode == Mode.LOAD or entry["is_manual"]:
			_rows.append(entry)

	slot_list.clear()
	for row in _rows:
		slot_list.add_item(_row_text(row))
	if not _rows.is_empty():
		slot_list.select(0)
	_update_buttons()


func _row_text(row: Dictionary) -> String:
	if row.is_empty():
		return "+  New Save"
	return "%s      %s      %s" % [row["title"], row["location"], row["saved_at"]]


func _update_buttons() -> void:
	var row = _selected_row()
	confirm_button.disabled = row == null
	delete_button.disabled = row == null or row.is_empty()


## The selected row's Dictionary, or null if nothing is selected.
func _selected_row() -> Variant:
	var selected := slot_list.get_selected_items()
	if selected.is_empty():
		return null
	return _rows[selected[0]]


# ---------- Actions ----------

func _on_confirm_pressed() -> void:
	var row = _selected_row()
	if row == null:
		return
	if _mode == Mode.SAVE:
		if row.is_empty():
			_save(SaveManager.next_manual_slot())
		else:
			_ask("Overwrite %s?" % row["title"], _save.bind(row["slot"]))
	else:
		_ask("Load %s?\nAny progress since your last save will be lost." % row["title"],
			_load.bind(row["slot"]))


func _on_delete_pressed() -> void:
	var row = _selected_row()
	if row == null or row.is_empty():
		return
	_ask("Delete %s? This can't be undone." % row["title"], func():
		SaveManager.delete_save(row["slot"])
		_refresh_slots())


func _save(slot: String) -> void:
	if SaveManager.save_game(slot):
		close()  # back to the game; the HUD shows "Game saved"


func _load(slot: String) -> void:
	# Don't do anything after this line: loading frees the current scene, including this menu.
	# InputMode notices (tree_exiting) and releases our pause request by itself.
	SaveManager.load_game(slot)


func _ask(question: String, on_yes: Callable) -> void:
	_on_confirmed = on_yes
	confirm_dialog.dialog_text = question
	confirm_dialog.popup_centered()
