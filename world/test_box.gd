extends StaticBody3D

func _ready() -> void:
	$Interactable.interacted.connect(_on_interacted)

func _on_interacted(interactor: Node) -> void:
	print("Hello from the box! Touched by: ", interactor.name)
