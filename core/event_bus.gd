extends Node

signal interaction_target_changed(target: Interactable)
signal item_picked_up(item: ItemData, quantity: int)
signal inventory_changed(inventory: Node)
