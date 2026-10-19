class_name DialogueData
extends Resource

@export var start_id: StringName = &""
@export var nodes: Array[DialogueNode] = []


func get_start_node() -> DialogueNode:
	return get_node_by_id(start_id)


func get_node_by_id(id: StringName) -> DialogueNode:
	for node in nodes:
		if node.id == id:
			return node
	push_warning("Dialogue '%s' has no node with id '%s'" % [resource_path, id])
	return null
	
