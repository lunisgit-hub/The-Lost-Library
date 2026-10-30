extends Node

@export var tecla = "interactuar"
@export var alcance = 1.5
@onready var pj = get_parent()

func _physics_process(delta):
	if Input.is_action_just_pressed(tecla):
		var obj = mas_cercano()
		if obj == null:
			print("nada a menos de ", alcance, " m")
		else:
			var d = snappedf(distancia_a(obj), 0.01)
			print("interactúa con ", obj.name, " a ", d, " m")

func mas_cercano():
	var mejor = null
	for obj in get_tree().get_nodes_in_group("interactivos"):
		var d = distancia_a(obj)
		if d <= alcance and (mejor == null or d < distancia_a(mejor)):
			mejor = obj
	return mejor

func distancia_a(obj):
	var a = Vector2(pj.global_position.x, pj.global_position.z)
	var b = Vector2(obj.global_position.x, obj.global_position.z)
	return a.distance_to(b)
