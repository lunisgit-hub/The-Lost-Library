extends Camera3D
# Cámara que sigue al personaje desde arriba y que el jugador puede girar
# SOLO cuando lo pide (nunca con el mouse suelto, nunca captura el mouse):
#   Mouse:    clic derecho o del medio + arrastrar = girar / inclinar; rueda = zoom
#   Touchpad: dos dedos de lado = girar; Shift + dos dedos = inclinar;
#             dos dedos arriba/abajo o pellizcar = zoom
#   Táctil:   arrastrar un dedo = girar / inclinar
# La cámara nunca sale de la caja del salón y siempre mira al personaje.

@export var objetivo: Node3D
@export var altura_foco := 1.0                 # mira al pecho, no a los pies
@export_group("Vista inicial")
@export var giro := 0.0                        # grados alrededor del personaje (0 = desde el sur)
@export var inclinacion := 55.0                # grados sobre el horizonte
@export var distancia := 11.0
@export_group("Límites del control")
@export var inclinacion_min := 20.0            # baja: deja mirar hacia el techo
@export var inclinacion_max := 75.0
@export var distancia_min := 5.0
@export var distancia_max := 15.0
@export var sensibilidad := 0.25               # grados por píxel arrastrado
@export var sensibilidad_rueda := 4.0          # grados por paso de dos dedos
@export var paso_zoom := 0.9                   # metros por paso de rueda
@export_group("Salón")
@export var suavizado := 6.0
@export var limite_min := Vector2(-13.5, 6.0)  # x, z: la cámara no sale de aquí
@export var limite_max := Vector2(13.5, 34.0)
@export var altura_max := 11.5
@export var techo_bajo := 6.5                  # por debajo de esta altura se ve el techo
@export_range(1, 20) var capa_techo := 2

var arrastrando := false
var dist_actual := 0.0


func _ready() -> void:
	top_level = true                           # ignora la rotación del personaje
	dist_actual = distancia
	if objetivo != null:
		global_position = _destino()
		_mirar()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		match b.button_index:
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				arrastrando = b.pressed
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if b.pressed:
					var s := -1.0 if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
					var f := b.factor if b.factor > 0.0 else 1.0
					if b.shift_pressed:
						_girar(0.0, -s * sensibilidad_rueda * f)
					else:
						distancia = clampf(distancia + s * paso_zoom * f, distancia_min, distancia_max)
			MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT:
				if b.pressed:
					var s := -1.0 if b.button_index == MOUSE_BUTTON_WHEEL_LEFT else 1.0
					var f := b.factor if b.factor > 0.0 else 1.0
					_girar(s * sensibilidad_rueda * f, 0.0)
	elif event is InputEventMouseMotion and arrastrando:
		var m := event as InputEventMouseMotion
		_girar(-m.relative.x * sensibilidad, m.relative.y * sensibilidad)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_girar(-d.relative.x * sensibilidad, d.relative.y * sensibilidad)
	elif event is InputEventMagnifyGesture:
		var g := event as InputEventMagnifyGesture
		distancia = clampf(distancia / g.factor, distancia_min, distancia_max)
	elif event is InputEventPanGesture:   # touchpads que mandan gestos (macOS y algunos Windows)
		var p := event as InputEventPanGesture
		_girar(-p.delta.x * sensibilidad_rueda, p.delta.y * sensibilidad_rueda)


func _girar(grados_giro: float, grados_inclinacion: float) -> void:
	giro = fposmod(giro + grados_giro, 360.0)
	inclinacion = clampf(inclinacion + grados_inclinacion, inclinacion_min, inclinacion_max)


func _foco() -> Vector3:
	return objetivo.global_position + Vector3(0, altura_foco, 0)


# Dónde quiere estar la cámara: en una esfera alrededor del foco, recortada a la
# caja del salón. Si se recorta, se acerca (como un brazo que choca), sin
# atravesar muros ni ver el vacío de afuera.
func _destino() -> Vector3:
	var inc := deg_to_rad(inclinacion)
	var g := deg_to_rad(giro)
	var dir := Vector3(sin(g) * cos(inc), sin(inc), cos(g) * cos(inc))
	var d := _foco() + dir * dist_actual
	d.x = clampf(d.x, limite_min.x, limite_max.x)
	d.z = clampf(d.z, limite_min.y, limite_max.y)
	d.y = clampf(d.y, 0.8, altura_max)
	# Si algo sólido queda entre el personaje y la cámara, la cámara se pone
	# delante de eso en vez de meterse adentro.
	var espacio := get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(_foco(), d)
	if objetivo is CollisionObject3D:
		consulta.exclude = [(objetivo as CollisionObject3D).get_rid()]
	var golpe := espacio.intersect_ray(consulta)
	if not golpe.is_empty():
		d = golpe.position + golpe.normal * 0.3
	return d


func _mirar() -> void:
	var f := _foco()
	if global_position.distance_to(f) > 0.05:
		look_at(f, Vector3.UP)


func _process(delta: float) -> void:
	if objetivo == null:
		return
	var k := 1.0 - exp(-suavizado * delta)
	dist_actual = lerpf(dist_actual, distancia, k)
	global_position = global_position.lerp(_destino(), k)
	_mirar()
	# El techo se ve cuando la cámara está por debajo de él; desde arriba estorba.
	var bit := 1 << (capa_techo - 1)
	if global_position.y < techo_bajo:
		cull_mask |= bit
	else:
		cull_mask &= ~bit
