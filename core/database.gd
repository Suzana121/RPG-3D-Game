extends Node
## Looks up data definitions (.tres) by their stable id.
## Save files store ids, never resources. This turns ids back into resources.

const ITEMS_DIR := "res://data/items"
const QUESTS_DIR := "res://data/quests"

var _items: Dictionary = {}   # StringName → ItemData
var _quests: Dictionary = {}  # StringName → QuestData


func _ready() -> void:
	_scan(ITEMS_DIR, _items)
	_scan(QUESTS_DIR, _quests)
	print("Database: %d items, %d quests" % [_items.size(), _quests.size()])


func get_item(id: StringName) -> ItemData:
	return _items.get(id)


func get_quest(id: StringName) -> QuestData:
	return _quests.get(id)


## Loads every resource in a folder (and its subfolders) and indexes it by id.
func _scan(dir_path: String, into: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("Database: can't open %s" % dir_path)
		return
	for file in dir.get_files():
		# In an exported game, "x.tres" is listed as "x.tres.remap"
		file = file.trim_suffix(".remap")
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var res := load(dir_path.path_join(file))
		if res == null or not "id" in res:
			continue
		var id: StringName = res.id
		if id == &"":
			push_error("Database: %s has an empty id" % file)
		elif into.has(id):
			push_error("Database: duplicate id '%s' (%s)" % [id, file])
		else:
			into[id] = res
	for sub in dir.get_directories():
		_scan(dir_path.path_join(sub), into)
