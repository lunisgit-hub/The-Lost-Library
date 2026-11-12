class_name HudCombate
extends CanvasLayer

signal accion_elegida(id: String)
signal dilema_elegido(op: String)

@export_group("Tipografía y Texturas Personalizadas")
@export var tex_barra_enemigo_fondo: Texture2D
@export var tex_barra_enemigo_relleno: Texture2D
@export var alto_barra_enemigo := 20.0
@export var fuente_combate: Font
@export var tex_boton_normal: Texture2D
@export var tex_boton_hover: Texture2D
@export var ocultar_barra_velam_abajo := true

@export_group("Diseño Dilema (Leer / Quemar)")
@export var usar_tex_panel_dilema := false
@export var tex_panel_dilema: Texture2D
@export var quitar_fondo_negro_dilema := false
@export var tex_boton_leer: Texture2D
@export var tex_boton_quemar: Texture2D
@export var tam_panel_dilema := Vector2(720, 230)
@export var tam_boton_dilema := Vector2(310, 56)

@export_group("Paleta de Colores")
@export var c_noche := Color("#0D1120")
@export var c_corrupcion := Color("#3B1754")
@export var c_magia := Color("#AF98C7")
@export var c_oro := Color("#D4A359")
@export var c_sabiduria := Color("#93B95A")
@export var c_papel := Color("#80602E")
@export var c_texto := Color("#F2E8D5")
@export var c_error := Color("#C83E6B")
@export var tex_divisor: Texture2D = preload("res://ui_trivia/divisor.png")
@export var tex_sello: Texture2D = preload("res://ui_trivia/sello.png")

var raiz: Control
var lbl_enemigo: Label
var lbl_descripcion_enemigo: Label
var lbl_hp_enemigo: Label
var lbl_estados: Label
var barra_enemigo: ProgressBar
var barra_velam: ProgressBar
var lbl_vida: Label
var fila_velam_info: HBoxContainer
var puntos_tinta: Array[Panel] = []
var menu: Control
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
	if fuente_combate == null:
		fuente_combate = _buscar_fuente_assets()
	_construir()
	visible = false


func _buscar_fuente_assets() -> Font:
	var dir := DirAccess.open("res://assets")
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.get_extension().to_lower() in ["ttf", "otf"]:
				var base := load("res://assets/" + f) as FontFile
				var fv := FontVariation.new()
				fv.base_font = base
				fv.variation_embolden = 0.45
				fv.spacing_glyph = 1
				return fv
			f = dir.get_next()
	return null


func abrir(nombre: String, descripcion: String = "") -> void:
	lbl_enemigo.text = nombre.to_upper()
	if lbl_descripcion_enemigo != null:
		lbl_descripcion_enemigo.text = descripcion
		lbl_descripcion_enemigo.visible = descripcion != ""
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
	create_tween().tween_property(barra_enemigo, "value", float(d.vida_e), 0.25)
	if lbl_hp_enemigo != null:
		lbl_hp_enemigo.text = "%d / %d HP" % [d.vida_e, d.vida_e_max]
	barra_velam.max_value = d.vida_v_max
	create_tween().tween_property(barra_velam, "value", float(d.vida_v), 0.25)
	lbl_vida.text = "%d / %d" % [d.vida_v, d.vida_v_max]
	lbl_estados.text = d.estados
	for i in puntos_tinta.size():
		puntos_tinta[i].visible = i < d.tinta_max
		var lleno: bool = i < d.tinta
		var sb := puntos_tinta[i].get_theme_stylebox("panel") as StyleBoxFlat
		sb.bg_color = c_magia if lleno else Color(0.06, 0.05, 0.1, 0.85)
		sb.border_color = c_oro if lleno else Color(c_magia, 0.35)


func mostrar_menu(opciones: Array) -> void:
	opciones_menu = opciones
	for h in menu.get_children():
		h.queue_free()
	for i in opciones.size():
		var o: Dictionary = opciones[i]
		var btn := _pincelada(i, o)
		var pos_base := Vector2(-i * 22.0, i * 64.0)
		btn.position = pos_base + Vector2(60, 0)
		btn.modulate.a = 0.0
		menu.add_child(btn)
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "position", pos_base, 0.22 + i * 0.04)
		tw.parallel().tween_property(btn, "modulate:a", 1.0, 0.18 + i * 0.04)
	menu.visible = true


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


