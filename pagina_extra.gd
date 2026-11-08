extends Area3D

signal recogido(valor)

@export var valor = 1

func _ready():
	add_to_group("objetivos")
	body_entered.connect(_al_entrar)

func _al_entrar(cuerpo):
	if not cuerpo.is_in_group("jugador"):
		return
	# queue_free borra al final del cuadro: aquí todavía cuenta.
	var faltan = get_tree().get_nodes_in_group("objetivos").size() - 1
	print(name, " +", valor, " faltan ", faltan, " cuadro ", Engine.get_physics_frames())
	recogido.emit(valor)
	var partida = get_tree().get_first_node_in_group("partida")
	if partida != null:
		partida.avisar_meta()
	queue_free()
