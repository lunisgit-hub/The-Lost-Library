class_name Disparador
extends Area3D

signal evento(posicion: Vector3)
@export var tecla: Key = KEY_T
@export var que_representa := "fallar enigma"

var antes := false

func _enter_tree() -> void:
	add_to_group("disparadores")

func _ready() -> void:
	body_entered.connect(func(_cuerpo: Node3D) -> void: evento.emit(global_position))

func _physics_process(_delta: float) -> void:
	var ahora := Input.is_key_pressed(tecla)
	if ahora and not antes:
		evento.emit(global_position)
	antes = ahora
