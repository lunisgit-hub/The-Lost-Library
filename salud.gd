extends Node

@export var vida = 3
@export var invulnerable = 1.0
var reloj = 0.0


func _physics_process(delta):
	reloj = maxf(reloj - delta, 0.0)


func recibir_golpe(danio):
	if reloj > 0.001:
		print("invulnerable: no cuenta")
		return
	vida = maxi(vida - danio, 0)
	reloj = invulnerable
	print("vida del jugador: ", vida)
	if vida == 0:
		print("el jugador perdió")
