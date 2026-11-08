# armar_nivel.gd v2 — Zona A (Biblioteca) — Godot 4.x
#
# Reparte el nivel por TODO el salón: lee el tamaño del Suelo y el grosor de los muros
# y estira la cuadrícula de 8 columnas x 15 filas para que llene el interior
# (con un salón de 20 x 40 m cada celda queda de ~2.3 x 2.6 m).
#
# USO: escena zona_a abierta > este script > Archivo > Ejecutar (Ctrl+Shift+X) > Ctrl+S
# Con REGENERAR := true borra y rehace "Escenario" (pierdes lo que hayas movido dentro).
# Si ya acomodaste cosas a mano, renombra tu Escenario a otra cosa y pon REGENERAR := false...
# o simplemente copia lo que quieras conservar fuera de "Escenario" antes de ejecutar.
@tool
extends EditorScript

const RUTA := "res://modelos_zona_A/"
const REGENERAR := true

const GROSOR_MURO := 0.8     # debe ser igual al de armar_estructura.gd
const COLS := 8
const FILAS := 15

const EST_ANCHO := 2.0       # ancho aprox. de cada estantería (se ajusta para cerrar sin huecos)
const PASO := 4.0            # hueco central de las barreras de estanterías (filas 6 y 11)

# Si un modelo sale mirando hacia el lado equivocado, cambia su giro (en grados).
const GIRO_MODELO := {
	"estanteria.glb": 0.0,
	"puerta.glb": 0.0,
	"mesa.glb": 0.0,
	"libro_mesa.glb": 0.0,
	"lampara.glb": 0.0,
	"monster.glb": 0.0,
}

# Opcional: ruta de tus escenas de enemigo (vacío = usa monster.glb suelto)
const ESCENA_E1 := ""
const ESCENA_E3 := ""

var DORADO := Color("#D4A359")
var MORADO := Color("#431C5E")

var _root: Node
var _vistos := {}
var _aabb := {}

# medidas de la sala (se llenan en _medir_sala)
var _xmin := -10.0
var _xmax := 10.0
var _zmin := 0.0
var _zmax := 40.0
var _y0 := 0.0
var _xc := 0.0
var _cx := 2.3
var _cz := 2.56
var _zint_max := 39.2


