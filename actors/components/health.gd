class_name Health
extends Node

signal changed(current: int, maximum: int)
signal died

@export var max_health: int = 100
var current: int


func _ready() -> void:
	current = max_health


func heal(amount: int) -> void:
	current = mini(current + amount, max_health)
	changed.emit(current, max_health)


func take_damage(amount: int) -> void:
	if current <= 0:
		return
	current = maxi(current - amount, 0)
	changed.emit(current, max_health)
	if current == 0:
		died.emit()


func is_full() -> bool:
	return current >= max_health
