extends CharacterBody3D

enum Estado { QUIETO, CAMINAR, EN_COMBATE }
const RAPIDEZ_ESTADO = [0.0, 3.2, 0.0] # Rapidez máxima en cada estado (m/s)

@export var camara: Camera3D
@export var speed_caminar = 3.2  # más lento = los pies patinan menos con la animación
@export var speed_correr = 7.0
@export var tiempo_arranque = 0.20

@export_group("Animaciones")
## Acción del Input Map que lanza el golpe (clic izquierdo = "elegir").
@export var tecla_golpe = "elegir"
## Velocidad de reproducción del golpe (la animación dura 4.3 s a 1.0).
@export var ritmo_golpe = 1.4
## Velocidad de la animación de caminar cuando vas a speed_caminar.
@export var ritmo_caminar = 1.9
## Velocidad de la animación de correr cuando vas a speed_correr.
@export var ritmo_correr = 1.15
## Segundos de mezcla al cambiar de animación.
@export var mezcla = 0.2

var anim: AnimationPlayer = null

var multiplicador = 1.0
var empuje = Vector3.ZERO
var accion = ""
var avance = Vector3.ZERO
var muerto = false

var estado = Estado.QUIETO
var rapidez_max_estado = 0.0


func _ready():
	anim = _buscar_anim()
	if anim != null:
		print("Animaciones del personaje: ", anim.get_animation_list())
		anim.animation_finished.connect(_al_terminar_anim)


func _buscar_anim() -> AnimationPlayer:
	var heroe = get_node_or_null("Heroe")
	if heroe != null and heroe.get("anim") != null:
		return heroe.anim
	# Respaldo: modelo viejo de Kenney
	return get_node_or_null("Modelo/AnimationPlayer")


func _unhandled_input(event):
	if tecla_golpe != "" and InputMap.has_action(tecla_golpe) and event.is_action_pressed(tecla_golpe):
		golpear()


func golpear():
	if muerto or accion != "" or anim == null or not anim.has_animation("golpe"):
		return
	accion = "golpe"
	anim.speed_scale = 1.0
	anim.play("golpe", 0.1, ritmo_golpe)


func _al_terminar_anim(nombre):
	if nombre == accion:
		accion = ""


## Reproduce la muerte y espera a que termine (salud.gd la llama antes de reaparecer o perder).
func morir():
	if muerto:
		return
	muerto = true
	accion = ""
	avance = Vector3.ZERO
	if anim == null or not anim.has_animation("muerte"):
		return
	anim.speed_scale = 1.0
	anim.play("muerte", 0.15)
	await get_tree().create_timer(anim.get_animation("muerte").length + 0.6).timeout


## La usan enemigos como archivista.gd al chocar con Velam.
func recibir_danio(cantidad):
	var salud = get_node_or_null("Salud")
	if salud != null:
		salud.recibir_golpe(int(round(cantidad)))


func revivir():
	muerto = false
	accion = ""
	if anim != null and anim.has_animation("quieto"):
		anim.speed_scale = 1.0
		anim.play("quieto", 0.0)


func _physics_process(delta):
	velocity += get_gravity() * delta
	if muerto:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var entrada = Vector3(input_dir.x, 0.0, input_dir.y)

	var giro_cam = camara.global_rotation.y
	var direction = entrada.rotated(Vector3.UP, giro_cam).normalized()

	var peleando = Input.is_action_pressed("combate") if InputMap.has_action("combate") else false
	var golpeando = accion != ""
	var mult_actual = 0.0 if (peleando or golpeando) else multiplicador

	var corre = Input.is_action_pressed("correr")
	var speed = speed_correr if corre else speed_caminar
	var objetivo = direction * speed * mult_actual
	var paso = speed / tiempo_arranque * delta

	avance = avance.move_toward(objetivo, paso)
	velocity.x = avance.x + empuje.x
	velocity.z = avance.z + empuje.z

	if direction.length() > 0 and not peleando and not golpeando:
		basis = Basis.looking_at(direction)

	move_and_slide()

	var antes = estado
	estado = elegir_estado()
	rapidez_max_estado = RAPIDEZ_ESTADO[estado]
	if estado != antes:
		print("estado ", Estado.keys()[estado], " rapidez ", rapidez_max_estado, " m/s")
	animar()
	_prueba()


func elegir_estado():
	if InputMap.has_action("combate") and Input.is_action_pressed("combate"):
		return Estado.EN_COMBATE
	var rapidez = Vector2(velocity.x, velocity.z).length()
	if rapidez < 0.1:
		return Estado.QUIETO
	return Estado.CAMINAR


func _reproducir(opciones: Array[String], velocidad: float = 1.0):
	for nombre in opciones:
		if anim.has_animation(nombre):
			anim.speed_scale = velocidad
			if anim.current_animation != nombre or not anim.is_playing():
				anim.play(nombre, mezcla)
			return


func animar():
	if anim == null or muerto or accion != "":
		return
	var rapidez = avance.length()
	match estado:
		Estado.QUIETO, Estado.EN_COMBATE:
			_reproducir(["quieto", "idle"])
		Estado.CAMINAR:
			if rapidez > speed_caminar + 0.5:
				_reproducir(["correr", "sprint"], clampf(rapidez / speed_correr, 0.5, 1.2) * ritmo_correr)
			else:
				_reproducir(["caminar", "walk"], clampf(rapidez / speed_caminar, 0.4, 1.2) * ritmo_caminar)


# ---------------------------------------------------------------------------
# PRUEBAS AUTOMÁTICAS. No hace falta entender esta parte: en el Inspector del
# Personaje elijan "Prueba" (y, si la prueba usa una acción, escriban su nombre
# en "Accion Prueba"). Con F5 el personaje se mueve solo y escribe los números
# en el panel Output. La última línea de _physics_process() es _prueba().
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
	t += " · animación " + (str(anim.current_animation) if anim != null else "ninguna")
	for nodo in _con_estado():
		t += " · " + str(nodo.name) + ".estado " + _nombre(nodo)
	return t


# Escribe el cuadro exacto en el que cambia cualquier variable "estado".
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