func mostrar_dilema(nombre: String, _lore: String, habilidad: String) -> void:
	lbl_dilema_titulo.text = "EL TOMO DE %s CAE A TUS PIES" % nombre.to_upper()
	lbl_quemar.text = "[Q]  QUEMAR · «%s»" % habilidad.to_upper()
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


func _construir() -> void:
	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)

	var velo := ColorRect.new()
	velo.color = Color(c_noche.darkened(0.6), 0.28)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(velo)

	var arriba := VBoxContainer.new()
	arriba.set_anchors_preset(Control.PRESET_CENTER_TOP)
	arriba.position = Vector2(-260, 14)
	arriba.size = Vector2(520, 125)
	arriba.alignment = BoxContainer.ALIGNMENT_CENTER
	arriba.add_theme_constant_override("separation", 3)
	raiz.add_child(arriba)

	lbl_enemigo = _label("", 28, c_oro)
	lbl_enemigo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arriba.add_child(lbl_enemigo)

	lbl_descripcion_enemigo = _label("", 15, c_texto.darkened(0.15))
	lbl_descripcion_enemigo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_descripcion_enemigo.visible = false
	arriba.add_child(lbl_descripcion_enemigo)

	barra_enemigo = _barra_jefe(Vector2(480, alto_barra_enemigo))
	arriba.add_child(barra_enemigo)

	lbl_hp_enemigo = _label("", 14, c_texto)
	lbl_hp_enemigo.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_hp_enemigo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hp_enemigo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	barra_enemigo.add_child(lbl_hp_enemigo)

	lbl_estados = _label("", 15, c_magia)
	lbl_estados.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arriba.add_child(lbl_estados)

	var velam := VBoxContainer.new()
	velam.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	velam.position = Vector2(34, -135)
	velam.size = Vector2(340, 115)
	velam.add_theme_constant_override("separation", 10)
	raiz.add_child(velam)
	fila_velam_info = HBoxContainer.new()
	velam.add_child(fila_velam_info)
	var sello := TextureRect.new()
	sello.texture = tex_sello
	sello.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sello.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sello.custom_minimum_size = Vector2(46, 46)
	fila_velam_info.add_child(sello)
	var nom := _label("VELAM", 22, c_texto)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_velam_info.add_child(nom)
	lbl_vida = _label("", 18, c_oro)
	fila_velam_info.add_child(lbl_vida)
	barra_velam = _barra(c_sabiduria, Vector2(330, 12))
	velam.add_child(barra_velam)

	if ocultar_barra_velam_abajo:
		fila_velam_info.visible = false
		barra_velam.visible = false

	var fila_tinta := HBoxContainer.new()
	fila_tinta.add_theme_constant_override("separation", 12)
	velam.add_child(fila_tinta)
	fila_tinta.add_child(_label("TINTA", 16, c_oro))
	for i in 6:
		var p := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = c_magia
		sb.border_color = c_oro
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(2)
		p.add_theme_stylebox_override("panel", sb)
		p.custom_minimum_size = Vector2(18, 18)
		p.rotation = PI / 4.0
		p.pivot_offset = Vector2(9, 9)
		fila_tinta.add_child(p)
		puntos_tinta.append(p)

	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	menu.position = Vector2(-420, -130)
	menu.size = Vector2(400, 280)
	raiz.add_child(menu)

	lbl_mensaje = _label("", 28, c_texto)
	lbl_mensaje.set_anchors_preset(Control.PRESET_CENTER)
	lbl_mensaje.position = Vector2(-400, -220)
	lbl_mensaje.size = Vector2(800, 50)
	lbl_mensaje.pivot_offset = Vector2(400, 25)
	lbl_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raiz.add_child(lbl_mensaje)

	anillo = AnilloParry.new()
	anillo.set_anchors_preset(Control.PRESET_CENTER)
	anillo.position = Vector2(-160, -160)
	anillo.size = Vector2(320, 320)
	anillo.c_magia = c_oro
	anillo.c_corrupcion = c_corrupcion
	anillo.c_texto = c_texto
	anillo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(anillo)

	dilema = Control.new()
	dilema.size = tam_panel_dilema
	dilema.set_anchors_preset(Control.PRESET_CENTER)
	dilema.position = -tam_panel_dilema / 2.0
	raiz.add_child(dilema)

	var caja_oscura := Panel.new()
	var sbd := StyleBoxFlat.new()
	sbd.bg_color = Color("#090C16", 0.94)
	sbd.border_color = c_oro
	sbd.set_border_width_all(0)
	sbd.set_corner_radius_all(6)
	sbd.shadow_color = Color(0, 0, 0, 0.75)
	sbd.shadow_size = 18
	caja_oscura.add_theme_stylebox_override("panel", sbd)
	caja_oscura.set_anchors_preset(Control.PRESET_FULL_RECT)
	caja_oscura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dilema.add_child(caja_oscura)

	if usar_tex_panel_dilema and tex_panel_dilema != null:
		var marco_d := TextureRect.new()
		marco_d.texture = tex_panel_dilema
		marco_d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		marco_d.stretch_mode = TextureRect.STRETCH_SCALE
		marco_d.size = tam_panel_dilema
		marco_d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if quitar_fondo_negro_dilema:
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			marco_d.material = mat
		dilema.add_child(marco_d)

	var vd := VBoxContainer.new()
	vd.position = Vector2(36, 26)
	vd.size = tam_panel_dilema - Vector2(72, 52)
	vd.alignment = BoxContainer.ALIGNMENT_CENTER
	vd.add_theme_constant_override("separation", 18)
	dilema.add_child(vd)

	lbl_dilema_titulo = _label("", 23, c_oro)
	lbl_dilema_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vd.add_child(lbl_dilema_titulo)

	var div := TextureRect.new()
	div.texture = tex_divisor
	div.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	div.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	div.custom_minimum_size = Vector2(0, 26)
	div.modulate = c_oro
	vd.add_child(div)

	lbl_lore = _label("", 15, c_texto)
	lbl_lore.visible = false
	vd.add_child(lbl_lore)

	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 24)
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	vd.add_child(botones)
	botones.add_child(_boton_dilema("[E]  LEER · +1 S AL RELOJ", c_sabiduria, "leer", null, tex_boton_leer))
	lbl_quemar = _label("", 16, c_texto)
	botones.add_child(_boton_dilema("", c_error, "quemar", lbl_quemar, tex_boton_quemar))
	dilema.visible = false


