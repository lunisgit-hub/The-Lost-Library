extends OmniLight3D

@export var velocidad: float = 0.2 # Velocidad del cambio de color (más alto = más rápido)
@export var saturacion: float = 1.0 # 1.0 es color puro, 0.0 es blanco
@export var brillo: float = 1.0     # 1.0 es brillo normal, 0.5 es más oscuro
@export var energia_base: float = 2.0 # Energía (intensidad) de la luz

var tiempo: float = 0.0

func _ready() -> void:
	# Guardamos la energía original si no se ha definido
	if light_energy > 0:
		energia_base = light_energy
	light_energy = energia_base

func _process(delta: float) -> void:
	tiempo += delta * velocidad
	# Usamos el tiempo para calcular un tono (hue) que va de 0 a 1
	var tono = fmod(tiempo, 1.0)
	# Convertimos el tono a un color RGB
	light_color = Color.from_hsv(tono, saturacion, brillo)
	
	# Opcional: hacer que la luz "respire" un poco en intensidad
	# light_energy = energia_base * (0.9 + 0.1 * sin(tiempo * 10.0))
