class_name DialogueChoice
extends Resource

## What the player says, e.g. "Any work for me?"
@export var text: String = ""
## The id of the node this choice leads to. Empty = end the conversation.
@export var next_id: StringName = &""
## All must be met for the choice to be shown.
@export var conditions: Array[GameCondition] = []
## Executed, in order, when the player picks this choice.
@export var actions: Array[GameAction] = []


func ends_dialogue() -> bool:
	return next_id == &""