func _pincelada(i: int, o: Dictionary) -> Button:
	var b := Button.new()
	b.text = "%d   %s" % [i + 1, o.texto.to_upper()]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(390, 52)
	b.size = Vector2(390, 52)
	b.focus_mode = Control.FOCUS_NONE
	if fuente_combate != null:
		b.add_theme_font_override("font", fuente_combate)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_color_override("font_outline_color", Color("#0D0717"))
	var activo: bool = o.activo
	var tinte := c_oro if activo else Color(0.35, 0.33, 0.4)
	for est in ["normal", "focus", "disabled"]:
		b.add_theme_stylebox_override(est, _estilo_boton(false, activo))
	b.add_theme_stylebox_override("hover", _estilo_boton(true, activo))
	b.add_theme_stylebox_override("pressed", _estilo_boton(true, activo))
	for c in ["font_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, c_texto if activo else Color(0.45, 0.43, 0.5))
	b.add_theme_color_override("font_hover_color", c_oro)
	b.disabled = not activo
	b.rotation = deg_to_rad(-1.5)
	b.pressed.connect(_elegir.bind(i))

	var x_base := -i * 22.0
	b.mouse_entered.connect(func():
		if activo:
			create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(b, "position:x", x_base - 18.0, 0.16)
	)
	b.mouse_exited.connect(func():
		if activo:
			create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).tween_property(b, "position:x", x_base, 0.14)
	)

	if o.has("detalle") and o.detalle != "":
		var d := _label(o.detalle, 13, c_magia if activo else tinte)
		d.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		d.position = Vector2(-165, -9)
		d.size = Vector2(150, 18)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(d)
	return b


func _estilo_boton(es_hover: bool, activo: bool) -> StyleBox:
	var tex := tex_boton_hover if (es_hover and tex_boton_hover != null) else tex_boton_normal
	if tex != null:
		var sbt := StyleBoxTexture.new()
		sbt.texture = tex
		sbt.content_margin_left = 26
		sbt.content_margin_right = 20
		if not activo:
			sbt.modulate_color = Color(0.45, 0.45, 0.45, 0.7)
		elif es_hover and tex_boton_hover == null:
			sbt.modulate_color = Color(1.25, 1.15, 0.95, 1.0)
		else:
			sbt.modulate_color = Color.WHITE
		return sbt
	var fondo := Color("#2B194D", 0.95) if es_hover else Color("#0B0E1A", 0.88)
	var borde := c_oro if (es_hover and activo) else (c_magia if activo else Color(0.35, 0.33, 0.4))
	return _trazo(fondo, borde)


