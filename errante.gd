extends CharacterBody3D

enum Estado { PATRULLAR, PERSEGUIR, ATACAR, HUIR }

@export var velocidad: float = 3.0
@export var aceleracion: float = 10.0
@export var rango_vision: float = 8.0
@export var rango_ataque: float = 1.5
@export var vida: float = 100.0
@export var vida_huida: float = 30.0
@export var altura_ojos: float = 0.9

# NUEVO: Rango de audición para el sistema de ruido y alerta
@export var rango_audicion: float = 5.0

# Cada enemigo patrulla su propia zona.
@export var ruta: Array[Vector3] = [
	Vector3(0, 0, 0),
	Vector3(8, 0, 0)
]

var estado_actual: Estado = Estado.PATRULLAR
var indice_punto: int = 0
var jugador: Node3D = null
var puntos: Array[Vector3] = []

@onready var vision: RayCast3D = $Vision


func _ready() -> void:
	jugador = get_tree().get_first_node_in_group("jugador")

	for desplazamiento in ruta:
		puntos.append(global_position + desplazamiento)


func _decidir_estado(distancia: float, lo_veo: bool, hay_ruido: bool) -> Estado:
	if vida <= vida_huida and distancia <= rango_vision:
		return Estado.HUIR

	if distancia <= rango_ataque and lo_veo:
		return Estado.ATACAR

	# NUEVO: Pasa a PERSEGUIR si lo ve O si escucha un ruido cercano
	if (distancia <= rango_vision and lo_veo) or (distancia <= rango_audicion and hay_ruido):
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


# NUEVO: Detectar si el jugador está haciendo ruido (ej. corriendo o emitiendo sonido)
func _escuchar_ruido() -> bool:
	if jugador == null:
		return false
	# Puedes comprobar si el jugador tiene un método o variable de movimiento ruidoso
	# Por ejemplo, si el jugador se mueve rápido:
	if jugador.has_method("esta_corriendo") and jugador.esta_corriendo():
		return true
	# O simplemente por proximidad auditiva si está en movimiento:
	if "velocity" in jugador and (jugador.velocity as Vector3).length() > 1.0:
		return true
	return false


func _physics_process(delta: float) -> void:
	velocity += get_gravity() * delta

	var distancia: float = INF
	if jugador != null:
		distancia = _distancia_plana(global_position, jugador.global_position)

	var lo_veo: bool = _tiene_linea_vision()
	var hay_ruido: bool = _escuchar_ruido()
	var nuevo: Estado = _decidir_estado(distancia, lo_veo, hay_ruido)

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

	# NUEVO: Verificar colisión física con el CharacterBody3D del jugador para activar combate
	_verificar_colision_combate()


# NUEVO: Activación de Combate por Colisión Directa
func _verificar_colision_combate() -> void:
	for i in range(get_slide_collision_count()):
		var colision = get_slide_collision(i)
		var collider = colision.get_collider()
		if collider and collider == jugador:
			print("¡Colisión con el jugador detectada! Iniciando combate por turnos...")
			# AQUÍ LLAMAS A TU SEÑAL O GESTOR DE ESCENA DE COMBATE:
			# Ej: Events.emit_signal("iniciar_combate")
			break


func _distancia_plana(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _patrullar(delta: float) -> void:
	if puntos.is_empty():
		_frenar(delta)
		return

	var destino: Vector3 = puntos[indice_punto]
	_moverse_hacia(destino, 1.0, delta)

	# OPTIMIZACIÓN: Umbral ajustado para fluidez en las esquinas de las estanterías
	if _distancia_plana(global_position, destino) < 0.4:
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
		basis = basis.slerp(
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
