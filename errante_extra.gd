extends CharacterBody3D

enum Estado { PATRULLAR, ESPERAR, PERSEGUIR }

@export var rapidez = 1.5
@export var espera = 1.0
@export var rango_vision = 5.0
@export var ruta: Array[Vector3] = [Vector3.ZERO, Vector3(-8, 0, 0)]

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
	var d = distancia_a(jugador.global_position)
	var ve = lo_ve()
	var nuevo = decidir(d, ve)
	if nuevo != estado:
		estado = nuevo
		print(name, " -> ", Estado.keys()[estado], " cuadro ", Engine.get_physics_frames(), " a ", snappedf(d, 0.01), " m")
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
	var pecho = jugador.global_position + Vector3(0, 0.9, 0)
	vision.target_position = vision.to_local(pecho)
	vision.force_raycast_update()
	if vision.is_colliding():
		return vision.get_collider() == jugador
	return true

func patrullar():
	var destino = puntos[indice]
	if distancia_a(destino) < 0.1:
		indice = (indice + 1) % puntos.size()
		reloj = espera
		frenar()
		return
	ir_a(destino)

func ir_a(destino):
	var hacia = destino - global_position
	hacia.y = 0.0
	var dir = hacia.normalized()
	velocity.x = dir.x * rapidez
	velocity.z = dir.z * rapidez
	basis = Basis.looking_at(dir)
	anim.play("walk")

func frenar():
	velocity.x = 0.0
	velocity.z = 0.0
	anim.play("idle")

func distancia_a(p):
	var o = global_position
	return Vector2(p.x - o.x, p.z - o.z).length()
