class_name HudTrivia
extends CanvasLayer
# Enigma de Tinta: la pregunta que el enemigo lanza antes del turno de Velam.

signal respuesta_elegida(correcta: bool, critico: bool, danio: int)
signal cerrado

@export_file("*.json") var banco := "res://ui_trivia/preguntas_piso1.json"
@export var titulo := "Enigma de tinta · Piso 1"
@export var danio_normal := 15
@export var danio_critico := 25
@export_range(0.1, 0.9) var tramo_critico := 0.5   # fracción del reloj que da crítico
@export var espera_al_cerrar := 1.4
@export var pausar_mundo := true
@export var enemigo: Node                          # opcional: recibe jugador_fallo()

@export_group("Arte")

@export var tex_barra_fondo: Texture2D

@export var tex_barra_relleno: Texture2D
@export var fuente_trivia: Font
@export var tex_fondo: Texture2D = preload("res://ui_trivia/fondo_tinta.png")
@export var tex_marco: Texture2D = preload("res://ui_trivia/marco.png")
## Marca esto si tu imagen de marco tiene fondo negro sólido para volverlo transparente:
@export var quitar_fondo_negro_marco := true
@export var tex_sello: Texture2D = preload("res://ui_trivia/sello.png")
@export var tex_divisor: Texture2D = preload("res://ui_trivia/divisor.png")
## Opcional: arrastra aquí una imagen (ej. Hexagonal_Shape) para los 4 botones A, B, C, D:
@export var tex_boton: Texture2D

@export_group("Tamaños y Posiciones")

@export var alto_barra := 18.0
## Tamaño general de la ventana de pregunta (ancho x alto):
@export var tam_tarjeta := Vector2(780, 589)
## Agranda solo la imagen del marco (ej. 1.2, 1.2) si tu PNG tiene mucho margen negro alrededor:
@export var escala_marco_extra := Vector2(1.0, 1.0)
## Tamaño del icono/calavera de la esquina superior izquierda:
@export var tam_sello := Vector2(118, 118)
@export var pos_sello := Vector2(-34, -30)
## Altura de la línea divisora debajo de la pregunta:
@export var alto_divisor := 30.0
## Altura de cada uno de los 4 botones de respuesta:
@export var alto_boton := 58.0

@export_group("Paleta")
@export var c_noche := Color("#19213E")
@export var c_corrupcion := Color("#431C5E")
@export var c_magia := Color("#AF98C7")
@export var c_oro := Color("#D4A359")
@export var c_sabiduria := Color("#93B95A")
@export var c_papel := Color("#80602E")
@export var c_texto := Color("#E8DCC0")
@export var c_error := Color("#B0407A")

const LETRAS = ["A", "B", "C", "D"]

var preguntas: Array = []
var mazo: Array = []
var correcta := -1
var total := 10.0
var restante := 0.0
var activo := false
var pausa_previa := false

var raiz: Control
var tarjeta: Control
var lbl_pregunta: Label
var lbl_reloj: Label
var lbl_tiempo: Label
var lbl_resultado: Label
var barra: ProgressBar
var estilo_barra: StyleBox
var botones: Array[Button] = []
var destello: ColorRect


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	if fuente_trivia == null:
		fuente_trivia = _buscar_fuente_assets()
	_cargar_banco()
	_construir()
	visible = false
	get_viewport().size_changed.connect(_ajustar_escala)
	_ajustar_escala()


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
				# Engrosa la fuente (0.4 a 0.6 la vuelve Bold/SemiBold)
				fv.variation_embolden = 0.45
				# Separa un poco cada letra para darle aire estilo RPG gótico
				fv.spacing_glyph = 1
				return fv
			f = dir.get_next()
	return null


# ---------------------------------------------------------------- uso

