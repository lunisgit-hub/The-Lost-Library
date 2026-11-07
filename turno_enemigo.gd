extends Node

enum Accion { ATACAR, CARGAR, DEFENDER }

@export var ritmo = 1.0
@export var danio = 10
@export var cuantos_turnos = 8
# El patrón: se recorre con un índice, como la patrulla.
@export var patron: Array[int] = [0, 1, 0, 2]

var indice = 0
var turno_numero = 0
var reloj = 0.0

func _ready():
	reloj = ritmo

func _physics_process(delta):
	if turno_numero >= cuantos_turnos:
		return
	reloj -= delta
	if reloj <= 0.001:
		reloj = ritmo
		jugar_turno()

func jugar_turno():
	turno_numero += 1
	var accion = patron[indice]
	indice = (indice + 1) % patron.size()
	print("turno ", turno_numero, ": ", Accion.keys()[accion])
	match accion:
		Accion.ATACAR:
			print(" ataca: ", danio, " de daño")
		Accion.CARGAR:
			print(" carga fuerzas")
		Accion.DEFENDER:
			print(" se defiende")
