extends Node
# Escena de prueba del HUD de trivia (F6). Lanza preguntas una tras otra.
# Para probar el bono de lectura: cambia "bonos_de_prueba" en el Inspector.

@export var bonos_de_prueba := 0.0

@onready var hud: HudTrivia = $HudTrivia


func _ready():
	Lectura.bono = bonos_de_prueba
	hud.respuesta_elegida.connect(func(bien, critico, danio): print("respuesta: bien=", bien, " crítico=", critico, " daño=", danio))
	hud.cerrado.connect(func(): get_tree().create_timer(0.6).timeout.connect(hud.preguntar))
	hud.preguntar()
