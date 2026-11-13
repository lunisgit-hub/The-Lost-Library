extends CharacterBody3D

enum Estado { PATRULLAR, PERSEGUIR, ATACAR, HUIR }

@export var velocidad: float = 3.0
@export var aceleracion: float = 10.0
@export var rango_vision: float = 5.0
@export var rango_perder: float = 8.0
@export var rango_ataque: float = 1.5
@export var vida: float = 3.0
@export var vida_huida: float = 1.0
@export var sonido_ataque: AudioStream = preload("res://sonidos/ataque.mp3")
var reproductor_audio: AudioStreamPlayer3D = null
var tiempo_entre_ataques: float = 1.0
var temporizador_ataque: float = 0.0

# Puntos de patrulla relativos o fijos
@export var ruta: Array[Vector3] = [
	Vector3(-6, 0, 1),
	Vector3(6, 0, 1)
]

var estado_actual: Estado = Estado.PATRULLAR
var indice_punto: int = 0
var jugador: Node3D = null
var puntos_absolutos: Array[Vector3] = []

@onready var anim = $Modelo/AnimationPlayer

func _ready() -> void:
	# Busca automáticamente al jugador por grupo para evitar que sea null
	jugador = get_tree().get_first_node_in_group("jugador")
	
	# Convierte la ruta en posiciones absolutas basadas en dónde se coloca el enemigo
	for desplazamiento in ruta:
		puntos_absolutos.append(global_position + desplazamiento)
		
	

func _physics_process(delta: float) -> void:
	velocity += get_gravity() * delta

	var distancia: float = INF
	if jugador != null:
		distancia = global_position.distance_to(jugador.global_position)

	# Máquina de estados robusta similar al código anterior
	match estado_actual:
		Estado.PATRULLAR:
			if jugador != null and distancia < rango_vision:
				estado_actual = Estado.PERSEGUIR
				print("¡Lo vio a ", snappedf(distancia, 0.01), " m!")
			_patrullar(delta)

		Estado.PERSEGUIR:
			if jugador != null:
				if distancia > rango_perder:
					estado_actual = Estado.PATRULLAR
					print("Lo perdió a ", snappedf(distancia, 0.01), " m")
				elif distancia <= rango_ataque:
					estado_actual = Estado.ATACAR
				else:
					_moverse_hacia(jugador.global_position, 1.0, delta)
			else:
				estado_actual = Estado.PATRULLAR

		Estado.ATACAR:
			_frenar(delta)
			
			# Verificamos si el jugador ya murió usando su variable o grupo
			if jugador != null and jugador.has_method("has_method") and not jugador.get("ya_murio"):
				temporizador_ataque += delta
				if temporizador_ataque >= tiempo_entre_ataques:
					temporizador_ataque = 0.0
					print("¡El enemigo ataca al jugador!")
					
					if audio_ataque and not audio_ataque.playing:
						audio_ataque.play()
						
					if jugador.has_method("recibir_danio"):
						jugador.recibir_danio(10.0)
				
				if distancia > rango_ataque:
					estado_actual = Estado.PERSEGUIR
			else:
				# Si el jugador ya murió o es nulo, el enemigo se detiene / patina a patrullar
				estado_actual = Estado.PATRULLAR

		Estado.HUIR:
			if jugador != null:
				_moverse_lejos_de(jugador.global_position, delta)

	move_and_slide()
	
	# Verificar colisión física para combate por colisión (Piso 2)
	_verificar_colision_combate()

func _patrullar(delta: float) -> void:
	if puntos_absolutos.is_empty():
		_frenar(delta)
		return

	var destino: Vector3 = puntos_absolutos[indice_punto]
	_moverse_hacia(destino, 1.0, delta)

	if global_position.distance_to(destino) < 0.4:
		indice_punto = (indice_punto + 1) % puntos_absolutos.size()

func _moverse_hacia(destino: Vector3, factor: float, delta: float) -> void:
	var direccion: Vector3 = destino - global_position
	direccion.y = 0.0

	var objetivo_vel: Vector3 = Vector3.ZERO
	if direccion.length() > 0.05:
		objetivo_vel = direccion.normalized() * velocidad * factor

	velocity.x = move_toward(velocity.x, objetivo_vel.x, aceleracion * delta)
	velocity.z = move_toward(velocity.z, objetivo_vel.z, aceleracion * delta)

	if objetivo_vel.length() > 0.1:
		basis = basis.slerp(
			Basis.looking_at(objetivo_vel),
			delta * 8.0
		).orthonormalized()
	
	if anim.has_animation("walk"):
		anim.play("walk")

func _moverse_lejos_de(amenaza: Vector3, delta: float) -> void:
	var direccion: Vector3 = global_position - amenaza
	direccion.y = 0.0
	_moverse_hacia(global_position + direccion, 1.3, delta)

func _frenar(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, aceleracion * delta)
	velocity.z = move_toward(velocity.z, 0.0, aceleracion * delta)
	if anim.has_animation("idle"):
		anim.play("idle")

@onready var audio_ataque: AudioStreamPlayer = $AudioStreamPlayer 

func _verificar_colision_combate() -> void:
	for i in range(get_slide_collision_count()):
		var colision = get_slide_collision(i) 
		var collider = colision.get_collider()
		if collider and collider == jugador:
			print("¡Colisión con el jugador! Iniciando combate por turnos...")
			
			if (audio_ataque):
				print("Audio ataque existe")
				if (not audio_ataque.playing):
					audio_ataque.play()
			else:
				print("Audio ataque no existe")	
			if collider.has_method("recibir_danio"):
				collider.recibir_danio(10.0)
			break

func recibir_golpe(danio: float) -> void:
	vida -= danio
	print(name, ": vida ", vida)
	if vida <= 0:
		print(name, " destruida")
		queue_free()