func preguntar(p: Dictionary = {}, quitar_falsas := 0) -> void:
	if p.is_empty():
		p = _siguiente()
	if p.is_empty():
		push_warning("hud_trivia: el banco está vacío")
		return
	var orden := range(p.opciones.size())
	orden.shuffle()
	correcta = orden.find(int(p.correcta))
	lbl_pregunta.text = p.texto
	for i in botones.size():
		var b := botones[i]
		b.visible = i < orden.size()
		if b.visible:
			b.text = str(p.opciones[orden[i]])
		b.disabled = false
		_pintar(b, "normal")
	var falsas := []
	for i in orden.size():
		if i != correcta:
			falsas.append(i)
	falsas.shuffle()
	for k in mini(quitar_falsas, falsas.size() - 1):
		var b := botones[falsas[k]]
		b.disabled = true
		_pintar(b, "tachada")
	total = Lectura.reloj_trivia()
	restante = total
	var bono := total - Lectura.RELOJ_BASE
	lbl_reloj.text = "Reloj %s s" % _num(total) + ("  (+%s por leer)" % _num(bono) if bono > 0.0 else "")
	lbl_resultado.text = ""
	activo = true
	visible = true
	if pausar_mundo:
		pausa_previa = get_tree().paused
		get_tree().paused = true
	tarjeta.modulate.a = 0.0
	tarjeta.scale = Vector2.ONE * 0.92 * _escala()
	var tw := create_tween().set_parallel()
	tw.tween_property(tarjeta, "modulate:a", 1.0, 0.25)
	tw.tween_property(tarjeta, "scale", Vector2.ONE * _escala(), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if not activo:
		return
	restante = maxf(restante - delta, 0.0)
	var f := restante / total
	barra.value = f * 100.0
	var critico_aun := f > 1.0 - tramo_critico
	var col_tiempo := c_sabiduria if critico_aun else (c_magia if f > 0.25 else c_error)
	if estilo_barra is StyleBoxTexture:
		(estilo_barra as StyleBoxTexture).modulate_color = col_tiempo.lightened(0.25)
	elif estilo_barra is StyleBoxFlat:
		(estilo_barra as StyleBoxFlat).bg_color = col_tiempo
	lbl_tiempo.text = "%s s · %s" % [_num(snappedf(restante, 0.1)), "crítico si respondes ya" if critico_aun else "sin crítico"]
	if restante <= 0.0:
		_resolver(-1)


func _input(event: InputEvent) -> void:
	if not activo or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	for i in 4:
		if k == KEY_1 + i or k == KEY_KP_1 + i:
			if i < botones.size() and botones[i].visible and not botones[i].disabled:
				get_viewport().set_input_as_handled()
				_resolver(i)
			return


func _resolver(i: int) -> void:
	if not activo:
		return
	activo = false
	var usado := total - restante
	var bien := i == correcta
	var critico := bien and usado < total * tramo_critico
	var danio := danio_critico if critico else (danio_normal if bien else 0)
	for j in botones.size():
		botones[j].disabled = true
		if j == correcta:
			_pintar(botones[j], "correcta")
		elif j == i:
			_pintar(botones[j], "error")
	if critico:
		lbl_resultado.text = "¡Golpe crítico! %d de daño" % danio
		lbl_resultado.modulate = c_sabiduria
	elif bien:
		lbl_resultado.text = "Correcto · %d de daño" % danio
		lbl_resultado.modulate = c_sabiduria
	else:
		lbl_resultado.text = "Se acabó el tiempo: la tinta te alcanza" if i == -1 else "Fallaste: tu ataque se anula"
		lbl_resultado.modulate = c_error
		_manchar()
		if enemigo != null and enemigo.has_method("jugador_fallo"):
			enemigo.jugador_fallo()
	print("trivia: ", "bien" if bien else "mal", " en ", snappedf(usado, 0.01), " s de ", total, " s · crítico=", critico, " · daño=", danio)
	respuesta_elegida.emit(bien, critico, danio)
	await get_tree().create_timer(espera_al_cerrar, true, false, true).timeout
	var tw := create_tween()
	tw.tween_property(tarjeta, "modulate:a", 0.0, 0.2)
	await tw.finished
	visible = false
	if pausar_mundo:
		get_tree().paused = pausa_previa
	cerrado.emit()


# ---------------------------------------------------------------- banco

func _cargar_banco() -> void:
	var f := FileAccess.open(banco, FileAccess.READ)
	if f == null:
		push_warning("hud_trivia: no se pudo abrir " + banco)
		return
	var datos = JSON.parse_string(f.get_as_text())
	if datos is Dictionary and datos.has("preguntas"):
		preguntas = datos.preguntas


func _siguiente() -> Dictionary:
	if preguntas.is_empty():
		return {}
	if mazo.is_empty():
		mazo = preguntas.duplicate()
		mazo.shuffle()
	return mazo.pop_back()


# ---------------------------------------------------------------- interfaz

func _construir() -> void:
	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(raiz)

	var fondo := TextureRect.new()
	fondo.texture = tex_fondo
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fondo.modulate = Color(1, 1, 1, 0.9)
	raiz.add_child(fondo)
	var velo := ColorRect.new()
	velo.color = Color(0.02, 0.03, 0.07, 0.35)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(velo)

	var tam := tam_tarjeta
	tarjeta = Control.new()
	tarjeta.size = tam
	tarjeta.pivot_offset = tam / 2.0
	tarjeta.set_anchors_preset(Control.PRESET_CENTER)
	tarjeta.position = -tam / 2.0
	raiz.add_child(tarjeta)

	var hoja := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c_noche.darkened(0.45), 0.9)
	sb.set_corner_radius_all(6)
	hoja.add_theme_stylebox_override("panel", sb)
	hoja.position = Vector2(26, 34)
	hoja.size = tam - Vector2(52, 62)
	tarjeta.add_child(hoja)

	var marco := TextureRect.new()
	marco.texture = tex_marco
	marco.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	marco.stretch_mode = TextureRect.STRETCH_SCALE
	var tam_m := tam * escala_marco_extra
	marco.size = tam_m
	marco.position = (tam - tam_m) / 2.0
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if quitar_fondo_negro_marco:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		marco.material = mat
	tarjeta.add_child(marco)

	var sello := TextureRect.new()
	sello.texture = tex_sello
	sello.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sello.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sello.size = tam_sello
	sello.position = pos_sello
	sello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tarjeta.add_child(sello)

	var caja := VBoxContainer.new()
	# Subimos X de 76 a 115 (más adentro) y Y de 70 a 115 (más abajo, lejos de los picos de arriba)
	caja.position = Vector2(115, 115)
	caja.size = Vector2(tam.x - 230, tam.y - 190)
	caja.add_theme_constant_override("separation", 8)
	tarjeta.add_child(caja)

	var cab := HBoxContainer.new()
	caja.add_child(cab)
	var lbl_titulo := _label(titulo, 17, c_oro)
	lbl_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(lbl_titulo)
	lbl_reloj = _label("", 15, c_sabiduria)
	cab.add_child(lbl_reloj)

	lbl_pregunta = _label("", 26, c_texto)
	lbl_pregunta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_pregunta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_pregunta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_pregunta.custom_minimum_size = Vector2(0, 75)
	caja.add_child(lbl_pregunta)

	var div := TextureRect.new()
	div.texture = tex_divisor
	div.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	div.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	div.custom_minimum_size = Vector2(0, alto_divisor)
	div.modulate = Color(c_oro, 0.95)
	caja.add_child(div)

	barra = ProgressBar.new()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, alto_barra)
	
	var sb_fondo: StyleBox
	if tex_barra_fondo != null:
		var sbt_f := StyleBoxTexture.new()
		sbt_f.texture = tex_barra_fondo
		sbt_f.modulate_color = Color(0.25, 0.22, 0.3, 0.9) # Oscurece el fondo vacío
		sb_fondo = sbt_f
	else:
		var sbf := StyleBoxFlat.new()
		sbf.bg_color = Color(0.03, 0.04, 0.09, 0.95)
		sbf.border_color = c_oro
		sbf.set_border_width_all(1)
		sbf.set_corner_radius_all(7)
		sb_fondo = sbf

	var tex_fill := tex_barra_relleno if tex_barra_relleno != null else tex_barra_fondo
	if tex_fill != null:
		var sbt_r := StyleBoxTexture.new()
		sbt_r.texture = tex_fill
		estilo_barra = sbt_r
	else:
		var sbr := StyleBoxFlat.new()
		sbr.bg_color = c_sabiduria
		sbr.set_corner_radius_all(7)
		estilo_barra = sbr

	barra.add_theme_stylebox_override("background", sb_fondo)
	barra.add_theme_stylebox_override("fill", estilo_barra)
	caja.add_child(barra)
	lbl_tiempo = _label("", 14, c_magia)
	lbl_tiempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caja.add_child(lbl_tiempo)

	var grilla := GridContainer.new()
	grilla.columns = 2
	grilla.add_theme_constant_override("h_separation", 14)
	grilla.add_theme_constant_override("v_separation", 12)
	caja.add_child(grilla)
	for i in 4:
		var b := _boton(i)
		grilla.add_child(b)
		botones.append(b)

	lbl_resultado = _label("", 21, c_texto)
	lbl_resultado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(lbl_resultado)

	destello = ColorRect.new()
	destello.color = Color(c_corrupcion, 0.0)
	destello.set_anchors_preset(Control.PRESET_FULL_RECT)
	destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(destello)