func _run() -> void:
	_root = EditorInterface.get_edited_scene_root()
	if _root == null:
		push_error("Abre primero la escena del nivel.")
		return
	var viejo := _root.get_node_or_null("Escenario")
	if viejo != null:
		if not REGENERAR:
			push_error("Ya existe 'Escenario'.")
			return
		_root.remove_child(viejo)
		viejo.free()

	var esc := Node3D.new()
	esc.name = "Escenario"
	_add(_root, esc)
	var muros := _grupo(esc, "Muros")
	var props := _grupo(esc, "Props")
	var enem := _grupo(esc, "Enemigos")

	_medir_sala(esc)
	_ambiente()

	# ---------- Estanterías pegadas a las paredes laterales ----------
	var ab := _aabb_modelo("estanteria.glb")
	var esp := minf(ab.size.x, ab.size.z) * EST_ANCHO / maxf(maxf(ab.size.x, ab.size.z), 0.001)
	var xl := _xmin + GROSOR_MURO + esp / 2.0 + 0.05
	var xr := _xmax - GROSOR_MURO - esp / 2.0 - 0.05
	var z_a := _zmin + GROSOR_MURO
	var z_b := _zmax - GROSOR_MURO
	_fila_est(muros, "Est_izq", Vector3(xl, _y0, z_a), Vector3(xl, _y0, z_b), 90.0)
	_fila_est(muros, "Est_der", Vector3(xr, _y0, z_a), Vector3(xr, _y0, z_b), -90.0)

	# ---------- Barreras: fila 6 (cierre) y fila 11 (O2), con paso central ----------
	var x_ini_l := xl + esp / 2.0 + 0.05
	var x_ini_r := xr - esp / 2.0 - 0.05
	for fila in [6, 11]:
		var z := g(4, fila).z
		var tag := "cierre_f6" if fila == 6 else "O2_f11"
		_fila_est(muros, "Est_%s_izq" % tag, Vector3(x_ini_l, _y0, z), Vector3(_xc - PASO / 2.0, _y0, z), 0.0)
		_fila_est(muros, "Est_%s_der" % tag, Vector3(_xc + PASO / 2.0, _y0, z), Vector3(x_ini_r, _y0, z), 0.0)

	# ---------- Muro divisor en columna 3, filas 8 a 10 (tapa la visión de E2) ----------
	var xd := g(3, 9).x
	_fila_est(muros, "Est_divisor_c3",
			Vector3(xd, _y0, g(3, 10).z - _cz / 2.0), Vector3(xd, _y0, g(3, 8).z + _cz / 2.0), 90.0)

	# ---------- IN: entrada + personaje ----------
	_personaje()
	_prop(props, "IN_ArcoEntrada", "puerta.glb",
			Vector3(_xc, _y0, _zmax - GROSOR_MURO - 0.6), 0, {"ancho": 4.0})

	# ---------- R0: atril inicial ----------
	var r0 := _prop(props, "R0_Atril", "libro_mesa.glb", g(3, 3), 0, {"alto": 1.3}, true)
	_luz(r0, "R0_Luz", Vector3(0, 2.0, 0), DORADO, 4.0, 2.0, true)

	# ---------- A1 + E1 ----------
	_marker(props, "A1_Aviso", g(4, 4))
	_enemigo(enem, "E1_LibroDebil", g(4, 5), 0.9, ESCENA_E1, 25)

	# ---------- D1 + O1 ----------
	_marker(props, "D1_CruceDecision", g(4, 7))
	_prop(props, "O1_MesaCaida", "mesa.glb", g(3, 7), 25, {"ancho": 2.2}, true)

	# ---------- R1: atril de lectura + hilera de velas ----------
	var r1 := _prop(props, "R1_AtrilLectura", "libro_mesa.glb", g(2, 9), 45, {"alto": 1.3}, true)
	_luz(r1, "R1_Luz", Vector3(0, 2.0, 0), DORADO, 4.0, 2.0, true)
	for i in 3:
		var t := (i + 1) / 4.0   # 0.25, 0.5, 0.75 entre (3,7) y (2,9)
		_velas(props, "R1_Velas_%d" % (i + 1), g(lerpf(3.0, 2.0, t), lerpf(7.0, 9.0, t)))

	# ---------- A2 + E2 ----------
	_tinta(props, "A2_Tinta", g(4, 8))
	_enemigo(enem, "E2_LibroCorrupto", g(4, 10), 1.1, _buscar(["errante.tscn"]), 50)

	# ---------- R2: velas de respiro + sello ----------
	var r2 := Node3D.new()
	r2.name = "R2_Respiro"
	r2.position = g(5, 12)
	_add(props, r2)
	_velas(r2, "R2_Velas", Vector3.ZERO)
	_parpadeante(r2, "R2_Luz", Vector3(0, 1.2, 0))
	_marker(r2, "R2_SelloQuemar", Vector3.ZERO)

	# ---------- A3 + E3 + S1 ----------
	var z13 := g(4, 13).z
	for x in [_xc - _cx, _xc + _cx]:
		var lado := "izq" if x < _xc else "der"
		var ant := _prop(props, "A3_Antorcha_%s" % lado, "lampara.glb", Vector3(x, _y0, z13), 0, {"alto": 2.2})
		_luz(ant, "Luz", Vector3(0, 2.4, 0), MORADO, 6.0, 3.5)
	_enemigo(enem, "E3_GuardianTinta", g(4, 14), 2.2, ESCENA_E3, 50)
	_prop(props, "S1_ArcoSalida", "puerta.glb",
			Vector3(_xc, _y0, _zmin + GROSOR_MURO / 2.0), 0, {"ancho": 4.0})

	print("Nivel armado en un salón de %.0f x %.0f m. Guarda la escena con Ctrl+S." % [_xmax - _xmin, _zmax - _zmin])


