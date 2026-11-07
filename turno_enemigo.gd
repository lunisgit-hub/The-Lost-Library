extends Node

enum Accion { ATACAR, CARGAR, DEFENDER, GOLPE_FUERTE, CURARSE }

@export var ritmo = 1.0
@export var danio = 10
@export var cuantos_turnos = 8
@export var patron: Array[int] = [0, 1, 0, 2]
@export var vida = 60
@export var vida_baja = 15
@export var curas = 1
@export var cura = 10

var indice = 0
var turno_numero = 0
var reloj = 0.0
var cargado = false

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
	var accion = decidir()
	print("turno ", turno_numero, ": ", Accion.keys()[accion], " (vida ", vida, ")")
	match accion:
		Accion.ATACAR:
			print(" ataca: ", danio, " de daño")
		Accion.CARGAR:
			cargado = true
			print(" carga fuerzas")
		Accion.DEFENDER:
			print(" se defiende")
		Accion.GOLPE_FUERTE:
			cargado = false
			print(" golpe fuerte: ", danio * 2, " de daño")
		Accion.CURARSE:
			curas -= 1
			vida += cura
			print(" se cura: vida ", vida)

# El orden es la personalidad: la primera regla que se cumple gana.
func decidir():
	if cargado:
		return Accion.GOLPE_FUERTE
	if vida <= vida_baja and curas > 0:
		return Accion.CURARSE
	var a = patron[indice]
	indice = (indice + 1) % patron.size()
	return a

# La llama el jugador cuando le acierta.
func recibir_golpe(cuanto):
	vida -= cuanto
	print(" el enemigo recibe ", cuanto, ": vida ", vida)
