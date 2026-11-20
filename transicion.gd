extends CanvasLayer

@export var duracion_fundido := 0.5
@export var minimo_carga := 1.4

const FRASES = [
	"Pasando de página…",
	"La tinta se reordena…",
	"Abriendo el siguiente tomo…",
	"Las estanterías cambian de lugar…",
	"Una pluma escribe tu camino…",
]
const ORO = Color(0.784, 0.631, 0.353)
const PAPEL = Color(0.91, 0.863, 0.753)

var velo: ColorRect
var caja: VBoxContainer
var libro: Control
var frase: Label
var fondo_barra: ColorRect
var relleno: ColorRect
var ocupado := false


class Libro extends Control:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var w := 70.0
		var h := 90.0
		var tapa := Color(0.3, 0.06, 0.07)
		draw_rect(Rect2(c.x - w - 8, c.y - h / 2 - 6, w * 2 + 16, h + 12), tapa)
		var papel := Color(0.91, 0.863, 0.753)
		var oro := Color(0.784, 0.631, 0.353)
		draw_rect(Rect2(c.x - w, c.y - h / 2, w, h), papel.darkened(0.08))
		draw_rect(Rect2(c.x, c.y - h / 2, w, h), papel)
		for i in 6:
			var y := c.y - h / 2 + 16 + i * 12
			draw_line(Vector2(c.x - w + 10, y), Vector2(c.x - 10, y), Color(0.35, 0.25, 0.2, 0.5), 2)
			draw_line(Vector2(c.x + 10, y), Vector2(c.x + w - 10 - (i % 3) * 8, y), Color(0.35, 0.25, 0.2, 0.5), 2)
		var fase := fmod(t * 0.9, 1.0)
		var ang := smoothstep(0.0, 1.0, fase) * PI
		var x := cos(ang) * w
		var alza := sin(ang) * 14.0
		var hoja := PackedVector2Array([
			Vector2(c.x, c.y - h / 2),
			Vector2(c.x + x, c.y - h / 2 - alza),
			Vector2(c.x + x, c.y + h / 2 - alza),
			Vector2(c.x, c.y + h / 2),
		])
		var sombra := papel.darkened(0.25 * sin(ang))
		draw_colored_polygon(hoja, sombra)
		draw_polyline(PackedVector2Array([hoja[0], hoja[1], hoja[2], hoja[3]]), oro, 1.5)
		draw_line(Vector2(c.x, c.y - h / 2), Vector2(c.x, c.y + h / 2), oro, 2.5)
		for i in 3:
			var a := clampf(sin(t * 4.0 - i * 0.7), 0.0, 1.0)
			draw_circle(Vector2(c.x - 16 + i * 16, c.y + h / 2 + 26), 4.0, Color(oro, a))


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	velo = ColorRect.new()
	velo.color = Color(0.025, 0.015, 0.035)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(velo)
	caja = VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_CENTER)
	caja.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caja.grow_vertical = Control.GROW_DIRECTION_BOTH
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 18)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.add_child(caja)
	libro = Libro.new()
	libro.custom_minimum_size = Vector2(240, 170)
	libro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(libro)
	frase = Label.new()
	frase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frase.add_theme_color_override("font_color", PAPEL)
	frase.add_theme_font_size_override("font_size", 30)
	var fuente := load("res://assets/CormorantGaramond-MediumItalic.woff2") as Font
	if fuente:
		frase.add_theme_font_override("font", fuente)
	caja.add_child(frase)
	fondo_barra = ColorRect.new()
	fondo_barra.color = Color(ORO, 0.18)
	fondo_barra.custom_minimum_size = Vector2(320, 3)
	fondo_barra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	caja.add_child(fondo_barra)
	relleno = ColorRect.new()
	relleno.color = ORO
	relleno.size = Vector2(0, 3)
	fondo_barra.add_child(relleno)
	caja.modulate.a = 0.0
	velo.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(velo, "modulate:a", 0.0, 0.8)


func cambiar(ruta: String) -> void:
	if ocupado:
		return
	ocupado = true
	ruta = _resolver(ruta)
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	frase.text = FRASES[randi() % FRASES.size()]
	_progreso(0.0)
	var tw := create_tween()
	tw.tween_property(velo, "modulate:a", 1.0, duracion_fundido)
	await tw.finished
	create_tween().tween_property(caja, "modulate:a", 1.0, 0.3)
	var inicio := Time.get_ticks_msec()
	var pedido := ResourceLoader.load_threaded_request(ruta) == OK
	var escena: PackedScene = null
	var progreso: Array = []
	while true:
		var tiempo := (Time.get_ticks_msec() - inicio) / 1000.0 / minimo_carga
		var estado := ResourceLoader.THREAD_LOAD_FAILED
		if pedido:
			estado = ResourceLoader.load_threaded_get_status(ruta, progreso)
		var real: float = progreso[0] if progreso.size() > 0 else 0.0
		if estado == ResourceLoader.THREAD_LOAD_LOADED:
			real = 1.0
		_progreso(minf(real, tiempo))
		if estado != ResourceLoader.THREAD_LOAD_IN_PROGRESS and tiempo >= 1.0:
			break
		await get_tree().process_frame
	if pedido and ResourceLoader.load_threaded_get_status(ruta) == ResourceLoader.THREAD_LOAD_LOADED:
		escena = ResourceLoader.load_threaded_get(ruta) as PackedScene
	get_tree().paused = false
	Engine.time_scale = 1.0
	if escena:
		get_tree().change_scene_to_packed(escena)
	else:
		get_tree().change_scene_to_file(ruta)
	await get_tree().process_frame
	await get_tree().process_frame
	var fuera := create_tween()
	fuera.tween_property(caja, "modulate:a", 0.0, 0.25)
	fuera.tween_property(velo, "modulate:a", 0.0, duracion_fundido)
	await fuera.finished
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ocupado = false


func _progreso(v: float) -> void:
	relleno.size = Vector2(fondo_barra.custom_minimum_size.x * clampf(v, 0.0, 1.0), 3)


func _resolver(ruta: String) -> String:
	if ruta.begins_with("uid://"):
		var id := ResourceUID.text_to_id(ruta)
		if ResourceUID.has_id(id):
			return ResourceUID.get_id_path(id)
	return ruta
