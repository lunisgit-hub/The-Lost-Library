extends CanvasLayer

@onready var texto = $Texto
<<<<<<< HEAD


func _ready():
	var pj = get_tree().get_first_node_in_group("jugador")
	var salud = pj.get_node("Salud")
	salud.cambio.connect(mostrar)
	mostrar(salud.vida)

=======
@onready var barra_vida = get_node_or_null("BarraVida")

func _ready():
	var pj = get_tree().get_first_node_in_group("jugador")
	if pj == null:
		return
	var salud = pj.get_node_or_null("Salud")
	if salud != null:
		salud.cambio.connect(mostrar)
		if barra_vida != null:
			barra_vida.max_value = salud.vida
			barra_vida.value = salud.vida
		mostrar(salud.vida)
>>>>>>> 415c2f486c5282aaa527cec2dc2a1ba88139ec95

func mostrar(vida):
	texto.text = "Vida: " + str(vida)
	print("HUD -> ", texto.text)
<<<<<<< HEAD
=======
	
	# Si existe BarraVida, la anima suavemente en 0.25 segundos hasta el nuevo valor
	if barra_vida != null:
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(barra_vida, "value", float(vida), 0.25)
>>>>>>> 415c2f486c5282aaa527cec2dc2a1ba88139ec95
