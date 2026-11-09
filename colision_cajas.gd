extends Node3D
# Da colisión de caja a modelos importados que no la traen (estanterías, el
# arco de la entrada, braseros...). Al arrancar mide la malla de cada objetivo
# y crea un StaticBody3D con una caja del mismo tamaño y giro. Si mueves o
# giras un modelo en el editor, su caja lo sigue sola la próxima vez que corras.
#
# Cada caja vive aquí (no dentro del modelo) para no heredar la escala del
# modelo: la física de Godot no acepta bien cajas con escala no uniforme.

@export var objetivos: Array[NodePath] = []
@export var hijos_de: Array[NodePath] = []   # usa cada hijo directo como objetivo
@export var margen := 0.0                    # metros que se quitan por lado (cajas más justas)
@export var alto_max := 4.0                  # recorta las cajas muy altas (no hace falta más)


func _ready():
	var lista = []
	for r in objetivos:
		var n = get_node_or_null(r)
		if n: lista.append(n)
	for r in hijos_de:
		var p = get_node_or_null(r)
		if p:
			for h in p.get_children():
				if h is Node3D: lista.append(h)
	var hechas = 0
	for n in lista:
		if crear_caja(n):
			hechas += 1
	print("colision_cajas: ", hechas, " cajas")


func crear_caja(n: Node3D) -> bool:
	# Marco del objetivo sin escala: su posición y su giro.
	var marco = Transform3D(n.global_basis.orthonormalized(), n.global_position)
	var a = null
	for v in [n] + n.find_children("*", "VisualInstance3D", true, false):
		if v is VisualInstance3D and not (v is Light3D):
			var caja = marco.affine_inverse() * v.global_transform * v.get_aabb()
			a = caja if a == null else a.merge(caja)
	if a == null or a.size.x < 0.05 or a.size.z < 0.05:
		return false
	a = a.grow(-margen)
	a.size.y = minf(a.size.y, alto_max)
	var cuerpo = StaticBody3D.new()
	cuerpo.name = "Col_" + str(n.name)
	add_child(cuerpo)
	cuerpo.global_transform = marco
	var forma = CollisionShape3D.new()
	var b = BoxShape3D.new()
	b.size = a.size
	forma.shape = b
	forma.position = a.get_center()
	cuerpo.add_child(forma)
	return true
