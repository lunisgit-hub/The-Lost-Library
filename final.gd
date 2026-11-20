extends Node3D

const ORO = Color(1.0, 0.76, 0.4)
const PAPEL = Color(0.91, 0.863, 0.753)

var creditos: Label3D
var base_creditos := Vector3.ZERO
var t := 0.0
var aviso: Label
var listo := false


func _ready() -> void:
	crear_entorno()
	crear_polvo()
	crear_paginas()
	preparar_creditos()
	crear_interfaz()


func _process(delta: float) -> void:
	t += delta
	if is_instance_valid(creditos):
		creditos.position = base_creditos + Vector3(0, sin(t * 0.8) * 0.15, 0)
	if aviso:
		aviso.modulate.a = 0.45 + sin(t * 2.2) * 0.25 if listo else aviso.modulate.a


func _unhandled_input(event: InputEvent) -> void:
	if not listo:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ENTER):
		listo = false
		var transicion = get_node_or_null("/root/Transicion")
		if transicion:
			transicion.cambiar("res://menu.tscn")
		else:
			get_tree().change_scene_to_file("res://menu.tscn")


func crear_entorno() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.02, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.36, 0.22)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.fog_enabled = true
	env.fog_light_color = Color(0.35, 0.22, 0.12)
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func material_aditivo(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	return m


func crear_polvo() -> void:
	var p := CPUParticles3D.new()
	p.amount = 260
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.position = Vector3(0, 4.0, 8.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(13, 4, 22)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.gravity = Vector3(0, 0.05, 0)
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.2
	var s := SphereMesh.new()
	s.radius = 0.03
	s.height = 0.06
	s.radial_segments = 6
	s.rings = 3
	s.material = material_aditivo(Color(ORO, 0.9))
	p.mesh = s
	add_child(p)


func crear_paginas() -> void:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = Vector3(0, 11.0, 8.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(11, 0.5, 18)
	p.direction = Vector3.DOWN
	p.spread = 25.0
	p.gravity = Vector3(0, -0.6, 0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.3)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = PAPEL
	q.material = m
	p.mesh = q
	add_child(p)


func preparar_creditos() -> void:
	creditos = get_node_or_null("Label3D")
	if creditos == null:
		return
	base_creditos = creditos.position
	creditos.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	creditos.modulate = Color(ORO, 0.0)
	creditos.outline_modulate = Color(0.12, 0.06, 0.02, 0.0)
	creditos.outline_size = 14
	creditos.font_size = 40
	creditos.line_spacing = 6.0
	var fuente := load("res://assets/CormorantGaramond-SemiBold.woff2") as Font
	if fuente:
		creditos.font = fuente
	var luz := OmniLight3D.new()
	luz.light_color = ORO
	luz.light_energy = 0.0
	luz.omni_range = 7.0
	luz.position = base_creditos + Vector3(0, 0, 1.5)
	add_child(luz)
	var tw := create_tween().set_parallel()
	tw.tween_property(creditos, "modulate:a", 1.0, 2.5).set_delay(0.8)
	tw.tween_property(creditos, "outline_modulate:a", 0.9, 2.5).set_delay(0.8)
	tw.tween_property(luz, "light_energy", 2.5, 2.5).set_delay(0.8)


func crear_interfaz() -> void:
	var fuente := load("res://assets/CormorantGaramond-SemiBold.woff2") as Font
	var cursiva := load("res://assets/CormorantGaramond-MediumItalic.woff2") as Font
	var capa := CanvasLayer.new()
	add_child(capa)
	aviso = _label("Enter / Esc · volver al menú", 22, PAPEL, cursiva)
	aviso.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	aviso.grow_vertical = Control.GROW_DIRECTION_BEGIN
	aviso.position.y -= 40
	aviso.modulate.a = 0.0
	capa.add_child(aviso)
	await victoria(fuente, cursiva)
	listo = true


func victoria(fuente: Font, cursiva: Font) -> void:
	get_tree().paused = true
	var capa := CanvasLayer.new()
	capa.layer = 20
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)
	var negro := ColorRect.new()
	negro.color = Color(0.012, 0.008, 0.016)
	negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(negro)
	var brasas := CPUParticles2D.new()
	brasas.amount = 90
	brasas.lifetime = 7.0
	brasas.preprocess = 7.0
	brasas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	brasas.direction = Vector2.UP
	brasas.spread = 25.0
	brasas.gravity = Vector2(0, -12)
	brasas.initial_velocity_min = 15.0
	brasas.initial_velocity_max = 45.0
	brasas.scale_amount_min = 1.5
	brasas.scale_amount_max = 4.0
	brasas.color = Color(ORO, 0.7)
	var rampa := Gradient.new()
	rampa.set_color(0, Color(1, 1, 1, 0))
	rampa.add_point(0.2, Color(1, 1, 1, 1))
	rampa.set_color(rampa.get_point_count() - 1, Color(1, 1, 1, 0))
	brasas.color_ramp = rampa
	brasas.modulate.a = 0.0
	capa.add_child(brasas)
	var tam := get_viewport().get_visible_rect().size
	brasas.position = Vector2(tam.x / 2.0, tam.y + 10)
	brasas.emission_rect_extents = Vector2(tam.x / 2.0, 10)
	capa.create_tween().tween_property(brasas, "modulate:a", 1.0, 3.0)
	var centro := VBoxContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_theme_constant_override("separation", 22)
	capa.add_child(centro)
	await _esperar(1.0)
	var leidos := 0
	var quemados := 0
	for v in CombateManager.tomos.values():
		if v == "leido":
			leidos += 1
		elif v == "quemado":
			quemados += 1
	var cierre := "Las páginas que leíste ahora viven en ti."
	if quemados > leidos:
		cierre = "El fuego limpió la tinta… y también la memoria."
	var lineas := [
		"El Último Bibliotecario cierra su libro.",
		"La tinta deja de pudrirse. La torre vuelve a respirar.",
		cierre,
	]
	for texto in lineas:
		var l := _label(texto, 30, PAPEL, cursiva)
		l.modulate.a = 0.0
		centro.add_child(l)
		var tw := capa.create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 1.4)
		await tw.finished
		await _esperar(1.3)
	var salida := capa.create_tween().set_parallel()
	for l in centro.get_children():
		salida.tween_property(l, "modulate:a", 0.0, 1.2)
	await salida.finished
	for l in centro.get_children():
		l.queue_free()
	await _esperar(0.6)
	var linea_sup := _divisor()
	centro.add_child(linea_sup)
	var titulo := _label("GRACIAS POR JUGAR", 76, ORO, fuente)
	titulo.add_theme_constant_override("outline_size", 10)
	titulo.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.02, 0.6))
	titulo.modulate.a = 0.0
	centro.add_child(titulo)
	var linea_inf := _divisor()
	centro.add_child(linea_inf)
	var nombre := _label("T H E   L O S T   L I B R A R Y", 26, PAPEL, fuente)
	nombre.modulate.a = 0.0
	centro.add_child(nombre)
	var datos := _label("Tomos leídos: %d   ·   Tomos quemados: %d" % [leidos, quemados], 22, Color(PAPEL, 0.75), cursiva)
	datos.modulate.a = 0.0
	centro.add_child(datos)
	await get_tree().process_frame
	titulo.pivot_offset = titulo.size / 2.0
	titulo.scale = Vector2(0.85, 0.85)
	var destello := ColorRect.new()
	destello.color = Color(ORO, 0.0)
	destello.set_anchors_preset(Control.PRESET_FULL_RECT)
	destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(destello)
	var tw2 := capa.create_tween().set_parallel()
	tw2.tween_property(titulo, "modulate:a", 1.0, 2.0)
	tw2.tween_property(titulo, "scale", Vector2.ONE, 2.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw2.tween_property(linea_sup, "custom_minimum_size:x", 520.0, 1.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw2.tween_property(linea_inf, "custom_minimum_size:x", 520.0, 1.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw2.tween_property(destello, "color:a", 0.18, 0.25)
	tw2.chain().tween_property(destello, "color:a", 0.0, 1.5)
	await _esperar(1.8)
	var tw3 := capa.create_tween()
	tw3.tween_property(nombre, "modulate:a", 1.0, 1.2)
	tw3.tween_property(datos, "modulate:a", 1.0, 1.0)
	await tw3.finished
	var seguir := _label("Enter · continuar", 22, PAPEL, cursiva)
	seguir.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	seguir.grow_horizontal = Control.GROW_DIRECTION_BOTH
	seguir.grow_vertical = Control.GROW_DIRECTION_BEGIN
	seguir.position.y -= 40
	capa.add_child(seguir)
	var parpadeo := capa.create_tween().set_loops()
	parpadeo.tween_property(seguir, "modulate:a", 0.25, 0.9)
	parpadeo.tween_property(seguir, "modulate:a", 0.9, 0.9)
	while not (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel")):
		await get_tree().process_frame
	parpadeo.kill()
	get_tree().paused = false
	var fuera := capa.create_tween().set_parallel()
	for n in capa.get_children():
		if n is CanvasItem:
			fuera.tween_property(n, "modulate:a", 0.0, 1.8)
	await fuera.finished
	capa.queue_free()


func _divisor() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(ORO, 0.7)
	d.custom_minimum_size = Vector2(0, 2)
	d.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return d


func _esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _label(texto: String, tam: int, color: Color, fuente: Font) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 3)
	if fuente:
		l.add_theme_font_override("font", fuente)
	return l
