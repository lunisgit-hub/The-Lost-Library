class_name HudCombate
extends CanvasLayer
# Interfaz del combate por turnos (inspirada en los menús de pinceladas de
# Expedition 33). Solo muestra y avisa: las reglas viven en combate_manager.gd.
#   accion_elegida(id)   -> el jugador eligió del menú (teclas 1-6 o clic)
#   dilema_elegido(op)   -> "leer" (E) o "quemar" (Q) al vencer

signal accion_elegida(id: String)
signal dilema_elegido(op: String)

@export var c_noche := Color("#19213E")
@export var c_corrupcion := Color("#431C5E")
@export var c_magia := Color("#AF98C7")
@export var c_sabiduria := Color("#93B95A")
@export var c_papel := Color("#80602E")
@export var c_texto := Color("#E8DCC0")
@export var c_error := Color("#B0407A")
@export var tex_divisor: Texture2D = preload("res://ui_trivia/divisor.png")
@export var tex_sello: Texture2D = preload("res://ui_trivia/sello.png")

var raiz: Control
var lbl_enemigo: Label
var lbl_estados: Label
var barra_enemigo: ProgressBar
var barra_velam: ProgressBar
var lbl_vida: Label
var puntos_tinta: Array[Panel] = []
var menu: VBoxContainer
var lbl_mensaje: Label
var anillo: AnilloParry
var dilema: Control
var lbl_dilema_titulo: Label
var lbl_lore: Label
var lbl_quemar: Label
var opciones_menu: Array = []
var esperando_dilema := false


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir()
	visible = false


# ------------------------------------------------------------- API

func abrir(nombre: String) -> void:
	lbl_enemigo.text = nombre
	lbl_mensaje.text = ""
	dilema.visible = false
	anillo.visible = false
	visible = true
	raiz.modulate.a = 0.0
	create_tween().tween_property(raiz, "modulate:a", 1.0, 0.3)


func cerrar() -> void:
	var tw := create_tween()
	tw.tween_property(raiz, "modulate:a", 0.0, 0.3)
	await tw.finished
	visible = false


func actualizar(d: Dictionary) -> void:
	barra_enemigo.max_value = d.vida_e_max
	barra_enemigo.value = d.vida_e
	barra_velam.max_value = d.vida_v_max
	barra_velam.value = d.vida_v
	lbl_vida.text = "%d / %d" % [d.vida_v, d.vida_v_max]
	lbl_estados.text = d.estados
	for i in puntos_tinta.size():
		puntos_tinta[i].visible = i < d.tinta_max
		var lleno: bool = i < d.tinta
		(puntos_tinta[i].get_theme_stylebox("panel") as StyleBoxFlat).bg_color = c_magia if lleno else Color(0.08, 0.07, 0.12)


## opciones: [{id, texto, detalle, activo}]
func mostrar_menu(opciones: Array) -> void:
	opciones_menu = opciones
	for h in menu.get_children():
		h.queue_free()
	for i in opciones.size():
		var o: Dictionary = opciones[i]
		menu.add_child(_pincelada(i, o))
	menu.visible = true
	menu.modulate.a = 0.0
	create_tween().tween_property(menu, "modulate:a", 1.0, 0.2)


func ocultar_menu() -> void:
	menu.visible = false


func mensaje(t: String, color := Color.WHITE) -> void:
	lbl_mensaje.text = t
	lbl_mensaje.modulate = c_texto if color == Color.WHITE else color
	lbl_mensaje.scale = Vector2.ONE * 1.15
	create_tween().tween_property(lbl_mensaje, "scale", Vector2.ONE, 0.25)


func parry(fase: String, f := 0.0) -> void:
	anillo.visible = fase != "fin"
	anillo.fase = fase
	anillo.f = f
	anillo.queue_redraw()


func mostrar_dilema(nombre: String, lore: String, habilidad: String) -> void:
	lbl_dilema_titulo.text = "El tomo de %s cae a tus pies" % nombre
	lbl_lore.text = lore
	lbl_quemar.text = "[Q]  Quemar · aprendes «%s»" % habilidad
	dilema.visible = true
	esperando_dilema = true
	dilema.modulate.a = 0.0
	create_tween().tween_property(dilema, "modulate:a", 1.0, 0.3)


func _elegir_dilema(op: String) -> void:
	if not esperando_dilema:
		return
	esperando_dilema = false
	dilema.visible = false
	dilema_elegido.emit(op)


func _elegir(i: int) -> void:
	if not menu.visible or i >= opciones_menu.size() or not opciones_menu[i].activo:
		return
	menu.visible = false
	accion_elegida.emit(opciones_menu[i].id)


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if esperando_dilema:
		if k == KEY_E:
			_elegir_dilema("leer")
		elif k == KEY_Q:
			_elegir_dilema("quemar")
		return
	if menu.visible:
		for i in 6:
			if k == KEY_1 + i or k == KEY_KP_1 + i:
				get_viewport().set_input_as_handled()
				_elegir(i)
				return
		if k == KEY_ESCAPE or k == KEY_BACKSPACE:
			for i in opciones_menu.size():
				if opciones_menu[i].id == "volver":
					_elegir(i)


