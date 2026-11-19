extends Node3D
## Punto de descanso (como las banderas de Expedition 33).
## Cerca de él, con [E] ("interactuar"): Velam recupera toda la vida y este lugar
## queda guardado. Si después cae, reaparece aquí con la vida llena (una vez por
## descanso) en vez de perder la partida.
## Para poner otro: instancien res://descanso.tscn en la escena y muévanlo.

@export var tecla = "interactuar"
@export var alcance = 2.2
@export var color_luz := Color(1.0, 0.78, 0.45)

var pj: Node3D = null
var etiqueta: Label3D
var aviso: Label3D
var libro: MeshInstance3D
var luz: OmniLight3D
var sonido: AudioStreamPlayer
var tiempo := 0.0


func _ready():
	add_to_group("interactivos")
	pj = get_tree().get_first_node_in_group("jugador")
	_construir()


func _construir():
	# Atril de piedra
	var pie := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.18
	cil.bottom_radius = 0.32
	cil.height = 1.0
	pie.mesh = cil
	pie.position.y = 0.5
	var piedra := StandardMaterial3D.new()
	piedra.albedo_color = Color(0.22, 0.2, 0.24)
	piedra.roughness = 0.9
	pie.material_override = piedra
	add_child(pie)
	# Libro abierto que flota y brilla
	libro = MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.55, 0.06, 0.4)
	libro.mesh = caja
	libro.position.y = 1.25
	var brillo := StandardMaterial3D.new()
	brillo.albedo_color = Color(0.95, 0.88, 0.7)
	brillo.emission_enabled = true
	brillo.emission = color_luz
	brillo.emission_energy_multiplier = 1.6
	libro.material_override = brillo
	add_child(libro)
	luz = OmniLight3D.new()
	luz.light_color = color_luz
	luz.light_energy = 1.4
	luz.omni_range = 4.0
	luz.position.y = 1.5
	add_child(luz)
	etiqueta = Label3D.new()
	etiqueta.text = "[E] Descansar"
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.no_depth_test = true
	etiqueta.font_size = 48
	etiqueta.outline_size = 10
	etiqueta.pixel_size = 0.004
	etiqueta.position.y = 1.9
	etiqueta.visible = false
	add_child(etiqueta)
	aviso = etiqueta.duplicate() as Label3D
	aviso.modulate = Color(0.58, 0.85, 0.42)
	aviso.position.y = 2.3
	add_child(aviso)
	var st = load("res://sonidos/descanso.wav")
	if st != null:
		sonido = AudioStreamPlayer.new()
		sonido.stream = st
		add_child(sonido)


func _process(delta):
	tiempo += delta
	libro.position.y = 1.25 + sin(tiempo * 1.8) * 0.06
	libro.rotation.y += delta * 0.4
	if pj == null or not is_instance_valid(pj):
		return
	var d := Vector2(pj.global_position.x - global_position.x, pj.global_position.z - global_position.z).length()
	var cerca := d <= alcance and not get_tree().paused
	etiqueta.visible = cerca
	if cerca and InputMap.has_action(tecla) and Input.is_action_just_pressed(tecla):
		descansar()


func descansar():
	var salud = pj.get_node_or_null("Salud")
	if salud != null:
		salud.vida = salud.vida_inicial
		salud.punto = pj.global_position
		salud.reapariciones = maxi(salud.reapariciones, 1)
		salud.cambio.emit(salud.vida)
	if sonido:
		sonido.play()
	print("descanso: vida llena y lugar guardado en ", pj.global_position.snappedf(0.1))
	var tw := create_tween()
	tw.tween_property(luz, "light_energy", 5.0, 0.15)
	tw.tween_property(luz, "light_energy", 1.4, 0.8)
	aviso.text = "Vida restaurada · lugar guardado"
	aviso.visible = true
	aviso.modulate.a = 1.0
	var tw2 := create_tween()
	tw2.tween_interval(1.6)
	tw2.tween_property(aviso, "modulate:a", 0.0, 0.6)
	tw2.tween_callback(func(): aviso.visible = false)
