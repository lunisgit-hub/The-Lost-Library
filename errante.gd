extends CharacterBody3D

enum Estado { PATRULLAR, ESPERAR, PERSEGUIR }

@export var rapidez = 2.0
@export var espera = 1.0
@export var rango_vision = 7.0
@export var ruta: Array[Vector3] = [Vector3.ZERO, Vector3(0, 0, -6)]

var estado = Estado.PATRULLAR
var puntos: Array[Vector3] = []
var indice = 0
var reloj = 0.0
var jugador = null

@onready var anim = $Modelo/AnimationPlayer
@onready var vision = $Vision

func _ready():
	jugador = get_tree().get_first_node_in_group("jugador")
	for d in ruta:
		puntos.append(global_position + d)

func _physics_process(delta):
	velocity += get_gravity() * delta
	reloj = maxf(reloj - delta, 0.0)
	
	# 1. MEDIR
	var d = distancia_a(jugador.global_position)
	var ve = lo_ve()
	
	# 2. DECIDIR
	var nuevo = decidir(d, ve)
	if nuevo != estado:
		estado = nuevo
		print(name, " -> ", Estado.keys()[estado], " cuadro ", Engine.get_physics_frames(), " a ", snappedf(d, 0.01), " m")
		
	# 3. ACTUAR
	match estado:
		Estado.PATRULLAR:
			patrullar()
		Estado.ESPERAR:
			frenar()
		Estado.PERSEGUIR:
			ir_a(jugador.global_position)
			
	move_and_slide()

func decidir(d, ve):
	if d <= rango_vision and ve:
		return Estado.PERSEGUIR
	if reloj > 0.001:
		return Estado.ESPERAR
	return Estado.PATRULLAR

func lo_ve():
	# Se apunta al pecho: el origen del jugador está en los pies.
	var pecho = jugador.global_position + Vector3(0, 0.9, 0)
	vision.target_position = vision.to_local(pecho)
	vision.force_raycast_update()
	if vision.is_colliding():
		# ¿Lo primero que tocó fue el jugador, o una pared?
		return vision.get_collider() == jugador
	return true

# (Conserva aquí abajo las funciones patrullar(), ir_a(), frenar() y distancia_a() del nivel anterior)
