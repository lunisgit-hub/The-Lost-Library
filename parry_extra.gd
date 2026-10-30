extends Node

enum Estado { LISTA, ACTIVA, RECARGA }

@export var tecla = "correr" # O "parry" con Espacio
@export var duracion = 0.5
@export var recarga = 1.0
@onready var pj = get_parent()

var estado = Estado.LISTA
var tiempo = 0.0

func _physics_process(delta):
	tiempo -= delta
	match estado:
		Estado.LISTA:
			if Input.is_action_just_pressed(tecla):
				empezar()
		Estado.ACTIVA:
			if tiempo <= 0.001:
				terminar()
		Estado.RECARGA:
			if tiempo <= 0.001:
				estado = Estado.LISTA

func empezar():
	estado = Estado.ACTIVA
	tiempo = duracion
	print("empieza: ", tecla)

func terminar():
	estado = Estado.RECARGA
	tiempo = recarga
	print("termina: ", tecla)
