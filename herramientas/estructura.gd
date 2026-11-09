# armar_estructura.gd v4.1 — muros + ventanas + arcos de techo sin sombras (Godot 4.x)
#
# Hecho a partir de las medidas REALES de tus modelos (todos son paneles delgados,
# con el ancho en X, la altura en Y y el grosor en Z):
#   muro.glb    0.93 x 0.95 x 0.28    panel con pináculos
#   ventana.glb 0.56 x 0.95 x 0.17    nicho con vitral
#   techo.glb   0.95 x 0.94 x 0.17    UN arco gótico completo (nervio)
# Por eso cada pieza se escala por separado en ancho / alto / grosor.
#
# USO: escena zona_a abierta > este script > Archivo > Ejecutar (Ctrl+Shift+X) > Ctrl+S
# Lee el tamaño del Suelo más grande de la escena. Si "Estructura" ya existe, la rehace
# (REGENERAR) y pierdes lo que hayas movido dentro de ella.
@tool
extends EditorScript

const RUTA := "res://modelos_zona_A/"
const REGENERAR := true

const ALTO_MURO := 6.0        # altura de las paredes
const GROSOR_MURO := 0.8      # grosor de las paredes
const APERTURA := 5.0         # hueco de la salida (S1) en el muro del fondo (z mínima)

const CON_VENTANAS := true
const VENT_ALTO := 2.8        # alto de cada ventana
const VENT_Y := 3.0           # altura de su base
const VENT_GROSOR := 0.45

const CON_TECHO := true       # pon false si la cámara se ve tapada por los arcos
const ALTO_ARCO := 7.0        # cuánto sube cada arco desde lo alto del muro
const GROSOR_ARCO := 0.7

var _root: Node
var _aabb := {}


func _run() -> void:
	_root = EditorInterface.get_edited_scene_root()
	if _root == null:
		push_error("Abre primero la escena zona_a.")
		return
	var viejo := _root.get_node_or_null("Estructura")
	if viejo != null:
		if not REGENERAR:
			push_error("Ya existe 'Estructura'.")
			return
		_root.remove_child(viejo)
		viejo.free()

	for m in ["muro.glb", "ventana.glb", "techo.glb"]:
		if _medir_modelo(m).size == Vector3.ZERO:
			push_error("No pude cargar/medir %s%s" % [RUTA, m])
			return

	var est := Node3D.new()
	est.name = "Estructura"
	_add(_root, est)

	# ---------- medidas del suelo ----------
	var s := _medir_suelo()
	var xmin := s.position.x
	var xmax := s.end.x
	var zmin := s.position.z
	var zmax := s.end.z
	var y0 := s.end.y
	var W := xmax - xmin
	var L := zmax - zmin
	var xc := (xmin + xmax) / 2.0
	var zc := (zmin + zmax) / 2.0
	var g := GROSOR_MURO
	var H := ALTO_MURO
	var wi := W - 2.0 * g          # ancho interior
	print("Suelo: %.1f x %.1f m (x: %.1f..%.1f, z: %.1f..%.1f)" % [W, L, xmin, xmax, zmin, zmax])

	# ---------- módulos de muro ----------
	var mb := _medir_modelo("muro.glb")
	var mw := H * mb.size.x / mb.size.y          # ancho "natural" de un módulo a esa altura
	var n := maxi(1, roundi(L / mw))
	var seg := L / n

	var vb := _medir_modelo("ventana.glb")
	var vent_ancho := VENT_ALTO * vb.size.x / vb.size.y

	# Paredes laterales (+ una ventana por módulo)
	for lado in [-1, 1]:
		var tag := "izq" if lado < 0 else "der"
		var x: float = (xmin + g / 2.0) if lado < 0 else (xmax - g / 2.0)
		var yaw := 90.0 if lado < 0 else -90.0
		var xv: float = (xmin + g + VENT_GROSOR / 2.0 - 0.05) if lado < 0 else (xmax - g - VENT_GROSOR / 2.0 + 0.05)
		for i in n:
			var z := zmin + seg * (i + 0.5)
			_pieza(est, "Muro_%s_%d" % [tag, i], "muro.glb", Vector3(x, y0, z), yaw, seg, H, g)
			if CON_VENTANAS:
				_pieza(est, "Ventana_%s_%d" % [tag, i], "ventana.glb",
						Vector3(xv, y0 + VENT_Y, z), yaw, vent_ancho, VENT_ALTO, VENT_GROSOR)

	# Muro de entrada (z máxima), cerrado
	var nx := maxi(1, roundi(wi / mw))
	var sx := wi / nx
	for i in nx:
		_pieza(est, "Muro_entrada_%d" % i, "muro.glb",
				Vector3(xmin + g + sx * (i + 0.5), y0, zmax - g / 2.0), 180.0, sx, H, g)

	# Muro de salida (z mínima) con hueco central
	var sw := (wi - APERTURA) / 2.0
	if sw > 0.5:
		var m := maxi(1, roundi(sw / mw))
		var sm := sw / m
		for lado in [-1, 1]:
			var tag2 := "izq" if lado < 0 else "der"
			var ini: float = (xmin + g) if lado < 0 else (xc + APERTURA / 2.0)
			for i in m:
				_pieza(est, "Muro_salida_%s_%d" % [tag2, i], "muro.glb",
						Vector3(ini + sm * (i + 0.5), y0, zmin + g / 2.0), 0.0, sm, H, g)

	# ---------- colisiones invisibles ----------
	var ancho_seg := (W - APERTURA) / 2.0
	_col(est, "Col_izq", Vector3(xmin + g / 2.0, y0 + H / 2.0, zc), Vector3(g, H, L))
	_col(est, "Col_der", Vector3(xmax - g / 2.0, y0 + H / 2.0, zc), Vector3(g, H, L))
	_col(est, "Col_entrada", Vector3(xc, y0 + H / 2.0, zmax - g / 2.0), Vector3(W, H, g))
	_col(est, "Col_salida_izq", Vector3(xmin + ancho_seg / 2.0, y0 + H / 2.0, zmin + g / 2.0), Vector3(ancho_seg, H, g))
	_col(est, "Col_salida_der", Vector3(xmax - ancho_seg / 2.0, y0 + H / 2.0, zmin + g / 2.0), Vector3(ancho_seg, H, g))

	# ---------- techo: un nervio gótico sobre cada junta de muro ----------
	if CON_TECHO:
		var techo := Node3D.new()
		techo.name = "Techo"
		var fade := "res://herramientas/techo_oculta_cerca.gd"
		if ResourceLoader.exists(fade):
			techo.set_script(load(fade))
		_add(est, techo)
		for i in range(n + 1):
			var z := clampf(zmin + seg * i, zmin + GROSOR_ARCO / 2.0, zmax - GROSOR_ARCO / 2.0)
			
			# Instanciamos el arco y le apagamos las sombras
			var ab := _medir_modelo("techo.glb")
			var inst := (load(RUTA + "techo.glb") as PackedScene).instantiate() as Node3D
			var esc := Vector3(wi / ab.size.x, ALTO_ARCO / ab.size.y, GROSOR_ARCO / ab.size.z)
			var c := ab.get_center()
			inst.scale = esc
			inst.position = Vector3(-c.x * esc.x, -ab.position.y * esc.y, -c.z * esc.z)
			_apagar_sombras_glb(inst)
			
			var h := Node3D.new()
			h.name = "Arco_%d" % i
			h.position = Vector3(xc, y0 + H, z)
			h.add_child(inst)
			_add(techo, h)

	print("Estructura lista: muros %.1f m, %d módulos por lado. Guarda con Ctrl+S." % [H, n])


