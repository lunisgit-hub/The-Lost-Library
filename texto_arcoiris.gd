extends Label3D

@export_range(1.0, 30.0, 0.5) var segundos_por_ciclo: float = 8.0
@export_range(0.0, 1.0) var saturacion: float = 1.0
@export_range(0.0, 1.0) var brillo: float = 1.0

var tiempo: float = 0.0

func _process(delta: float) -> void:
	tiempo += delta
	# Calculamos el progreso del ciclo (0.0 a 1.0)
	var progreso = fmod(tiempo / segundos_por_ciclo, 1.0)
	
	# Asignamos el color al Label3D
	modulate = Color.from_hsv(progreso, saturacion, brillo)
