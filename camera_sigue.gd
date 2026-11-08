extends Camera3D

@export var objetivo: Node3D
@export var distancia := Vector3(0.0, 12.0, 7.0)   # desde el personaje: arriba y atrás
@export var suavizado := 6.0
@export var limite_min := Vector2(-3.0, 6.0)       # x, z del centro de la cámara
@export var limite_max := Vector2(3.0, 44.0)

func _ready() -> void:
	top_level = true                                # ignora la rotación y movimiento del padre
	var h := Vector2(distancia.x, distancia.z).length()
	rotation = Vector3(-atan2(distancia.y, h), atan2(distancia.x, distancia.z), 0.0)
	if objetivo != null:
		global_position = _destino()

func _destino() -> Vector3:
	var d := objetivo.global_position + distancia
	d.x = clampf(d.x, limite_min.x, limite_max.x)
	d.z = clampf(d.z, limite_min.y, limite_max.y)
	return d

func _process(delta: float) -> void:
	if objetivo == null:
		return
	global_position = global_position.lerp(_destino(), 1.0 - exp(-suavizado * delta))
