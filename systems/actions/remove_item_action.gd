class_name RemoveItemAction
extends GameAction

@export var item: ItemData
@export var quantity: int = 1

func execute(player: Node) -> void:
	player.inventory.remove_item(item.id, quantity)
