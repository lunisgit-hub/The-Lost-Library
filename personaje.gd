extends CharacterBody3D

enum Estado { QUIETO, CAMINAR, RODANDO, EN_COMBATE }
const RAPIDEZ_ESTADO = [0.0, 4.0, 7.0, 0.0]

@export var camara: Camera3D
@export var speed_caminar = 4.0
@export var speed_correr = 6.0
@export var speed_rodar = 7.0
@export var tiempo_arranque = 0.20
@onready var anim = $Modelo/AnimationPlayer

@export var vida_maxima: float = 100.0
var vida_actual: float = 100.0

var multiplicador = 1.0
var empuje = Vector3.ZERO
var accion = ""
var avance = Vector3.ZERO

var estado = Estado.QUIETO
var rapidez_max_estado = 0.0

# Variables para el control de la habilidad de rodar
var esta_rodando: bool = false
var tiempo_rodando: float = 0.0
var duracion_rodar: float = 0.4
var direccion_rodar: Vector3 = Vector3.FORWARD

func _ready() -> void:
	if not is_in_group("jugador"):
		add_to_group("jugador")
	vida_actual = vida_maxima

# Aquí usamos correctamente el parámetro 'delta' que te pedía el warning
func _physics_process(delta: float) -> void:
	velocity += get_gravity() * delta
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var entrada = Vector3(input_dir.x, 0.0, input_dir.y)

	var giro_cam = camara.global_rotation.y
	var direction = entrada.rotated(Vector3.UP, giro_cam).normalized()

	var peleando = Input.is_action_pressed("combate")
	var mult_actual = 0.0 if peleando else multiplicador

	# Usamos la variable _rueda (o comprobamos la acción del Input Map correctamente)
	var rueda = Input.is_action_just_pressed("rodar")
	
	if rueda and not esta_rodando and direction.length() > 0:
		esta_rodando = true
		tiempo_rodando = duracion_rodar
		direccion_rodar = direction

	if esta_rodando:
		# Aquí SÍ se usa el 'delta' para calcular el tiempo y el movimiento del salto/rodido
		tiempo_rodando -= delta
		velocity.x = direccion_rodar.x * speed_rodar
		velocity.z = direccion_rodar.z * speed_rodar
		if tiempo_rodando <= 0.0:
			esta_rodando = false
	else:
		var corre = Input.is_action_pressed("correr")
		var speed = speed_correr if corre else speed_caminar
		var objetivo = direction * speed * mult_actual
		var paso = speed / tiempo_arranque * delta

		avance = avance.move_toward(objetivo, paso)
		velocity.x = avance.x + empuje.x
		velocity.z = avance.z + empuje.z

		if direction.length() > 0 and not peleando:
			basis = Basis.looking_at(direction)

	if Input.is_action_just_pressed("disparar"):
		_atacar_o_disparar()

	if Input.is_action_just_pressed("interactuar"):
		_interactuar_entorno()

	move_and_slide()

	var antes = estado
	estado = elegir_estado()
	rapidez_max_estado = RAPIDEZ_ESTADO[estado]
	if estado != antes:
		print("estado ", Estado.keys()[estado], " rapidez ", rapidez_max_estado, " m/s")
	animar()
	_prueba()


func elegir_estado():
	if Input.is_action_pressed("combate"):
		return Estado.EN_COMBATE
	if esta_rodando:
		return Estado.RODANDO
	var rapidez = Vector2(velocity.x, velocity.z).length()
	if rapidez < 0.1:
		return Estado.QUIETO
	return Estado.CAMINAR


func _atacar_o_disparar() -> void:
	print("¡Acción de disparo/ataque activada con la tecla J!")


func _interactuar_entorno() -> void:
	print("¡Interactuando con el entorno (Estanterías/Reloj) con la tecla E!")
var ya_murio: bool = false
@onready var audio_perder: AudioStreamPlayer = $AudioStreamPlayer

func recibir_danio(cantidad: float) -> void:
	if ya_murio:
		return # Si ya murió, ignoramos cualquier daño adicional
	vida_actual -= cantidad
	print("¡El jugador recibió daño! Vida actual: ", vida_actual)
	
	if vida_actual <= 0:
		_morir()

func _morir() -> void:
	if ya_murio:
		return
		
	ya_murio = true
	print("El jugador ha sido derrotado. Mostrando pantalla de fin de partida...")
	
	# Reproducir el sonido de derrota exactamente una vez
	if audio_perder and not audio_perder.playing:
		audio_perder.play()
		
	# Desactivar movimientos o entradas si lo deseas
	set_physics_process(false)