# ------------------------------------------------------------- construcción

func _construir() -> void:
	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)

	# Viñeta oscura para separar el combate de la exploración.
	var velo := ColorRect.new()
	velo.color = Color(c_noche.darkened(0.6), 0.35)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(velo)

	# --- Enemigo (arriba al centro)
	var arriba := VBoxContainer.new()
	arriba.set_anchors_preset(Control.PRESET_CENTER_TOP)
	arriba.position = Vector2(-220, 18)
	arriba.size = Vector2(440, 90)
	arriba.alignment = BoxContainer.ALIGNMENT_CENTER
	raiz.add_child(arriba)
	lbl_enemigo = _label("", 24, c_texto)
	lbl_enemigo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arriba.add_child(lbl_enemigo)
	barra_enemigo = _barra(c_corrupcion.lightened(0.3), Vector2(440, 14))
	arriba.add_child(barra_enemigo)
	lbl_estados = _label("", 15, c_magia)
	lbl_estados.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arriba.add_child(lbl_estados)

	# --- Velam (abajo a la izquierda)
	var velam := VBoxContainer.new()
	velam.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	velam.position = Vector2(28, -130)
	velam.size = Vector2(330, 110)
	raiz.add_child(velam)
	var fila := HBoxContainer.new()
	velam.add_child(fila)
	var sello := TextureRect.new()
	sello.texture = tex_sello
	sello.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sello.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sello.custom_minimum_size = Vector2(46, 46)
	fila.add_child(sello)
	var nom := _label("Velam", 24, c_texto)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(nom)
	lbl_vida = _label("", 18, c_sabiduria)
	fila.add_child(lbl_vida)
	barra_velam = _barra(c_sabiduria, Vector2(330, 14))
	velam.add_child(barra_velam)
	var fila_tinta := HBoxContainer.new()
	fila_tinta.add_theme_constant_override("separation", 8)
	velam.add_child(fila_tinta)
	fila_tinta.add_child(_label("Tinta", 15, c_magia))
	for i in 6:
		var p := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = c_magia
		sb.border_color = c_magia
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		p.add_theme_stylebox_override("panel", sb)
		p.custom_minimum_size = Vector2(16, 16)
		p.rotation = PI / 4.0
		p.pivot_offset = Vector2(8, 8)
		fila_tinta.add_child(p)
		puntos_tinta.append(p)

	# --- Menú de pinceladas (derecha)
	menu = VBoxContainer.new()
	menu.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	menu.position = Vector2(-430, -150)
	menu.size = Vector2(400, 300)
	menu.add_theme_constant_override("separation", 10)
	raiz.add_child(menu)

	# --- Mensaje central
	lbl_mensaje = _label("", 30, c_texto)
	lbl_mensaje.set_anchors_preset(Control.PRESET_CENTER)
	lbl_mensaje.position = Vector2(-400, -230)
	lbl_mensaje.size = Vector2(800, 50)
	lbl_mensaje.pivot_offset = Vector2(400, 25)
	lbl_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raiz.add_child(lbl_mensaje)

	# --- Anillo de parry (centro)
	anillo = AnilloParry.new()
	anillo.set_anchors_preset(Control.PRESET_CENTER)
	anillo.position = Vector2(-160, -160)
	anillo.size = Vector2(320, 320)
	anillo.c_magia = c_magia
	anillo.c_corrupcion = c_corrupcion
	anillo.c_texto = c_texto
	anillo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(anillo)

	# --- Dilema Leer / Quemar
	dilema = PanelContainer.new()
	var sbd := StyleBoxFlat.new()
	sbd.bg_color = Color(c_noche.darkened(0.5), 0.94)
	sbd.border_color = c_papel
	sbd.set_border_width_all(2)
	sbd.set_corner_radius_all(10)
	sbd.content_margin_left = 34
	sbd.content_margin_right = 34
	sbd.content_margin_top = 26
	sbd.content_margin_bottom = 26
	dilema.add_theme_stylebox_override("panel", sbd)
	dilema.set_anchors_preset(Control.PRESET_CENTER)
	dilema.position = Vector2(-330, -150)
	dilema.custom_minimum_size = Vector2(660, 300)
	raiz.add_child(dilema)
	var vd := VBoxContainer.new()
	vd.add_theme_constant_override("separation", 14)
	dilema.add_child(vd)
	lbl_dilema_titulo = _label("", 24, c_texto)
	lbl_dilema_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vd.add_child(lbl_dilema_titulo)
	var div := TextureRect.new()
	div.texture = tex_divisor
	div.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	div.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	div.custom_minimum_size = Vector2(0, 26)
	div.modulate = c_magia
	vd.add_child(div)
	lbl_lore = _label("", 17, c_texto.darkened(0.15))
	lbl_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_lore.custom_minimum_size = Vector2(590, 0)
	vd.add_child(lbl_lore)
	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 20)
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	vd.add_child(botones)
	botones.add_child(_boton_dilema("[E]  Leer · +1 s al reloj", c_sabiduria, "leer", null))
	lbl_quemar = Label.new()
	botones.add_child(_boton_dilema("", c_error, "quemar", lbl_quemar))
	dilema.visible = false