func _trazo(fondo: Color, borde: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.border_width_left = 6
	s.border_width_bottom = 2
	s.corner_radius_top_right = 18
	s.corner_radius_bottom_right = 4
	s.skew = Vector2(0.26, 0)
	s.content_margin_left = 24
	s.shadow_color = Color(0, 0, 0, 0.6)
	s.shadow_size = 8
	s.shadow_offset = Vector2(4, 4)
	return s


func _boton_dilema(t: String, color: Color, op: String, etiqueta: Label, tex_propia: Texture2D) -> Button:
	var b := Button.new()
	b.custom_minimum_size = tam_boton_dilema
	b.focus_mode = Control.FOCUS_NONE
	if fuente_combate != null:
		b.add_theme_font_override("font", fuente_combate)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_color_override("font_outline_color", Color("#0D0717"))
	if tex_propia != null:
		var sbt_n := StyleBoxTexture.new()
		sbt_n.texture = tex_propia
		sbt_n.content_margin_left = 18
		sbt_n.content_margin_right = 18
		var sbt_h := sbt_n.duplicate() as StyleBoxTexture
		sbt_h.modulate_color = Color(1.25, 1.15, 0.95, 1.0)
		for est in ["normal", "focus"]:
			b.add_theme_stylebox_override(est, sbt_n)
		b.add_theme_stylebox_override("hover", sbt_h)
		b.add_theme_stylebox_override("pressed", sbt_h)
	else:
		for est in ["normal", "focus"]:
			var s := _trazo(Color(color.darkened(0.72), 0.95), color)
			s.content_margin_left = 16
			b.add_theme_stylebox_override(est, s)
		var h := _trazo(Color(color.darkened(0.52), 0.98), c_oro)
		h.content_margin_left = 16
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", h)
	b.add_theme_color_override("font_color", c_texto)
	b.add_theme_color_override("font_hover_color", c_oro)
	if etiqueta == null:
		b.text = t
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
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
	fondo.bg_color = Color(0.03, 0.03, 0.06, 0.92)
	fondo.border_color = c_oro
	fondo.set_border_width_all(1)
	fondo.skew = Vector2(0.3, 0)
	var lleno := StyleBoxFlat.new()
	lleno.bg_color = color
	lleno.skew = Vector2(0.3, 0)
	p.add_theme_stylebox_override("background", fondo)
	p.add_theme_stylebox_override("fill", lleno)
	return p


func _barra_jefe(tam: Vector2) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = tam
	
	var sb_fondo: StyleBox
	if tex_barra_enemigo_fondo != null:
		var sbt_f := StyleBoxTexture.new()
		sbt_f.texture = tex_barra_enemigo_fondo
		sbt_f.modulate_color = Color(0.25, 0.2, 0.28, 0.9)
		sb_fondo = sbt_f
	else:
		var sbf := StyleBoxFlat.new()
		sbf.bg_color = Color(0.04, 0.03, 0.07, 0.92)
		sbf.border_color = c_oro
		sbf.set_border_width_all(2)
		sbf.corner_radius_top_left = 8
		sbf.corner_radius_bottom_right = 8
		sbf.skew = Vector2(0.25, 0)
		sb_fondo = sbf

	var tex_fill := tex_barra_enemigo_relleno if tex_barra_enemigo_relleno != null else tex_barra_enemigo_fondo
	var sb_lleno: StyleBox
	if tex_fill != null:
		var sbt_r := StyleBoxTexture.new()
		sbt_r.texture = tex_fill
		sbt_r.texture_margin_left = 18
		sbt_r.texture_margin_right = 16
		sb_lleno = sbt_r
	else:
		var sbr := StyleBoxFlat.new()
		sbr.bg_color = Color("#9E1F40")
		sbr.border_width_top = 2
		sbr.border_color = Color("#E86A82")
		sbr.skew = Vector2(0.25, 0)
		sb_lleno = sbr

	p.add_theme_stylebox_override("background", sb_fondo)
	p.add_theme_stylebox_override("fill", sb_lleno)
	return p


func _label(t: String, tam: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	var ls := LabelSettings.new()
	if fuente_combate != null:
		ls.font = fuente_combate
	ls.font_size = tam
	ls.font_color = color
	ls.outline_size = 6
	ls.outline_color = Color("#120920")
	ls.shadow_size = 5
	ls.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	ls.shadow_offset = Vector2(2, 3)
	l.label_settings = ls
	return l


class AnilloParry extends Control:
	var fase := "aviso"
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
