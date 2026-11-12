extends CanvasLayer

@onready var texto = $Texto
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

func mostrar(vida):
	texto.text = "Vida: " + str(vida)
	print("HUD -> ", texto.text)
	
	# Si existe BarraVida, la anima suavemente en 0.25 segundos hasta el nuevo valor
	if barra_vida != null:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(barra_vida, "value", float(vida), 0.25)
