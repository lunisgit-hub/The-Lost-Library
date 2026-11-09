extends Node
# Pasa a otra capa de render todo lo que tapa la vista cenital (techo, muro de
# la entrada). La Camera3D no dibuja esa capa (su cull_mask la excluye), pero
# las luces sí: esas piezas siguen existiendo, chocando y dando sombra.

@export var objetivos: Array[NodePath] = []
@export_range(1, 20) var capa = 2   # capa 2 = "oculto a la cámara"


func _ready():
	var total = 0
	for ruta in objetivos:
		var nodo = get_node_or_null(ruta)
		if nodo == null:
			push_warning("oculto_a_camara: no existe " + str(ruta))
			continue
		for v in [nodo] + nodo.find_children("*", "VisualInstance3D", true, false):
			if v is VisualInstance3D:
				v.layers = 1 << (capa - 1)
				total += 1
	print("oculto a la cámara: ", total, " mallas en la capa ", capa)