# ============================================================
#  Cuadrícula: columna 1-COLS, fila 1-FILAS (fila 1 = entrada, z alta; avanza hacia -Z).
#  Cada celda se estira para llenar el interior del salón (entre los muros).
# ============================================================
func g(col: float, fila: float) -> Vector3:
	return Vector3(_xc + (col - (COLS + 1) / 2.0) * _cx, _y0, _zint_max - (fila - 0.5) * _cz)


func _medir_sala(esc: Node) -> void:
	var s := _medir_suelo()
	if s.size == Vector3.ZERO:
		push_warning("No encontré 'Suelo'; creo uno de 20 x 40 m.")
		_suelo_defecto(esc)
		s = AABB(Vector3(-10, -1, 0), Vector3(20, 1, 40))
	_xmin = s.position.x
	_xmax = s.end.x
	_zmin = s.position.z
	_zmax = s.end.z
	_y0 = s.end.y
	_xc = (_xmin + _xmax) / 2.0
	_cx = ((_xmax - _xmin) - 2.0 * GROSOR_MURO) / COLS
	_cz = ((_zmax - _zmin) - 2.0 * GROSOR_MURO) / FILAS
	_zint_max = _zmax - GROSOR_MURO
	print("Salón: %.1f x %.1f m, celda %.2f x %.2f m" % [_xmax - _xmin, _zmax - _zmin, _cx, _cz])


# AABB global del Suelo más grande de la escena (si hay varios nodos "Suelo")
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
	return mejor


func _suelo_defecto(parent: Node) -> void:
	var body := StaticBody3D.new()
	body.name = "Suelo"
	body.position = Vector3(0, -0.5, 20)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(20, 1, 40)
	bm.material = _mat(Color("#19213E"))
	mi.mesh = bm
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(20, 1, 40)
	cs.shape = bs
	body.add_child(cs)
	_add(parent, body)


# Fila de estanterías de a a b, repartidas parejo para cerrar sin huecos
func _fila_est(parent: Node, prefijo: String, a: Vector3, b: Vector3, yaw: float) -> void:
	var largo := a.distance_to(b)
	var n := maxi(1, roundi(largo / EST_ANCHO))
	var ancho := largo / n
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n)
		_prop(parent, "%s_%d" % [prefijo, i], "estanteria.glb", p, yaw, {"ancho": ancho}, true)


# ============================================================
#  Utilidades de nodos
# ============================================================
func _add(parent: Node, n: Node) -> void:
	parent.add_child(n)
	_dueno(n)


# Pone el dueño (para que se guarde en el .tscn) sin tocar el interior de las instancias
func _dueno(n: Node) -> void:
	n.owner = _root
	if n.scene_file_path != "":
		return
	for c in n.get_children():
		_dueno(c)


func _grupo(parent: Node, nombre: String) -> Node3D:
	var n := Node3D.new()
	n.name = nombre
	_add(parent, n)
	return n


