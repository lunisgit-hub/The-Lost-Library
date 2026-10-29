extends Node 

@export var tecla = "rodar" 
@onready var pj = get_parent() 
var usos = 0 

func _physics_process(delta):     
	if Input.is_action_just_pressed(tecla): 
		usos += 1 
		print("empieza: ", tecla, " · uso número ", usos)