func _boton(i: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, alto_boton)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	if fuente_trivia != null:
		b.add_theme_font_override("font", fuente_trivia)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_color_override("font_outline_color", Color("#0D0717"))
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_resolver.bind(i))

	# Insignia redonda con la letra limpia (sin sombra ni borde grueso)
	var ins := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = c_oro
	sb.set_corner_radius_all(16)
	ins.add_theme_stylebox_override("panel", sb)
	ins.size = Vector2(32, 32)
	ins.position = Vector2(18, (alto_boton - 32.0) / 2.0)
	ins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ins.name = "Insignia"

	var l := Label.new()
	l.text = LETRAS[i]
	var ls := LabelSettings.new()
	if fuente_trivia != null:
		ls.font = fuente_trivia
	ls.font_size = 17
	ls.font_color = Color("#160D24")
	ls.outline_size = 0
	ls.shadow_size = 0
	l.label_settings = ls
	l.size = ins.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ins.add_child(l)
	b.add_child(ins)
	return b


func _pintar(b: Button, estado: String) -> void:
	var fondo := Color("#1E1630")
	var borde := c_oro
	var insignia := c_oro
	match estado:
		"correcta":
			fondo = c_sabiduria.darkened(0.6)
			borde = c_sabiduria
			insignia = c_sabiduria
		"error":
			fondo = c_error.darkened(0.6)
			borde = c_error
			insignia = c_error
		"tachada":
			fondo = Color(0.08, 0.07, 0.1)
			borde = Color(0.25, 0.22, 0.3)
			insignia = Color(0.3, 0.27, 0.35)
	var color_letra := c_texto if estado != "tachada" else Color(0.4, 0.37, 0.45)
	for nombre in ["normal", "disabled", "focus"]:
		b.add_theme_stylebox_override(nombre, _caja_boton(fondo, borde, false, estado))
	b.add_theme_stylebox_override("hover", _caja_boton(fondo.lightened(0.12), c_magia, true, estado))
	b.add_theme_stylebox_override("pressed", _caja_boton(fondo.lightened(0.18), c_magia, true, estado))
	for nombre in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(nombre, color_letra)
	var ins: Panel = b.get_node("Insignia")
	(ins.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = insignia


func _caja_boton(fondo: Color, borde: Color, es_hover: bool, estado: String) -> StyleBox:
	if tex_boton != null:
		var sbt := StyleBoxTexture.new()
		sbt.texture = tex_boton
		sbt.content_margin_left = 64
		sbt.content_margin_right = 18
		if estado == "correcta":
			sbt.modulate_color = Color(0.6, 1.3, 0.6)
		elif estado == "error":
			sbt.modulate_color = Color(1.3, 0.5, 0.6)
		elif estado == "tachada":
			sbt.modulate_color = Color(0.4, 0.4, 0.4, 0.6)
		elif es_hover:
			sbt.modulate_color = Color(1.2, 1.15, 0.95)
		return sbt
	var s := StyleBoxFlat.new()
	s.bg_color = Color(fondo, 0.92)
	s.border_color = borde
	s.set_border_width_all(2)
	s.set_corner_radius_all(29)
	s.content_margin_left = 58
	s.content_margin_right = 14
	return s


func _label(t: String, tam: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	var ls := LabelSettings.new()
	if fuente_trivia != null:
		ls.font = fuente_trivia
	ls.font_size = tam
	ls.font_color = color
	
	# Contorno grueso en tono púrpura/dorado muy oscuro (se nota sobre el fondo negro)
	ls.outline_size = 7
	ls.outline_color = Color("#180D29")
	
	# Sombra desplazada para dar efecto de profundidad / relieve
	ls.shadow_size = 6
	ls.shadow_color = Color(0.0, 0.0, 0.0, 0.9)
	ls.shadow_offset = Vector2(3, 4)
	
	l.label_settings = ls
	return l

func _manchar() -> void:
	destello.color.a = 0.55
	create_tween().tween_property(destello, "color:a", 0.0, 0.6)


func _escala() -> float:
	var v := get_viewport().get_visible_rect().size
	return minf(1.0, minf(v.x / (tam_tarjeta.x + 80.0), v.y / (tam_tarjeta.y + 70.0)))


func _ajustar_escala() -> void:
	if tarjeta:
		tarjeta.scale = Vector2.ONE * _escala()


func _num(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, roundf(x)) else str(snappedf(x, 0.1))