func _marker(parent: Node, nombre: String, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = nombre
	m.position = pos
	_add(parent, m)


func _mat(c: Color, sin_luz := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if sin_luz:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _placeholder(nombre: String, tam: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nombre
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.position.y = tam.y / 2.0
	n.add_child(mi)
	return n


func _ambiente() -> void:
	if not _root.find_children("*", "WorldEnvironment", true, false).is_empty():
		return
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#05070F")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#2A3566")
	env.ambient_light_energy = 20
	env.fog_enabled = true
	env.fog_light_color = Color("#1A2040")
	env.fog_density = 0.02
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_add(_root, we)


# ============================================================
#  Personaje
# ============================================================
func _personaje() -> void:
	var pj := _root.get_node_or_null("Personaje") as Node3D
	if pj == null:
		var ruta := _buscar(["personaje.tscn", "Personaje.tscn", "jugador.tscn", "player.tscn"])
		if ruta != "":
			pj = (load(ruta) as PackedScene).instantiate() as Node3D
		else:
			push_warning("No encontré la escena del personaje; puse una caja como marcador.")
			pj = _placeholder("Personaje", Vector3(0.6, 1.4, 0.6))
		pj.name = "Personaje"
		_add(_root, pj)
	pj.position = g(4, 1)


# ============================================================
#  Props con modelo .glb (autoescala + base en el suelo + colisión opcional)
#  ajuste: {"alto": metros} o {"ancho": metros} (lado horizontal más largo)
#  El nodo devuelto tiene su origen en el CENTRO DE LA BASE del modelo.
# ============================================================
func _prop(parent: Node, nombre: String, modelo: String, pos: Vector3, yaw: float,
		ajuste: Dictionary, colision := false) -> Node3D:
	var holder: Node3D
	if colision:
		holder = StaticBody3D.new()
	else:
		holder = Node3D.new()
	holder.name = nombre
	holder.position = pos
	holder.rotation_degrees.y = yaw

	var tam := Vector3(2, 2, 0.6)
	var ruta := RUTA + modelo
	if not ResourceLoader.exists(ruta):
		push_warning("No encontré %s (pongo una caja en su lugar)." % ruta)
		holder.add_child(_placeholder("Placeholder", tam))
	else:
		var inst := (load(ruta) as PackedScene).instantiate() as Node3D
		inst.rotation_degrees.y = float(GIRO_MODELO.get(modelo, 0.0))
		var acc: Array[AABB] = []
		_medir(inst, Transform3D.IDENTITY, acc)
		if acc.is_empty():
			push_warning("%s no tiene mallas." % modelo)
		else:
			var total := acc[0]
			for i in range(1, acc.size()):
				total = total.merge(acc[i])
			var s := 1.0
			if ajuste.has("alto"):
				s = float(ajuste["alto"]) / maxf(total.size.y, 0.001)
			elif ajuste.has("ancho"):
				s = float(ajuste["ancho"]) / maxf(maxf(total.size.x, total.size.z), 0.001)
			inst.scale = Vector3.ONE * s
			var c := total.get_center()
			inst.position = Vector3(-c.x, -total.position.y, -c.z) * s
			tam = total.size * s
		holder.add_child(inst)
		if not _vistos.has(modelo):
			_vistos[modelo] = true
			print("%s -> %.2f x %.2f x %.2f m (X,Y,Z)" % [modelo, tam.x, tam.y, tam.z])

	if colision:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = tam
		cs.shape = bs
		cs.position.y = tam.y / 2.0
		holder.add_child(cs)

	_add(parent, holder)
	return holder


# AABB (sin escalar) de un modelo, cacheado. Zero si no existe.
func _aabb_modelo(modelo: String) -> AABB:
	if _aabb.has(modelo):
		return _aabb[modelo]
	var res := AABB()
	if ResourceLoader.exists(RUTA + modelo):
		var inst := (load(RUTA + modelo) as PackedScene).instantiate() as Node3D
		inst.rotation_degrees.y = float(GIRO_MODELO.get(modelo, 0.0))
		var acc: Array[AABB] = []
		_medir(inst, Transform3D.IDENTITY, acc)
		if not acc.is_empty():
			res = acc[0]
			for i in range(1, acc.size()):
				res = res.merge(acc[i])
		inst.free()
	_aabb[modelo] = res
	return res


# Junta el AABB de todas las mallas de un modelo
func _medir(n: Node, xf: Transform3D, acc: Array[AABB]) -> void:
	if n is Node3D:
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		acc.append(xf * (n as MeshInstance3D).mesh.get_aabb())
	for c in n.get_children():
		_medir(c, xf, acc)


# ============================================================
#  Enemigos (escena propia si existe, si no monster.glb)
# ============================================================
func _enemigo(parent: Node, nombre: String, pos: Vector3, alto: float,
		ruta_escena: String, hp: int) -> void:
	var e: Node3D
	if ruta_escena != "" and ResourceLoader.exists(ruta_escena):
		e = (load(ruta_escena) as PackedScene).instantiate() as Node3D
		e.name = nombre
		e.position = pos
		_add(parent, e)
	else:
		e = _prop(parent, nombre, "monster.glb", pos, 0, {"alto": alto})
	e.set_meta("hp", hp)


# ============================================================
#  Luces, velas y tinta
# ============================================================
func _luz(parent: Node, nombre: String, pos: Vector3, color: Color,
		rango: float, energia: float, sombra := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = nombre
	l.position = pos
	l.light_color = color
	l.omni_range = rango
	l.light_energy = energia
	l.shadow_enabled = sombra
	_add(parent, l)
	return l


func _parpadeante(parent: Node, nombre: String, pos: Vector3) -> void:
	var ruta := _buscar(["LuzParpadeante.tscn", "luz_parpadeante.tscn",
			"LuzParpadeante.gd", "luz_parpadeante.gd"])
	var luz: Node3D
	if ruta.ends_with(".tscn"):
		luz = (load(ruta) as PackedScene).instantiate() as Node3D
	else:
		var l := OmniLight3D.new()
		l.light_color = DORADO
		l.omni_range = 4.0
		l.light_energy = 2.0
		if ruta != "":
			l.set_script(load(ruta))
		else:
			push_warning("No encontré LuzParpadeante; puse una luz fija. Asígnale tu script a mano.")
		luz = l
	luz.name = nombre
	luz.position = pos
	_add(parent, luz)


# Grupito de 3 velas con una luz cálida
func _velas(parent: Node, nombre: String, pos: Vector3) -> void:
	var h := Node3D.new()
	h.name = nombre
	h.position = pos
	var datos := [
		[Vector3(0.0, 0, 0.0), 0.20],
		[Vector3(0.15, 0, 0.08), 0.14],
		[Vector3(-0.10, 0, 0.15), 0.10],
	]
	for d in datos:
		var alto: float = d[1]
		var vela := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.04
		cm.height = alto
		cm.material = _mat(Color("#E8DCC0"))
		vela.mesh = cm
		vela.position = (d[0] as Vector3) + Vector3(0, alto / 2.0, 0)
		h.add_child(vela)
		var llama := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.03
		sm.height = 0.06
		sm.material = _mat(Color("#FFB347"), true)
		llama.mesh = sm
		llama.position = (d[0] as Vector3) + Vector3(0, alto + 0.03, 0)
		h.add_child(llama)
	var l := OmniLight3D.new()
	l.name = "Luz"
	l.position = Vector3(0, 0.5, 0)
	l.light_color = Color("#FFB45A")
	l.light_energy = 0.8
	l.omni_range = 2.5
	h.add_child(l)
	_add(parent, h)


func _tinta(parent: Node, nombre: String, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nombre
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 0.9
	cm.height = 0.02
	var m := _mat(Color("#0A0A12"))
	m.roughness = 0.05
	cm.material = m
	mi.mesh = cm
	mi.position = pos + Vector3(0, 0.011, 0)
	_add(parent, mi)


# ============================================================
#  Busca un archivo por nombre en todo res:// (ignora .godot y addons)
# ============================================================
func _buscar(nombres: Array, dir := "res://") -> String:
	var d := DirAccess.open(dir)
	if d == null:
		return ""
	for f in d.get_files():
		if f in nombres:
			return dir.path_join(f)
	for sub in d.get_directories():
		if sub.begins_with(".") or sub == "addons":
			continue
		var r := _buscar(nombres, dir.path_join(sub))
		if r != "":
			return r
	return ""