func animar():
	if accion != "":
		anim.speed_scale = 1.0
		anim.play(accion)
		return
	match estado:
		Estado.QUIETO:
			anim.speed_scale = 1.0
			anim.play("idle")
		Estado.CAMINAR:
			anim.speed_scale = avance.length() / speed_caminar
			anim.play("walk")
		Estado.RODANDO:
			anim.speed_scale = 1.0
			if anim.has_animation("roll"):
				anim.play("roll")
			else:
				anim.play("walk")
		Estado.EN_COMBATE:
			anim.speed_scale = 1.0
			anim.play("idle")


# ---------------------------------------------------------------------------
# PRUEBAS AUTOMÁTICAS (Mantenidas sin cambios)
# ---------------------------------------------------------------------------
@export_enum("Ninguna", "Avanzar 60 cuadros", "Avanzar 60 y soltar", "Avanzar y la acción desde el cuadro 30", "Mantener la acción 2 s", "Avanzar con la acción 60 cuadros", "Diagonal W+D 60 cuadros") var prueba = 0
@export var accion_prueba = ""
var _cuadro = 0
var _termino = false
var _y_max = 0.0
var _cuadro_max = 0

func _prueba():
	if prueba == 0 or _termino:
		return
	_cuadro += 1
	var avanzar = "move_up"
	var lado = "move_right"
	if _cuadro == 1:
		if prueba <= 3 or prueba == 5:
			_apretar(avanzar)
		if prueba == 4 or prueba == 5:
			_apretar(accion_prueba)
		if prueba == 6:
			_apretar(avanzar)
			_apretar(lado)
		return
	var n = _cuadro - 1
	if prueba == 3 and n == 30:
		_apretar(accion_prueba)
	if prueba == 2 and n == 60:
		Input.action_release(avanzar)
	var marcas = []
	if prueba == 1 or prueba == 5:
		marcas = [1, 2, 3, 5, 10, 15, 20, 30, 60]
	elif prueba == 2:
		marcas = [59, 60, 61, 62, 63, 65, 70, 80, 90]
	elif prueba == 3:
		marcas = [29, 30, 31, 32, 33, 35, 40, 45, 50, 60, 75, 90]
	elif prueba == 6:
		marcas = [1, 30, 60]
	else:
		marcas = [1, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150]
	if n in marcas:
		print("[prueba] cuadro ", n, ": ", _resumen())
	_cambios(n)
	if global_position.y > _y_max + 0.0001:
		_y_max = global_position.y
		_cuadro_max = n
	if n == marcas[-1]:
		Input.action_release(avanzar)
		Input.action_release(lado)
		_soltar(accion_prueba)
		_termino = true
		if _y_max > 0.01:
			print("[prueba] altura máxima ", snappedf(_y_max, 0.01), " en el cuadro ", _cuadro_max)

func _resumen():
	var t = "posición " + str(global_position.snappedf(0.01))
	t += " · rapidez " + str(snappedf(Vector2(velocity.x, velocity.z).length(), 0.01))
	t += " · y " + str(snappedf(global_position.y, 0.01))
	t += " · animación " + str(anim.current_animation)
	for nodo in _con_estado():
		t += " · " + str(nodo.name) + ".estado " + _nombre(nodo)
	return t

var _antes = {}

func _cambios(n):
	for nodo in _con_estado():
		var e = _nombre(nodo)
		if _antes.has(nodo) and _antes[nodo] != e:
			print("[prueba] cuadro ", n, ": ", nodo.name, ".estado cambia a ", e)
		_antes[nodo] = e

func _con_estado():
	var lista = []
	for nodo in [self] + get_children() + get_tree().get_nodes_in_group("probar"):
		if nodo.get_script() != null and "estado" in nodo:
			lista.append(nodo)
	return lista

func _nombre(nodo):
	var nombres = nodo.get_script().get_script_constant_map().get("Estado", {})
	for k in nombres:
		if nombres[k] == nodo.estado:
			return k
	return str(nodo.estado)

func _apretar(a):
	if a == "":
		print("[prueba] escriban el nombre de la acción en 'Accion Prueba'")
	elif not InputMap.has_action(a):
		print("[prueba] falta la acción '", a, "' en el Input Map")
	else:
		Input.action_press(a)

func _soltar(a):
	if a != "" and InputMap.has_action(a):
		Input.action_release(a)
		
