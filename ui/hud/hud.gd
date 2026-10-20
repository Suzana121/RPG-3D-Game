extends CanvasLayer

@onready var prompt: Label = $Prompt

func _ready() -> void:
	prompt.hide()
	EventBus.interaction_target_changed.connect(_on_target_changed)

func _on_target_changed(target: Interactable) -> void:
	if target:
		prompt.text = "E  " + target.prompt_text
		prompt.show()
	else:
		prompt.hide()
