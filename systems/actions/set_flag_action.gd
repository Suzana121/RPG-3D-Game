class_name SetFlagAction
extends GameAction

@export var flag: StringName
@export var value: bool = true


func execute(_player: Player) -> void:
	GameState.set_flag(flag, value)
