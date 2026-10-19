extends CanvasLayer

@onready var _panel: Control = $Panel
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _text_label: Label = %TextLabel
@onready var _choices: VBoxContainer = %Choices


func _ready() -> void:
	_panel.hide()
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.node_shown.connect(_on_node_shown)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


func _on_dialogue_started(_npc: NPC) -> void:
	_panel.show()


func _on_node_shown(speaker: String, text: String, choices: Array[DialogueChoice]) -> void:
	_speaker_label.text = speaker
	_text_label.text = text
	_clear_choices()

	for i in choices.size():
		var button := Button.new()
		button.text = choices[i].text
		button.pressed.connect(DialogueManager.choose.bind(i))
		_choices.add_child(button)

	if _choices.get_child_count() > 0:
		_choices.get_child(0).grab_focus()


func _on_dialogue_ended() -> void:
	_clear_choices()
	_panel.hide()


func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
