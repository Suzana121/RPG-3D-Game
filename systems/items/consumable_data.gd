class_name ConsumableData
extends ItemData

@export var heal_amount: int = 25


func use(user: Node) -> bool:
	var health := user.get_node_or_null("Health") as Health
	if health == null or health.is_full():
		return false
	health.heal(heal_amount)
	return true
