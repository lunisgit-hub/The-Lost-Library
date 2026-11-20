extends Area3D

signal evento(posicion: Vector3)

@export var tecla: Key = KEY_T
@export var que_representa: String = "fallar enigma"
# NUEVO: Ruta a la escena de la siguiente zona
@export_file("*.tscn") var escena_siguiente: String = "" 

@onready var audio_victoria: AudioStreamPlayer = $AudioStreamPlayer if has_node("AudioStreamPlayer") else null

var antes := false
var usado := false
var jugador_dentro: Node3D = null
var avisando := false

func _enter_tree() -> void:
	add_to_group("disparadores")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(_delta: float) -> void:
	var ahora := Input.is_key_pressed(tecla)
	if ahora and not antes:
		evento.emit(global_position)
	antes = ahora
	if jugador_dentro and not usado and enemigos_vivos() == 0:
		_on_body_entered(jugador_dentro)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		jugador_dentro = body
	if body.is_in_group("jugador") and not usado:
		var vivos := enemigos_vivos()
		if vivos > 0:
			if not avisando:
				avisar_bloqueo(vivos)
			return
		usado = true
		print("¡El jugador llegó a la puerta! ¡Victoria!")
		
		# Reproducir el sonido de victoria
		if audio_victoria and not audio_victoria.playing:
			audio_victoria.play()
			
		# Detener a los enemigos
		var enemigos = get_tree().get_nodes_in_group("enemigos") 
		for enemigo in enemigos:
			if enemigo.has_method("detener_persecucion"):
				enemigo.detener_persecucion()
			elif "estado_actual" in enemigo:
				enemigo.estado_actual = 0
		
		# NUEVO: Cambiar a la siguiente escena si está definida
		if escena_siguiente != "":
			var transicion = get_node_or_null("/root/Transicion")
			if transicion:
				transicion.cambiar(escena_siguiente)
			else:
				get_tree().change_scene_to_file(escena_siguiente)


func _on_body_exited(body: Node3D) -> void:
	if body == jugador_dentro:
		jugador_dentro = null


func enemigos_vivos() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemigo_combate"):
		if not e.get("vencido"):
			n += 1
	return n


func avisar_bloqueo(vivos: int) -> void:
	avisando = true
	var capa := CanvasLayer.new()
	capa.layer = 50
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)
	var l := Label.new()
	l.text = "La puerta no cede… aún queda 1 enemigo en este piso" if vivos == 1 else "La puerta no cede… aún quedan %d enemigos en este piso" % vivos
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.position.y -= 110
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Color(0.91, 0.863, 0.753))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 3)
	var fuente := load("res://assets/CormorantGaramond-MediumItalic.woff2") as Font
	if fuente:
		l.add_theme_font_override("font", fuente)
	l.modulate.a = 0.0
	capa.add_child(l)
	var tw := capa.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): avisando = false)
	tw.tween_callback(capa.queue_free)