# Instancia un .glb escalando por separado ancho (X), alto (Y) y grosor (Z).
func _pieza(parent: Node, nombre: String, modelo: String, pos: Vector3, yaw: float,
		ancho: float, alto: float, grosor: float) -> void:
	var ab := _medir_modelo(modelo)
	var inst := (load(RUTA + modelo) as PackedScene).instantiate() as Node3D
	var esc := Vector3(ancho / ab.size.x, alto / ab.size.y, grosor / ab.size.z)
	var c := ab.get_center()
	inst.scale = esc
	inst.position = Vector3(-c.x * esc.x, -ab.position.y * esc.y, -c.z * esc.z)
	
	# Apaga las sombras para que la luz del Sol entre libremente
	_apagar_sombras_glb(inst)
	
	var h := Node3D.new()
	h.name = nombre
	h.position = pos
	h.rotation_degrees.y = yaw
	h.add_child(inst)
	_add(parent, h)


# AABB (sin escalar) de todas las mallas de un modelo, cacheado
func _medir_modelo(modelo: String) -> AABB:
	if _aabb.has(modelo):
		return _aabb[modelo]
	var res := AABB()
	if ResourceLoader.exists(RUTA + modelo):
		var ps := load(RUTA + modelo) as PackedScene
		if ps != null:
			var inst := ps.instantiate() as Node3D
			var acc: Array[AABB] = []
			_acumular(inst, Transform3D.IDENTITY, acc)
			if not acc.is_empty():
				res = acc[0]
				for i in range(1, acc.size()):
					res = res.merge(acc[i])
			inst.free()
	_aabb[modelo] = res
	return res


func _acumular(n: Node, xf: Transform3D, acc: Array[AABB]) -> void:
	if n is Node3D:
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		acc.append(xf * (n as MeshInstance3D).mesh.get_aabb())
	for c in n.get_children():
		_acumular(c, xf, acc)


# Devuelve el AABB global del Suelo más grande
func _medir_suelo() -> AABB:
	var mejor := AABB()
	var area_max := 0.0
	for n in _root.find_children("Suelo*", "Node3D", true, false):
		var cand: Array[Node] = [n]
		cand.append_array(n.get_children())
		for c in cand:
			if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
				var mi := c as MeshInstance3D
				var ab := mi.global_transform * mi.get_aabb()
				var area := ab.size.x * ab.size.z
				if area > area_max:
					area_max = area
					mejor = ab
	if area_max <= 0.0:
		push_warning("No encontré 'Suelo'; uso 20 x 40 m (x: -10..10, z: 0..40).")
		mejor = AABB(Vector3(-10, -1, 0), Vector3(20, 1, 40))
	return mejor


func _col(parent: Node, nombre: String, centro: Vector3, tam: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = nombre
	body.position = centro
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = tam
	cs.shape = bs
	body.add_child(cs)
	_add(parent, body)


func _add(parent: Node, n: Node) -> void:
	parent.add_child(n)
	_dueno(n)


func _dueno(n: Node) -> void:
	n.owner = _root
	if n.scene_file_path != "":
		return
	for c in n.get_children():
		_dueno(c)


func _apagar_sombras_glb(n: Node) -> void:
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_apagar_sombras_glb(c)
