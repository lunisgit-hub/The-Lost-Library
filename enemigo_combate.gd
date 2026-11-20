class_name EnemigoCombate
extends Node
# Va como nodo hijo de un enemigo del piso (Errante, libro, guardián...).
# Guarda sus números de combate y crea su TurnoEnemigo (turno_enemigo.gd), que
# es quien decide qué hace en cada turno. No toca el script del enemigo: el
# Errante sigue patrullando y persiguiendo con su propio código.

@export var nombre := "Libro corrupto"
@export var vida := 25
@export var danio := 10                 # ATACAR si fallas el parry
@export var danio_fuerte := 15          # GOLPE_FUERTE (después de CARGAR)
@export var pesos: Array[int] = [50, 30, 20]   # ATACAR, CARGAR, DEFENDER
@export var curas := 0
@export var cura := 10
@export var vida_baja := 0
@export var semilla := 1
@export var ritmo := 1.0                # segundos de aviso antes de cada golpe
@export_enum("hoja", "escudo", "llama") var habilidad := "hoja"   # la que da al quemar su tomo
@export_multiline var lore := "Un tomo de herbario: las plantas de la torre respiraban la tinta de los que leían."
@export var radio := 1.8                # metros para que empiece el combate
@export var punto: NodePath = ^".."     # dónde está el enemigo que se ve
@export var color_luz := Color(0.56, 0.26, 0.82)
@export var es_jefe := false

var turno: Node
var luz: OmniLight3D
var vencido := false
var enfriado := false                   # tras huir: no vuelve a pelear hasta que te alejes


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS    # su luz se anima aunque el mundo esté en pausa
	add_to_group("enemigo_combate")
	turno = Node.new()
	turno.name = "TurnoEnemigo"
	turno.set_script(load("res://turno_enemigo.gd"))
	turno.automatico = false
	turno.vida = vida
	turno.danio = danio
	turno.pesos = pesos
	turno.curas = curas
	turno.cura = cura
	turno.vida_baja = vida_baja
	turno.semilla = semilla
	turno.ritmo = ritmo
	turno.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(turno)
	# Luz que avisa: tenue siempre, fuerte cuando carga un golpe (Taller 4).
	luz = OmniLight3D.new()
	luz.top_level = true
	luz.light_color = color_luz
	luz.light_energy = 0.0
	luz.omni_range = 4.0
	add_child(luz)


func _process(_d: float) -> void:
	if luz:
		luz.global_position = posicion() + Vector3(0, 1.6, 0)


func posicion() -> Vector3:
	var n := get_node_or_null(punto) as Node3D
	return n.global_position if n else Vector3.ZERO


func clave() -> String:
	return "Tomo_" + str(get_parent().name)


func distancia_a(pj: Node3D) -> float:
	var a := posicion()
	return Vector2(a.x - pj.global_position.x, a.z - pj.global_position.z).length()


func puede_iniciar(pj: Node3D) -> bool:
	if vencido or turno == null:
		return false
	var d := distancia_a(pj)
	if enfriado:
		if d > radio + 2.0:
			enfriado = false
		return false
	return d <= radio


func cargando(si: bool) -> void:
	var tw := create_tween()
	tw.tween_property(luz, "light_energy", 3.5 if si else 0.0, 0.4)


func en_combate(si: bool) -> void:
	if not si:
		cargando(false)
	else:
		create_tween().tween_property(luz, "light_energy", 0.8, 0.3)
	# El Errante deja de moverse mientras pelea (el mundo está en pausa igual).
	var cuerpo := get_parent()
	if cuerpo.has_method("set_physics_process"):
		cuerpo.set_physics_process(not si and not vencido)


func vencer() -> void:
	vencido = true
	var cuerpo := get_parent() as Node3D
	if cuerpo == null:
		get_parent().queue_free()
		return
	if cuerpo.has_method("set_physics_process"):
		cuerpo.set_physics_process(false)
	for c in cuerpo.find_children("*", "CollisionShape3D", true, false):
		c.set_deferred("disabled", true)
	_estallido(posicion() + Vector3(0, 1.2, 0))
	var tw := create_tween()
	tw.tween_property(cuerpo, "scale", cuerpo.scale * 1.15, 0.15).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cuerpo, "scale", cuerpo.scale * 0.01, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(cuerpo.queue_free)


func _estallido(donde: Vector3) -> void:
	var escena := get_tree().current_scene
	if escena == null:
		return
	var p := CPUParticles3D.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 70
	p.lifetime = 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6 if not es_jefe else 2.5
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.5 if not es_jefe else 7.0
	p.gravity = Vector3(0, -3.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var gota := SphereMesh.new()
	gota.radius = 0.06
	gota.height = 0.12
	gota.radial_segments = 6
	gota.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color_luz
	m.emission_enabled = true
	m.emission = color_luz
	m.emission_energy_multiplier = 3.0
	gota.material = m
	p.mesh = gota
	escena.add_child(p)
	p.global_position = donde
	p.emitting = true
	var destello := OmniLight3D.new()
	destello.process_mode = Node.PROCESS_MODE_ALWAYS
	destello.light_color = color_luz
	destello.light_energy = 6.0
	destello.omni_range = 6.0 if not es_jefe else 14.0
	escena.add_child(destello)
	destello.global_position = donde
	var tw := destello.create_tween()
	tw.tween_property(destello, "light_energy", 0.0, 1.0)
	tw.tween_callback(destello.queue_free)
	get_tree().create_timer(p.lifetime + 0.5, true, false, true).timeout.connect(p.queue_free)