func _pincelada(i: int, o: Dictionary) -> Button:
	var b := Button.new()
	b.text = "%d   %s" % [i + 1, o.texto]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(380, 50)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 21)
	var activo: bool = o.activo
	var tinte := c_magia if activo else Color(0.35, 0.33, 0.4)
	for est in ["normal", "focus", "disabled"]:
		b.add_theme_stylebox_override(est, _trazo(Color(0.02, 0.02, 0.04, 0.88), tinte))
	b.add_theme_stylebox_override("hover", _trazo(Color(c_corrupcion, 0.95), c_magia))
	b.add_theme_stylebox_override("pressed", _trazo(Color(c_corrupcion.lightened(0.1), 0.95), c_texto))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, c_texto if activo else Color(0.45, 0.43, 0.5))
	b.disabled = not activo
	b.rotation = deg_to_rad(-2.0 + (i % 2) * 1.5)   # trazos un poco torcidos, como pinceladas
	b.pressed.connect(_elegir.bind(i))
	if o.has("detalle") and o.detalle != "":
		var d := _label(o.detalle, 13, tinte)
		d.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		d.position = Vector2(-150, -9)
		d.size = Vector2(140, 18)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(d)
	return b


func _trazo(fondo: Color, borde: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.border_width_left = 5
	s.border_width_bottom = 1
	s.corner_radius_top_right = 22
	s.corner_radius_bottom_right = 4
	s.skew = Vector2(0.18, 0)
	s.content_margin_left = 22
	return s


func _boton_dilema(t: String, color: Color, op: String, etiqueta) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(280, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	for est in ["normal", "focus"]:
		var s := _trazo(Color(color.darkened(0.7), 0.95), color)
		s.content_margin_left = 16
		b.add_theme_stylebox_override(est, s)
	var h := _trazo(Color(color.darkened(0.5), 0.95), color.lightened(0.3))
	h.content_margin_left = 16
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_color_override("font_color", c_texto)
	b.add_theme_color_override("font_hover_color", c_texto)
	if etiqueta == null:
		b.text = t
	else:
		# El texto de Quemar cambia según el tomo: va en un Label propio.
		etiqueta.add_theme_font_size_override("font_size", 18)
		etiqueta.add_theme_color_override("font_color", c_texto)
		etiqueta.set_anchors_preset(Control.PRESET_FULL_RECT)
		etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(etiqueta)
	b.pressed.connect(_elegir_dilema.bind(op))
	return b


func _barra(color: Color, tam: Vector2) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = tam
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.03, 0.03, 0.06, 0.9)
	fondo.border_color = Color(c_texto, 0.35)
	fondo.set_border_width_all(1)
	fondo.skew = Vector2(0.3, 0)
	var lleno := StyleBoxFlat.new()
	lleno.bg_color = color
	lleno.skew = Vector2(0.3, 0)
	p.add_theme_stylebox_override("background", fondo)
	p.add_theme_stylebox_override("fill", lleno)
	return p


func _label(t: String, tam: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
	l.add_theme_constant_override("outline_size", 5)
	return l


# Círculo de luz que se cierra sobre Velam: cuando toca el anillo fijo,
# es el momento del parry (Documento de concepto, sección 9).
class AnilloParry extends Control:
	var fase := "aviso"     # aviso: se cierra · ventana: ¡ahora! · fin
	var f := 0.0
	var c_magia := Color.WHITE
	var c_corrupcion := Color.WHITE
	var c_texto := Color.WHITE

	func _draw() -> void:
		var c := size / 2.0
		var r_meta := 52.0
		draw_arc(c, r_meta, 0, TAU, 64, Color(c_texto, 0.8), 3.0, true)
		if fase == "aviso":
			var r := lerpf(150.0, r_meta, f)
			draw_arc(c, r, 0, TAU, 64, Color(c_magia, 0.35 + 0.5 * f), 4.0, true)
		elif fase == "ventana":
			draw_circle(c, r_meta - 4.0, Color(c_magia, 0.35))
			draw_arc(c, r_meta, 0, TAU, 64, c_magia, 8.0, true)
			var fuente := get_theme_default_font()
			draw_string(fuente, c + Vector2(-60, r_meta + 34), "¡ESPACIO!", HORIZONTAL_ALIGNMENT_CENTER, 120, 20, c_texto)
