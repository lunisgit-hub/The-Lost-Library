extends Node

signal cambio(vida)
signal sin_vida

@export var vida = 3
@export var invulnerable = 1.0
@export var reapariciones = 1
@export var espera_reaparecer = 2.0
var reloj = 0.0
var vida_inicial = 0
var punto = Vector3.ZERO
@onready var pj = get_parent()


func _ready():
	sin_vida.connect(_al_quedar_sin_vida)
	vida_inicial = vida
	punto = pj.global_position


func _physics_process(delta):
	reloj = maxf(reloj - delta, 0.0)


# sin_invulnerable = true: lo usa el combate por turnos, donde cada golpe de
# un combo tiene que contar aunque lleguen seguidos.
func recibir_golpe(danio, sin_invulnerable = false):
	if vida == 0 or (reloj > 0.001 and not sin_invulnerable):
		return
	vida = maxi(vida - danio, 0)
	reloj = invulnerable
	cambio.emit(vida)
	if vida == 0:
		sin_vida.emit()


func _al_quedar_sin_vida():
	# Primero la animación de muerte del personaje (personaje.gd → morir())
	if pj.has_method("morir"):
		await pj.morir()
	if reapariciones > 0:
		reapariciones -= 1
		vida = vida_inicial
		pj.global_position = punto
		reloj = espera_reaparecer
		cambio.emit(vida)
		if pj.has_method("revivir"):
			pj.revivir()
		print("reaparece cuadro ", Engine.get_physics_frames())
		return
	var partida = get_tree().get_first_node_in_group("partida")
	if partida != null:
		partida.perder("sin vida")
	else:
		# Escena sin Partida (p. ej. zona_b): volver a empezar la escena.
		get_tree().paused = false
		get_tree().reload_current_scene()
