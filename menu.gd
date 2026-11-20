extends Control

@export var primera_zona := "res://zona_a.tscn"

func _ready():
	$Botones/Jugar.pressed.connect(_jugar)
	$Botones/Salir.pressed.connect(get_tree().quit)
	$Botones/Jugar.grab_focus()

func _jugar():
	Transicion.cambiar(primera_zona)
