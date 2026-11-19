extends CanvasLayer
# Barra de vida de Velam. Al recibir daño: la barra roja baja al instante,
# queda un "rastro" claro que se vacía un momento después (como en Expedition 33),
# la barra destella, el HUD tiembla y el número salta. Con poca vida late en rojo.

@export var color_vida := Color(0.72, 0.11, 0.14)
@export var color_rastro := Color(1.0, 0.86, 0.55)
@export var color_cura := Color(0.58, 0.85, 0.42)
@export var espera_rastro := 0.45     # segundos que el rastro se queda quieto
@export var vida_baja := 0.3          # fracción de vida a partir de la que late

@onready var texto = $Texto
@onready var barra_vida: ProgressBar = get_node_or_null("BarraVida")

var salud: Node = null
var vida_max := 1
var vida_antes := -1
var rastro: ProgressBar = null
var estilo_fill: StyleBoxFlat = null
var tw_rastro: Tween = null
var tw_latido: Tween = null
var pos_original := {}


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var pj = get_tree().get_first_node_in_group("jugador")
	if pj == null:
		return
	salud = pj.get_node_or_null("Salud")
	if salud == null:
		return
	vida_max = maxi(salud.vida, 1)
	if barra_vida != null:
		_preparar_barra()
	salud.cambio.connect(mostrar)
	mostrar(salud.vida)


func _preparar_barra():
	barra_vida.max_value = vida_max
	barra_vida.value = salud.vida
	# Rastro: otra barra igual, detrás de la roja.
	rastro = barra_vida.duplicate() as ProgressBar
	rastro.name = "RastroVida"
	var fill_r := StyleBoxFlat.new()
	fill_r.bg_color = color_rastro
	rastro.add_theme_stylebox_override("fill", fill_r)
	add_child(rastro)
	move_child(rastro, barra_vida.get_index())
	# La roja va encima con fondo transparente para que se vea el rastro.
	barra_vida.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	var f = barra_vida.get_theme_stylebox("fill")
	estilo_fill = (f.duplicate() as StyleBoxFlat) if f is StyleBoxFlat else StyleBoxFlat.new()
	estilo_fill.bg_color = color_vida
	barra_vida.add_theme_stylebox_override("fill", estilo_fill)
	for n in [barra_vida, rastro, texto]:
		pos_original[n] = n.position
	texto.pivot_offset = texto.size / 2.0


func mostrar(vida):
	vida_max = maxi(vida_max, vida)
	if salud != null and "vida_inicial" in salud and salud.vida_inicial > 0:
		vida_max = maxi(salud.vida_inicial, vida)
	texto.text = "Vida: %d / %d" % [vida, vida_max]
	print("HUD -> ", texto.text)
	if barra_vida == null:
		vida_antes = vida
		return
	barra_vida.max_value = vida_max
	rastro.max_value = vida_max
	var primera := vida_antes < 0
	var bajo: bool = not primera and vida < vida_antes
	var subio: bool = not primera and vida > vida_antes
	vida_antes = vida

	if tw_rastro != null:
		tw_rastro.kill()
	if primera:
		barra_vida.value = vida
		rastro.value = vida
	elif bajo:
		# La roja cae ya; el rastro espera y luego la alcanza.
		var tw := _tween()
		tw.tween_property(barra_vida, "value", float(vida), 0.08)
		tw_rastro = _tween()
		tw_rastro.tween_interval(espera_rastro)
		tw_rastro.tween_property(rastro, "value", float(vida), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_golpe_visual()
	elif subio:
		# Curación: el rastro (verde) sube primero y la roja lo sigue.
		(rastro.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = color_cura
		rastro.value = vida
		tw_rastro = _tween()
		tw_rastro.tween_property(barra_vida, "value", float(vida), 0.5).set_trans(Tween.TRANS_SINE)
		tw_rastro.tween_callback(func(): (rastro.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = color_rastro)
	_latido(float(vida) / vida_max <= vida_baja and vida > 0)


func _golpe_visual():
	# Destello blanco de la barra
	estilo_fill.bg_color = Color.WHITE
	var tw := _tween()
	tw.tween_property(estilo_fill, "bg_color", color_vida, 0.25)
	# Temblor
	var sacudir := _tween()
	for i in 7:
		var d := Vector2(randf_range(-6, 6), randf_range(-4, 4)) * (1.0 - i / 6.0)
		var primero := true
		for n in pos_original:
			if primero:
				sacudir.tween_property(n, "position", pos_original[n] + d, 0.03)
			else:
				sacudir.parallel().tween_property(n, "position", pos_original[n] + d, 0.03)
			primero = false
	# El número salta
	texto.scale = Vector2.ONE * 1.35
	_tween().tween_property(texto, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _latido(activo: bool):
	if activo and tw_latido == null:
		tw_latido = _tween().set_loops()
		tw_latido.tween_property(barra_vida, "modulate", Color(1.6, 0.7, 0.7), 0.4)
		tw_latido.tween_property(barra_vida, "modulate", Color.WHITE, 0.4)
	elif not activo and tw_latido != null:
		tw_latido.kill()
		tw_latido = null
		barra_vida.modulate = Color.WHITE


func _tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale()
