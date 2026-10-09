class_name ItemData
extends Resource

enum Category { MISC, WEAPON, ARMOR, CONSUMABLE, INGREDIENT }

## Stable unique ID, used by save files. Never change it after release.
@export var id: StringName
@export var display_name: String = "Unnamed Item"
@export_multiline var description: String = ""
@export var category: Category = Category.MISC
@export var icon: Texture2D
## Optional 3D model shown when the item lies in the world.
@export var world_model: PackedScene

@export_group("Economy")
@export_range(0.0, 100.0, 0.1) var weight: float = 0.0
@export_range(0, 100000) var value: int = 0
@export_range(1, 999) var max_stack: int = 1
