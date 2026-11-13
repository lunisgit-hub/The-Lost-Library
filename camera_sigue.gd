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
@export_group("Combate")
@export var combate_atras := 3.0
@export var combate_lado := 2.6
@export var combate_altura := 1.8
@export_range(0.0, 1.0) var combate_hacia_enemigo := 0.7
@export var combate_suavizado := 4.0

var arrastrando := false
var dist_actual := 0.0
var foco_suave := Vector3.ZERO
var en_combate := false
var enemigo_combate: Node3D = null
var lado := 1.0
var giro_combate := 0.0
var excluir_combate: Array[RID] = []
var reloj_toma := 0.0
var alto_enemigo := 2.0
var centro_enemigo := Vector3(0, 1, 0)
var ultimo_centro := Vector3.ZERO
var sacudida := 0.0
var fov_base := 75.0


func _ready() -> void:
	top_level = true                           # ignora la rotación del personaje
	process_mode = Node.PROCESS_MODE_ALWAYS
	dist_actual = distancia
	fov_base = fov
	if objetivo != null:
		foco_suave = _foco()
		global_position = _destino()
		_mirar()


func _unhandled_input(event: InputEvent) -> void:
	if en_combate or get_tree().paused:
		arrastrando = false
		return
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
	return _sin_chocar(_foco() + dir * dist_actual)


func _sin_chocar(d: Vector3) -> Vector3:
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
	if global_position.distance_to(foco_suave) > 0.05:
		look_at(foco_suave, Vector3.UP)


func _process(delta: float) -> void:
	if objetivo == null:
		return
	if get_tree().paused and not en_combate:
		return
	if en_combate:
		reloj_toma -= delta
		if reloj_toma <= 0.0:
			reloj_toma = 0.3
			_elegir_toma()
		var kc := 1.0 - exp(-combate_suavizado * delta)
		global_position = global_position.lerp(_destino_combate(lado), kc)
		foco_suave = foco_suave.lerp(_foco_combate(), kc)
	else:
		var k := 1.0 - exp(-suavizado * delta)
		dist_actual = lerpf(dist_actual, distancia, k)
		global_position = global_position.lerp(_destino(), k)
		foco_suave = foco_suave.lerp(_foco(), 1.0 - exp(-20.0 * delta))
	_mirar()
	if sacudida > 0.005:
		h_offset = randf_range(-1.0, 1.0) * sacudida
		v_offset = randf_range(-1.0, 1.0) * sacudida
		sacudida = lerpf(sacudida, 0.0, 1.0 - exp(-12.0 * delta))
	else:
		sacudida = 0.0
		h_offset = 0.0
		v_offset = 0.0
	# El techo se ve cuando la cámara está por debajo de él; desde arriba estorba.
	var bit := 1 << (capa_techo - 1)
	if global_position.y < techo_bajo:
		cull_mask |= bit
	else:
		cull_mask &= ~bit



func enfocar_combate(enemigo: Node3D) -> void:
	if objetivo == null or enemigo == null:
		return
	en_combate = true
	enemigo_combate = enemigo
	giro_combate = 0.0
	lado = 1.0
	reloj_toma = 0.3
	arrastrando = false
	var caja := _caja_visual(enemigo)
	if caja.size.length() > 0.01:
		alto_enemigo = clampf(caja.size.y, 0.5, 12.0)
		centro_enemigo = caja.get_center() - enemigo.global_position
	else:
		alto_enemigo = 2.0
		centro_enemigo = Vector3(0, 1.0, 0)
	ultimo_centro = enemigo.global_position + centro_enemigo
	var hacia := ultimo_centro - objetivo.global_position
	hacia.y = 0.0
	if hacia.length() > 0.05:
		objetivo.basis = Basis.looking_at(hacia.normalized())
	excluir_combate.clear()
	if objetivo is CollisionObject3D:
		excluir_combate.append((objetivo as CollisionObject3D).get_rid())
	var cuerpos: Array = enemigo.find_children("*", "CollisionObject3D", true, false)
	var raiz_e: Node = enemigo
	while raiz_e != null and not (raiz_e is CollisionObject3D) and raiz_e.get_parent() is Node3D:
		raiz_e = raiz_e.get_parent()
	if raiz_e is CollisionObject3D:
		cuerpos.append(raiz_e)
	for c in cuerpos:
		excluir_combate.append((c as CollisionObject3D).get_rid())
	_elegir_toma(true)


func soltar_combate() -> void:
	en_combate = false
	enemigo_combate = null


func _centro_enemigo() -> Vector3:
	if is_instance_valid(enemigo_combate):
		ultimo_centro = enemigo_combate.global_position + centro_enemigo
	return ultimo_centro


func _destino_combate(s: float, recortar := true, giro_extra := INF) -> Vector3:
	if is_inf(giro_extra):
		giro_extra = giro_combate
	var pj := objetivo.global_position
	var hacia := _centro_enemigo() - pj
	hacia.y = 0.0
	var sep := hacia.length()
	var frente := hacia / sep if sep > 0.05 else -objetivo.global_basis.z
	frente = frente.rotated(Vector3.UP, deg_to_rad(giro_extra))
	var derecha := frente.cross(Vector3.UP).normalized()
	var tam := maxf(sep, alto_enemigo)
	var d := pj - frente * (combate_atras + tam * 0.35) \
		+ derecha * (combate_lado * s) \
		+ Vector3.UP * (combate_altura + alto_enemigo * 0.2)
	return _sin_chocar(d) if recortar else d


func _foco_combate() -> Vector3:
	return _foco().lerp(_centro_enemigo(), combate_hacia_enemigo)


func _se_ve(desde: Vector3, hasta: Vector3) -> bool:
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta)
	consulta.exclude = excluir_combate
	return get_world_3d().direct_space_state.intersect_ray(consulta).is_empty()


func _puntaje(s: float, g: float) -> float:
	var d := _destino_combate(s, true, g)
	var p := combate_hacia_enemigo
	var puntos := d.distance_to(_destino_combate(s, false, g))
	if not _se_ve(d, _centro_enemigo()):
		puntos += 10.0
	if not _se_ve(d, _foco()):
		puntos += 6.0
	if not _se_ve(d, _foco().lerp(_centro_enemigo(), p)):
		puntos += 2.0
	puntos += absf(g) / 40.0
	if s < 0.0:
		puntos += 0.2
	return puntos


func _elegir_toma(forzar := false) -> void:
	var actual := _puntaje(lado, giro_combate)
	var mejor := actual
	var mejor_s := lado
	var mejor_g := giro_combate
	for g in [0.0, 25.0, -25.0, 50.0, -50.0, 80.0, -80.0, 115.0, -115.0]:
		for s in [1.0, -1.0]:
			var p := _puntaje(s, g)
			if p < mejor:
				mejor = p
				mejor_s = s
				mejor_g = g
	if forzar or mejor < actual - 1.0:
		lado = mejor_s
		giro_combate = mejor_g


func _caja_visual(n: Node) -> AABB:
	var caja := AABB()
	var hay := false
	var lista: Array = n.find_children("*", "GeometryInstance3D", true, false)
	if n is GeometryInstance3D:
		lista.append(n)
	for g in lista:
		var gi := g as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		var c: AABB = gi.global_transform * gi.get_aabb()
		caja = c if not hay else caja.merge(c)
		hay = true
	return caja



func sacudir(fuerza: float) -> void:
	sacudida = maxf(sacudida, fuerza)


func golpe_fov(cuanto: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "fov", fov_base - cuanto, 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "fov", fov_base, 0.35).set_trans(Tween.TRANS_SINE)
