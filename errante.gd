extends CharacterBody3D

enum Estado { PATRULLAR, PERSEGUIR, ATACAR, HUIR }

@export var velocidad: float = 3.0
@export var aceleracion: float = 10.0
@export var rango_vision: float = 8.0
@export var rango_ataque: float = 1.5
@export var vida: float = 100.0
@export var vida_huida: float = 30.0
@export var altura_ojos: float = 0.9

@export var ruta: Array[Vector3] = [
	Vector3(0, 0, 0),
	Vector3(8, 0, 0)
]

var estado_actual: Estado = Estado.PATRULLAR
var indice_punto: int = 0
var jugador: Node3D = null
var puntos: Array[Vector3] = []
var anim: AnimationPlayer = null

@onready var vision: RayCast3D = $Vision


func _ready() -> void:
	jugador = get_tree().get_first_node_in_group("jugador")
	anim = _buscar_anim_caballero()
	if anim != null:
		anim.play("Walking")

	for desplazamiento in ruta:
		puntos.append(global_position + desplazamiento)


func _buscar_anim_caballero() -> AnimationPlayer:
	for nodo in find_children("*", "AnimationPlayer", true, false):
		var ap := nodo as AnimationPlayer
		if ap != null and ap.has_animation("Walking"):
			return ap
	return null


func _decidir_estado(distancia: float, lo_veo: bool) -> Estado:
	if vida <= vida_huida and distancia <= rango_vision:
		return Estado.HUIR

	if distancia <= rango_ataque and lo_veo:
		return Estado.ATACAR

	if distancia <= rango_vision and lo_veo:
		return Estado.PERSEGUIR

	return Estado.PATRULLAR


func _tiene_linea_vision() -> bool:
	if jugador == null:
		return false

	var objetivo: Vector3 = jugador.global_position + Vector3(0, altura_ojos, 0)
	vision.target_position = vision.to_local(objetivo)
	vision.force_raycast_update()

	if vision.is_colliding():
		return vision.get_collider() == jugador

	return true


func _physics_process(delta: float) -> void:
	if anim == null:
		anim = _buscar_anim_caballero()

	if anim != null and anim.has_animation("Walking"):
		# Si está lanzando el espadazo, no interrumpirlo con Walking
		if anim.current_animation == "Charged_Slash" and anim.is_playing():
			pass
		elif Vector2(velocity.x, velocity.z).length() > 0.1:
			var anim_usar := "Running" if (estado_actual in [Estado.PERSEGUIR, Estado.HUIR] and anim.has_animation("Running")) else "Walking"
			if anim.current_animation != anim_usar:
				anim.play(anim_usar)
		elif anim.current_animation in ["Walking", "Running"]:
			anim.play("Walking", -1, 0.0)

	velocity += get_gravity() * delta

	var distancia: float = INF

	if jugador != null:
		distancia = _distancia_plana(global_position, jugador.global_position)

	var lo_veo: bool = _tiene_linea_vision()
	var nuevo: Estado = _decidir_estado(distancia, lo_veo)

	if nuevo != estado_actual:
		estado_actual = nuevo
		print("Enemigo -> ", Estado.keys()[estado_actual])

	match estado_actual:
		Estado.PATRULLAR:
			_patrullar(delta)

		Estado.PERSEGUIR:
			if jugador != null:
				_moverse_hacia(jugador.global_position, 1.0, delta)

		Estado.ATACAR:
			_frenar(delta)

		Estado.HUIR:
			if jugador != null:
				_moverse_lejos_de(jugador.global_position, delta)

	move_and_slide()


func _distancia_plana(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _patrullar(delta: float) -> void:
	if puntos.is_empty():
		_frenar(delta)
		return

	var destino: Vector3 = puntos[indice_punto]
	_moverse_hacia(destino, 1.0, delta)

	if _distancia_plana(global_position, destino) < 0.5:
		indice_punto = (indice_punto + 1) % puntos.size()


func _moverse_hacia(destino: Vector3, factor: float, delta: float) -> void:
	var direccion: Vector3 = destino - global_position
	direccion.y = 0.0

	var objetivo: Vector3 = Vector3.ZERO

	if direccion.length() > 0.05:
		objetivo = direccion.normalized() * velocidad * factor

	velocity.x = move_toward(velocity.x, objetivo.x, aceleracion * delta)
	velocity.z = move_toward(velocity.z, objetivo.z, aceleracion * delta)

	if objetivo.length() > 0.1:
		basis = basis.orthonormalized().slerp(
			Basis.looking_at(objetivo),
			delta * 8.0
		).orthonormalized()


func _moverse_lejos_de(amenaza: Vector3, delta: float) -> void:
	var direccion: Vector3 = global_position - amenaza
	direccion.y = 0.0
	_moverse_hacia(global_position + direccion, 1.3, delta)


func _frenar(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, aceleracion * delta)
	velocity.z = move_toward(velocity.z, 0.0, aceleracion * delta)
