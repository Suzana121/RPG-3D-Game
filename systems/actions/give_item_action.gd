class_name GiveItemAction
extends GameAction

@export var item: ItemData
@export var quantity: int = 1

func execute(player: Node) -> void:
	player.inventory.add_item(item, quantity)
