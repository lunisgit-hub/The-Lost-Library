extends Node3D

@export var distancia_min := 12.0

func _ready() -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		mi.visibility_range_begin = distancia_min
