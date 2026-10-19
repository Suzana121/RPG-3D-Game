class_name GameCondition
extends Resource

## Override in subclasses. Return true if the condition is satisfied.
func is_met(_player: Player) -> bool:
	return true
