class_name FlagCondition
extends GameCondition

@export var flag: StringName
@export var expected: bool = true


func is_met(_player: Player) -> bool:
	return GameState.get_flag(flag) == expected
