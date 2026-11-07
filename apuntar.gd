extends Node

@export var tecla = "disparar"
@export var alcance = 20.0
@export_enum("Personaje", "Centro de la cámara", "Mouse") var desde = 0
@export var danio = 25
@export var cadencia = 0.25
@onready var pj = get_parent()

var origen = Vector3.ZERO
var espera = 0.0

func _physics_process(delta):
	espera -= delta
	if Input.is_action_pressed(tecla) and espera <= 0.001:
		espera = cadencia
		var golpe = lanzar_rayo()
		if golpe.is_empty():
			print("no le dio a nada en ", alcance, " m")
			return
		var d = snappedf(origen.distance_to(golpe.position), 0.01)
		if golpe.collider.is_in_group("enemigos"):
			print("¡combate!")
		else:
			print("le dio a ", golpe.collider.name, " a ", d, " m")
		if golpe.collider.has_method("recibir_golpe"):
			golpe.collider.recibir_golpe(danio)

func lanzar_rayo():
	var hacia
	if desde == 0:
		origen = pj.global_position + Vector3(0, 0.8, 0)
		hacia = origen - pj.global_basis.z * alcance
	else:
		var cam = get_viewport().get_camera_3d()
		var punto = get_viewport().get_visible_rect().size / 2
		if desde == 2:
			punto = get_viewport().get_mouse_position()
		origen = cam.project_ray_origin(punto)
		hacia = origen + cam.project_ray_normal(punto) * alcance
	var consulta = PhysicsRayQueryParameters3D.create(origen, hacia)
	consulta.exclude = [pj.get_rid()]
	return pj.get_world_3d().direct_space_state.intersect_ray(consulta)
