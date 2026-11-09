extends Node

signal cambio(vida)
signal sin_vida

@export var vida = 3
@export var invulnerable = 1.0
var reloj = 0.0


func _physics_process(delta):
	reloj = maxf(reloj - delta, 0.0)


func recibir_golpe(danio):
	if reloj > 0.001 or vida == 0:
		return
	vida = maxi(vida - danio, 0)
	reloj = invulnerable
	cambio.emit(vida)
	if vida == 0:
		sin_vida.emit()
