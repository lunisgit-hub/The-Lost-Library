extends StaticBody3D

@export var vida = 100

func recibir_golpe(danio):
	vida -= danio
	print(name, ": vida ", vida)
	if vida <= 0:
		print(name, " destruida")
		queue_free()
