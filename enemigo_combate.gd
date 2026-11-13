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
		cuerpo.set_physics_process(not si)


func vencer() -> void:
	vencido = true
	get_parent().queue_free()
