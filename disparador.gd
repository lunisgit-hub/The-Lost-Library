extends Area3D

signal evento(posicion: Vector3)

@export var tecla: Key = KEY_T
@export var que_representa: String = "fallar enigma"

@onready var audio_victoria: AudioStreamPlayer = $AudioStreamPlayer if has_node("AudioStreamPlayer") else null

var antes := false

func _enter_tree() -> void:
	add_to_group("disparadores")

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	var ahora := Input.is_key_pressed(tecla)
	if ahora and not antes:
		evento.emit(global_position)
	antes = ahora

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		print("¡El jugador llegó a la puerta! ¡Victoria!")
		
		# Reproducir el sonido de victoria
		if audio_victoria and not audio_victoria.playing:
			audio_victoria.play()
			
		# enemigo deja de perseguir
		var enemigos = get_tree().get_nodes_in_group("enemigos") 
		for enemigo in enemigos:
			if enemigo.has_method("detener_persecucion"):
				enemigo.detener_persecucion()
			elif "estado_actual" in enemigo:
				# cambiar estado enemigo
				enemigo.estado_actual = 0 # Asumiendo que 0 es PATRULLAR o IDLE
