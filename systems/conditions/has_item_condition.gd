class_name HasItemCondition
extends GameCondition

@export var item: ItemData
@export var amount: int = 1


func is_met(player: Player) -> bool:
	return item != null and player.inventory.count_of(item.id) >= amount
