class_name ItemStack
extends RefCounted

var item: ItemData
var quantity: int

func _init(p_item: ItemData, p_quantity: int = 1) -> void:
	item = p_item
	quantity = p_quantity
