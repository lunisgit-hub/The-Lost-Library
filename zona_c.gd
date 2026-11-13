@tool
extends Node3D

@export var semilla = 18
@export var ancho_avenida = 18.0
@export var inicio_avenida = 42.0
@export var fin_avenida = -23.0
@export var centro_arena = Vector3(0, 0, -36)
@export var radio_arena = 16.0

const MADERA = Color(0.16, 0.1, 0.06)
const CORTEZA = Color(0.085, 0.05, 0.03)
const PIEDRA = Color(0.11, 0.09, 0.08)
const ORO = Color(1.0, 0.72, 0.32)
const LILA = Color("#AF98C7")
const TINTA = Color(0.035, 0.022, 0.05)
const COLORES_LIBROS = [
	Color(0.42, 0.12, 0.1), Color(0.33, 0.2, 0.1), Color(0.55, 0.38, 0.16),
	Color(0.28, 0.3, 0.16), Color(0.12, 0.24, 0.26), Color(0.62, 0.55, 0.42),
	Color(0.24, 0.14, 0.22), Color(0.48, 0.28, 0.12)
]

var rng = RandomNumberGenerator.new()
var raiz: Node3D
var madera_tf: Array[Transform3D] = []
var libros_tf: Array[Transform3D] = []
var libros_col: Array[Color] = []
var estrellas: Array[Node3D] = []
var mat_corteza: StandardMaterial3D
var jefe: Node3D
var jefe_cuerpo: Node3D
var jefe_libros: Node3D
var jefe_halo: Node3D
var mat_ojos: StandardMaterial3D
var t = 0.0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	construir()


func construir():
	rng.seed = semilla
	madera_tf.clear()
	libros_tf.clear()
	libros_col.clear()
	estrellas.clear()
	var viejo = get_node_or_null("Generado")
	if viejo != null:
		remove_child(viejo)
		viejo.queue_free()
	raiz = Node3D.new()
	raiz.name = "Generado"
	add_child(raiz)
	mat_corteza = material(CORTEZA, 0.92)
	mat_corteza.rim_enabled = true
	mat_corteza.rim = 0.35
	mat_corteza.rim_tint = 0.6
	crear_piso()
	crear_reflejo()
	crear_muros()
	crear_estanterias_avenida()
	crear_estanterias_arena()
	crear_raices()
	crear_dibujo_arena()
	crear_estrellas()
	crear_resplandor()
	crear_mesa(Vector3(6.4, 0, 24.0))
	crear_atril("C1_Atril", Vector3(-6.6, 0, 14.0), PI * 0.5)
	crear_atril("C2_Atril", Vector3(6.6, 0, -6.0), -PI * 0.5)
	crear_luces()
	crear_particulas()
	crear_jefe()
	armar_multimesh(madera_tf, [], material(MADERA, 0.75))
	var mat_libros = material(Color.WHITE, 0.8)
	mat_libros.vertex_color_use_as_albedo = true
	armar_multimesh(libros_tf, libros_col, mat_libros)


func _process(delta):
	t += delta
	for i in range(estrellas.size()):
		var e = estrellas[i]
		e.rotation.y = sin(t * 0.4 + i * 1.7) * 0.5
		e.rotation.z = sin(t * 0.7 + i) * 0.08
	if is_instance_valid(jefe_cuerpo):
		jefe_cuerpo.position.y = sin(t * 0.9) * 0.35
		jefe_cuerpo.rotation.z = sin(t * 0.6) * 0.025
	if is_instance_valid(jefe_libros):
		jefe_libros.rotate_y(delta * 0.45)
		for i in range(jefe_libros.get_child_count()):
			var l = jefe_libros.get_child(i)
			l.position.y = sin(t * 1.3 + i) * 0.5
	if is_instance_valid(jefe_halo):
		jefe_halo.rotate_z(delta * 0.25)
	if mat_ojos != null:
		mat_ojos.emission_energy_multiplier = 7.0 + sin(t * 2.6) * 2.5


func material(color, rugosidad = 0.6, metal = 0.0):
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rugosidad
	m.metallic = metal
	return m


func material_brillo(color, energia):
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energia
	return m


func material_aditivo(color, textura = null):
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	if textura != null:
		m.albedo_texture = textura
	return m


func degradado(radial, c0, c1):
	var g = Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	var tex = GradientTexture2D.new()
	tex.gradient = g
	tex.width = 128
	tex.height = 128
	if radial:
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
	else:
		tex.fill_from = Vector2(0, 0)
		tex.fill_to = Vector2(0, 1)
	return tex


func malla(mesh, mat, pos, padre = null):
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(padre if padre != null else raiz).add_child(mi)
	return mi


func cuerpo(forma, tf, padre = null):
	var sb = StaticBody3D.new()
	sb.transform = tf
	var cs = CollisionShape3D.new()
	cs.shape = forma
	sb.add_child(cs)
	(padre if padre != null else raiz).add_child(sb)
	return sb


func caja(tamano):
	var b = BoxShape3D.new()
	b.size = tamano
	return b


func basis_hacia(y):
	var x = y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z = x.cross(y).normalized()
	return Basis(x, y, z)


func z_fondo():
	return centro_arena.z - radio_arena - 6.0


func crear_piso():
	var z0 = inicio_avenida + 2.0
	var z1 = z_fondo() - 8.0
	var b = BoxMesh.new()
	b.size = Vector3(radio_arena * 2.0 + 16.0, 0.2, z0 - z1)
	var centro = Vector3(0, -0.1, (z0 + z1) / 2.0)
	malla(b, material(Color(0.05, 0.038, 0.03), 0.05, 0.4), centro)
	cuerpo(caja(b.size), Transform3D(Basis(), centro))


func crear_reflejo():
	var tex = degradado(false, Color(1, 0.78, 0.4, 1), Color(1, 0.6, 0.25, 0))
	var z0 = z_fondo() + 2.0
	var z1 = inicio_avenida - 10.0
	var capas = [[2.5, 0.5], [6.0, 0.28], [11.0, 0.14]]
	for i in range(capas.size()):
		var q = QuadMesh.new()
		q.size = Vector2(capas[i][0], z1 - z0)
		var mi = malla(q, material_aditivo(Color(1, 1, 1, capas[i][1]), tex), Vector3(0, 0.01 + i * 0.002, (z0 + z1) / 2.0))
		mi.rotation.x = -PI / 2.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func crear_muros():
	var mitad = ancho_avenida / 2.0
	var z0 = inicio_avenida
	var z1 = fin_avenida
	for lado in [-1, 1]:
		cuerpo(caja(Vector3(1.0, 8.0, z0 - z1)), Transform3D(Basis(), Vector3(lado * (mitad + 0.8), 4.0, (z0 + z1) / 2.0)))
	cuerpo(caja(Vector3(ancho_avenida + 4.0, 8.0, 1.0)), Transform3D(Basis(), Vector3(0, 4.0, z0 + 0.5)))
	var r = radio_arena + 0.8
	var n = 44
	for i in range(n):
		var a = TAU * i / n
		var pos = centro_arena + Vector3(sin(a), 0, cos(a)) * r
		if pos.z > centro_arena.z and absf(pos.x) < mitad + 1.2:
			continue
		cuerpo(caja(Vector3(TAU * r / n * 1.15, 8.0, 1.0)), Transform3D(Basis(Vector3.UP, a), pos + Vector3(0, 4.0, 0)))


func crear_estanterias_avenida():
	var mitad = ancho_avenida / 2.0
	var filas = [
		[mitad + 0.6, 5.0, 7.5, 0.04, 1.0],
		[mitad + 3.6, 8.0, 11.0, 0.08, 1.4],
		[mitad + 7.0, 12.0, 16.0, 0.12, 2.0],
	]
	for lado in [-1, 1]:
		for f in filas:
			var z = inicio_avenida - 1.5
			while z > fin_avenida + 1.0:
				var ancho = rng.randf_range(2.2, 2.8)
				var alto = rng.randf_range(f[1], f[2])
				var giro = -lado * PI / 2.0 + rng.randf_range(-0.12, 0.12)
				var orientacion = Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, rng.randf_range(0.0, f[3])) * Basis(Vector3.FORWARD, rng.randf_range(-0.05, 0.05))
				var pos = Vector3(lado * (f[0] + rng.randf_range(-0.3, 0.6)), 0, z)
				crear_estante(Transform3D(orientacion, pos), ancho, alto, f[4])
				z -= ancho + rng.randf_range(0.05, 0.6)


func crear_estanterias_arena():
	var mitad = ancho_avenida / 2.0
	for anillo in [[radio_arena + 1.6, 8.0, 13.0, 0.06, 1.3], [radio_arena + 5.5, 14.0, 20.0, 0.12, 2.2]]:
		var r = anillo[0]
		var n = int(floor(TAU * r / 2.7))
		for i in range(n):
			var a = TAU * i / n + rng.randf_range(-0.03, 0.03)
			var dir = Vector3(sin(a), 0, cos(a))
			var pos = centro_arena + dir * r
			if pos.z > centro_arena.z and absf(pos.x) < mitad + 2.0:
				continue
			if pos.z < centro_arena.z and absf(pos.x) < 6.5:
				continue
			var orientacion = Basis(Vector3.UP, a + PI) * Basis(Vector3.RIGHT, rng.randf_range(0.0, anillo[3])) * Basis(Vector3.FORWARD, rng.randf_range(-0.05, 0.05))
			crear_estante(Transform3D(orientacion, pos), rng.randf_range(2.3, 2.7), rng.randf_range(anillo[1], anillo[2]), anillo[4])


func crear_estante(tf, ancho, alto, escala_libro = 1.0):
	var fondo = 0.5
	var tabla = 0.05
	madera_tf.append(tf * Transform3D(Basis.from_scale(Vector3(ancho, alto, tabla)), Vector3(0, alto / 2.0, -fondo / 2.0)))
	for lado in [-1, 1]:
		madera_tf.append(tf * Transform3D(Basis.from_scale(Vector3(tabla * 1.5, alto, fondo)), Vector3(lado * ancho / 2.0, alto / 2.0, 0)))
	var niveles = maxi(int(alto / (0.55 * escala_libro)), 2)
	var paso = alto / niveles
	for k in range(niveles + 1):
		var y = k * paso
		madera_tf.append(tf * Transform3D(Basis.from_scale(Vector3(ancho, tabla, fondo)), Vector3(0, y, 0)))
		if k < niveles:
			llenar_repisa(tf, ancho, y + tabla / 2.0, paso, escala_libro)


func llenar_repisa(tf, ancho, y, paso, escala_libro = 1.0):
	var x = -ancho / 2.0 + 0.06
	var limite = ancho / 2.0 - 0.06
	while x < limite:
		if rng.randf() < 0.06:
			x += rng.randf_range(0.1, 0.3) * escala_libro
			continue
		var w = rng.randf_range(0.05, 0.11) * escala_libro
		if x + w > limite:
			break
		var h = paso * rng.randf_range(0.55, 0.85)
		var d = rng.randf_range(0.26, 0.36)
		var giro = 0.0
		if rng.randf() < 0.05:
			giro = rng.randf_range(0.15, 0.3)
		var b = Basis(Vector3.FORWARD, giro) * Basis.from_scale(Vector3(w, h, d))
		libros_tf.append(tf * Transform3D(b, Vector3(x + w / 2.0, y + h / 2.0, 0.02)))
		var c = COLORES_LIBROS[rng.randi() % COLORES_LIBROS.size()]
		libros_col.append(c * rng.randf_range(0.75, 1.15))
		x += w + 0.005


func armar_multimesh(tfs, colores, mat):
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colores.size() > 0
	var b = BoxMesh.new()
	b.size = Vector3.ONE
	mm.mesh = b
	mm.instance_count = tfs.size()
	for i in range(tfs.size()):
		mm.set_instance_transform(i, tfs[i])
		if mm.use_colors:
			mm.set_instance_color(i, colores[i])
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	raiz.add_child(mmi)


func crear_raiz(base, cima, grosor, con_colision = true):
	var ctrl = Vector3(base.x, cima.y * 0.78, lerpf(base.z, cima.z, 0.25))
	var segmentos = 12
	var prev = base
	for i in range(1, segmentos + 1):
		var u = float(i) / segmentos
		var p = base.lerp(ctrl, u).lerp(ctrl.lerp(cima, u), u)
		var c = CylinderMesh.new()
		c.bottom_radius = grosor * lerpf(1.0, 0.2, float(i - 1) / segmentos)
		c.top_radius = grosor * lerpf(1.0, 0.2, u)
		c.height = prev.distance_to(p) * 1.1
		c.radial_segments = 8
		c.rings = 1
		var mi = malla(c, mat_corteza, (prev + p) / 2.0)
		mi.basis = basis_hacia((p - prev).normalized())
		prev = p
	for _k in range(3):
		var a = rng.randf() * TAU
		var dir = Vector3(sin(a), 0, cos(a))
		var c = CylinderMesh.new()
		c.bottom_radius = grosor * 0.55
		c.top_radius = grosor * 0.08
		c.height = grosor * 3.2
		c.radial_segments = 6
		c.rings = 1
		var mi = malla(c, mat_corteza, base + dir * grosor * 1.2 + Vector3(0, grosor * 0.3, 0))
		mi.basis = basis_hacia((dir + Vector3(0, 0.25, 0)).normalized())
	if con_colision:
		var f = CylinderShape3D.new()
		f.radius = grosor * 1.05
		f.height = 6.0
		cuerpo(f, Transform3D(Basis(), base + Vector3(0, 3.0, 0)))


func crear_raices():
	var mitad = ancho_avenida / 2.0
	var z = inicio_avenida - 4.0
	while z > fin_avenida:
		for lado in [-1, 1]:
			var base = Vector3(lado * (mitad + rng.randf_range(1.8, 3.0)), 0, z + rng.randf_range(-2.0, 2.0))
			var cima = Vector3(lado * rng.randf_range(0.5, 4.0), rng.randf_range(20.0, 27.0), z + rng.randf_range(-5.0, 5.0))
			crear_raiz(base, cima, rng.randf_range(0.9, 1.5), false)
			var base2 = base + Vector3(lado * rng.randf_range(1.5, 3.0), 0, rng.randf_range(-3.0, 3.0))
			crear_raiz(base2, cima + Vector3(rng.randf_range(-3, 3), rng.randf_range(-4, 2), rng.randf_range(-3, 3)), rng.randf_range(0.4, 0.7), false)
		z -= rng.randf_range(9.0, 12.0)
	var n = 10
	for i in range(n):
		var a = TAU * i / n + rng.randf_range(-0.1, 0.1)
		var dir = Vector3(sin(a), 0, cos(a))
		var pos = centro_arena + dir * (radio_arena + 3.2)
		if pos.z > centro_arena.z and absf(pos.x) < mitad + 2.5:
			continue
		if pos.z < centro_arena.z and absf(pos.x) < 7.0:
			continue
		var cima = centro_arena + dir * rng.randf_range(2.0, 6.0) + Vector3(0, rng.randf_range(26.0, 32.0), 0)
		crear_raiz(pos, cima, rng.randf_range(1.3, 2.0), false)


func crear_dibujo_arena():
	var oro = material_brillo(ORO, 1.2)
	var c = centro_arena
	for r in [4.0, 8.5, 12.5, 15.4]:
		var tor = TorusMesh.new()
		tor.inner_radius = r - 0.05
		tor.outer_radius = r + 0.05
		tor.rings = 128
		tor.ring_segments = 6
		var mi = malla(tor, oro, c + Vector3(0, 0.01, 0))
		mi.scale = Vector3(1, 0.15, 1)
	for i in range(16):
		var a = TAU * i / 16.0
		var b = BoxMesh.new()
		b.size = Vector3(0.05, 0.02, 11.4)
		var mi = malla(b, oro, c + Vector3(sin(a), 0, cos(a)) * 9.7 + Vector3(0, 0.012, 0))
		mi.rotation.y = a
	for i in range(8):
		var a = TAU * i / 8.0 + PI / 8.0
		var b = BoxMesh.new()
		b.size = Vector3(0.05, 0.02, 2.0 * 8.5 * sin(PI / 8.0))
		var mi = malla(b, oro, c + Vector3(sin(a), 0, cos(a)) * 8.5 * cos(PI / 8.0) + Vector3(0, 0.014, 0))
		mi.rotation.y = a + PI / 2.0


func malla_estrella(puntas = 8, r_ext = 0.5, r_int = 0.2, grosor = 0.3):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = puntas * 2
	var pts = []
	for i in range(n):
		var a = TAU * i / n
		var r = r_ext if i % 2 == 0 else r_int
		pts.append(Vector3(sin(a) * r, cos(a) * r, 0))
	var f = Vector3(0, 0, grosor / 2.0)
	for i in range(n):
		var a = pts[i]
		var b = pts[(i + 1) % n]
		st.add_vertex(f)
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(-f)
		st.add_vertex(b)
		st.add_vertex(a)
	st.generate_normals()
	return st.commit()


func crear_estrellas():
	var forma = malla_estrella()
	var brillo = material_brillo(Color(1.0, 0.78, 0.4), 4.0)
	brillo.cull_mode = BaseMaterial3D.CULL_DISABLED
	var hilo_mat = material(Color(0.2, 0.15, 0.1), 0.8)
	var reflejo = material_aditivo(Color(1.0, 0.75, 0.35, 0.22))
	var cuerda = CylinderMesh.new()
	cuerda.top_radius = 0.012
	cuerda.bottom_radius = 0.012
	cuerda.height = 1.0
	cuerda.radial_segments = 4
	for i in range(18):
		var pos = Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(8.0, 17.0), rng.randf_range(centro_arena.z - 10.0, centro_arena.z + 22.0))
		var s = rng.randf_range(0.8, 2.2)
		var e = Node3D.new()
		e.position = pos
		raiz.add_child(e)
		var mi = malla(forma, brillo, Vector3.ZERO, e)
		mi.scale = Vector3.ONE * s
		var largo = 34.0 - pos.y
		var h = malla(cuerda, hilo_mat, Vector3(0, s * 0.5 + largo / 2.0, 0), e)
		h.scale = Vector3(1, largo, 1)
		if i < 5:
			var l = OmniLight3D.new()
			l.light_color = Color(1.0, 0.78, 0.45)
			l.light_energy = 1.4
			l.omni_range = 10.0
			e.add_child(l)
		var r = malla(forma, reflejo, Vector3(pos.x, 0.02, pos.z))
		r.rotation.x = -PI / 2.0
		r.scale = Vector3(s, s, 0.05)
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		estrellas.append(e)


func crear_resplandor():
	var z = z_fondo()
	var tex = degradado(true, Color(1, 0.85, 0.55, 1), Color(1, 0.55, 0.15, 0))
	for capa in [[Vector2(10, 18), 0.9, 9.0], [Vector2(24, 26), 0.5, 11.0], [Vector2(40, 30), 0.3, 12.0]]:
		var q = QuadMesh.new()
		q.size = capa[0]
		var mi = malla(q, material_aditivo(Color(1, 1, 1, capa[1]), tex), Vector3(0, capa[2], z))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rayo = degradado(false, Color(1, 0.8, 0.45, 0.0), Color(1, 0.75, 0.4, 0.35))
	for i in range(7):
		var q = QuadMesh.new()
		q.size = Vector2(rng.randf_range(1.0, 2.5), 26.0)
		var mi = malla(q, material_aditivo(Color(1, 1, 1, rng.randf_range(0.3, 0.6)), rayo), Vector3(rng.randf_range(-9, 9), 12.0, z + rng.randf_range(2, 10)))
		mi.rotation.z = rng.randf_range(-0.25, 0.25)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l = OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.4)
	l.light_energy = 5.0
	l.omni_range = 38.0
	l.omni_attenuation = 1.4
	l.position = Vector3(0, 6.0, z + 3.0)
	raiz.add_child(l)


func crear_mesa(pos):
	var madera = material(MADERA * 0.8, 0.45, 0.1)
	var m = Node3D.new()
	m.position = pos
	raiz.add_child(m)
	var tapa = CylinderMesh.new()
	tapa.top_radius = 0.85
	tapa.bottom_radius = 0.85
	tapa.height = 0.06
	malla(tapa, madera, Vector3(0, 0.8, 0), m)
	var pata = CylinderMesh.new()
	pata.top_radius = 0.07
	pata.bottom_radius = 0.1
	pata.height = 0.78
	malla(pata, madera, Vector3(0, 0.39, 0), m)
	var pie = CylinderMesh.new()
	pie.top_radius = 0.1
	pie.bottom_radius = 0.4
	pie.height = 0.06
	malla(pie, madera, Vector3(0, 0.03, 0), m)
	var silla = Node3D.new()
	silla.position = Vector3(0.6, 0, -1.0)
	silla.rotation.y = 0.5
	m.add_child(silla)
	var hierro = material(Color(0.06, 0.05, 0.05), 0.4, 0.7)
	var asiento = BoxMesh.new()
	asiento.size = Vector3(0.5, 0.05, 0.5)
	malla(asiento, hierro, Vector3(0, 0.47, 0), silla)
	var respaldo = BoxMesh.new()
	respaldo.size = Vector3(0.5, 0.55, 0.04)
	malla(respaldo, hierro, Vector3(0, 0.78, -0.23), silla)
	for x in [-0.22, 0.22]:
		for zz in [-0.22, 0.22]:
			var p = BoxMesh.new()
			p.size = Vector3(0.04, 0.47, 0.04)
			malla(p, hierro, Vector3(x, 0.235, zz), silla)
	var cera = material(Color(0.95, 0.88, 0.75), 0.6)
	var llama = material_brillo(Color(1.0, 0.7, 0.3), 6.0)
	for v in [[Vector3(-0.3, 0, 0.15), 0.18], [Vector3(-0.12, 0, 0.32), 0.12], [Vector3(0.05, 0, 0.1), 0.08]]:
		var vela = CylinderMesh.new()
		vela.top_radius = 0.035
		vela.bottom_radius = 0.035
		vela.height = v[1]
		malla(vela, cera, v[0] + Vector3(0, 0.83 + v[1] / 2.0, 0), m)
		var fuego = SphereMesh.new()
		fuego.radius = 0.025
		fuego.height = 0.07
		malla(fuego, llama, v[0] + Vector3(0, 0.86 + v[1], 0), m)
	var taza = CylinderMesh.new()
	taza.top_radius = 0.07
	taza.bottom_radius = 0.05
	taza.height = 0.08
	var loza = material(Color(0.9, 0.86, 0.8), 0.3)
	malla(taza, loza, Vector3(0.35, 0.87, -0.1), m)
	var plato = CylinderMesh.new()
	plato.top_radius = 0.12
	plato.bottom_radius = 0.1
	plato.height = 0.015
	malla(plato, loza, Vector3(0.35, 0.835, -0.1), m)
	var l = OmniLight3D.new()
	l.light_color = Color(1.0, 0.68, 0.35)
	l.light_energy = 1.3
	l.omni_range = 5.0
	l.position = Vector3(-0.15, 1.2, 0.2)
	m.add_child(l)
	var f = CylinderShape3D.new()
	f.radius = 0.9
	f.height = 1.0
	cuerpo(f, Transform3D(Basis(), pos + Vector3(0, 0.5, 0)))


func crear_atril(nombre, pos, giro):
	var tf = Transform3D(Basis(Vector3.UP, giro), pos)
	var sb = cuerpo(caja(Vector3(0.7, 1.2, 0.6)), tf)
	sb.name = nombre
	var cs = sb.get_child(0)
	cs.position = Vector3(0, 0.6, 0)
	var madera = material(MADERA * 1.2, 0.6)
	var poste = BoxMesh.new()
	poste.size = Vector3(0.16, 1.0, 0.16)
	malla(poste, madera, Vector3(0, 0.5, 0), sb)
	var pie = BoxMesh.new()
	pie.size = Vector3(0.6, 0.06, 0.5)
	malla(pie, madera, Vector3(0, 0.03, 0), sb)
	var tapa = BoxMesh.new()
	tapa.size = Vector3(0.75, 0.05, 0.55)
	var mi_t = malla(tapa, madera, Vector3(0, 1.05, 0), sb)
	mi_t.rotation.x = 0.35
	var hoja = BoxMesh.new()
	hoja.size = Vector3(0.3, 0.03, 0.4)
	var papel = material_brillo(Color(0.95, 0.88, 0.72), 0.3)
	for lado in [-1, 1]:
		var mi_h = malla(hoja, papel, Vector3(lado * 0.16, 1.09, 0.01), sb)
		mi_h.rotation = Vector3(0.35, 0, lado * -0.08)
	var luz = OmniLight3D.new()
	luz.name = "Luz"
	luz.light_color = Color(1.0, 0.75, 0.45)
	luz.light_energy = 1.2
	luz.omni_range = 4.0
	luz.position = Vector3(0, 1.7, 0.3)
	sb.add_child(luz)
	if not Engine.is_editor_hint():
		var lectura = Node3D.new()
		lectura.name = "Lectura"
		lectura.set_script(load("res://lectura.gd"))
		sb.add_child(lectura)


func crear_luces():
	for z in [34.0, 14.0, -6.0]:
		for lado in [-1, 1]:
			var l = OmniLight3D.new()
			l.light_color = Color(1.0, 0.66, 0.35)
			l.light_energy = 1.1
			l.omni_range = 18.0
			l.position = Vector3(lado * 6.0, 8.0, z)
			raiz.add_child(l)
	for lado in [-1, 1]:
		var l = OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.4)
		l.light_energy = 1.4
		l.omni_range = 22.0
		l.position = centro_arena + Vector3(lado * 9.0, 9.0, 4.0)
		raiz.add_child(l)


func crear_particulas():
	var z0 = inicio_avenida
	var z1 = z_fondo()
	var brasas = CPUParticles3D.new()
	brasas.amount = 420
	brasas.lifetime = 14.0
	brasas.preprocess = 14.0
	brasas.position = Vector3(0, 5.0, (z0 + z1) / 2.0)
	brasas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	brasas.emission_box_extents = Vector3(ancho_avenida * 0.7, 5.0, (z0 - z1) / 2.0)
	brasas.direction = Vector3.UP
	brasas.spread = 60.0
	brasas.gravity = Vector3(0, 0.08, 0)
	brasas.initial_velocity_min = 0.02
	brasas.initial_velocity_max = 0.18
	var s = SphereMesh.new()
	s.radius = 0.03
	s.height = 0.06
	s.radial_segments = 6
	s.rings = 3
	s.material = material_aditivo(Color(1.0, 0.62, 0.25, 0.9))
	brasas.mesh = s
	raiz.add_child(brasas)
	var hojas = CPUParticles3D.new()
	hojas.amount = 70
	hojas.lifetime = 14.0
	hojas.preprocess = 14.0
	hojas.position = brasas.position
	hojas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	hojas.emission_box_extents = brasas.emission_box_extents
	hojas.direction = Vector3.UP
	hojas.spread = 180.0
	hojas.gravity = Vector3(0, 0.03, 0)
	hojas.initial_velocity_min = 0.05
	hojas.initial_velocity_max = 0.25
	hojas.angle_min = 0.0
	hojas.angle_max = 360.0
	hojas.angular_velocity_min = -30.0
	hojas.angular_velocity_max = 30.0
	var q = QuadMesh.new()
	q.size = Vector2(0.18, 0.24)
	var mh = StandardMaterial3D.new()
	mh.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mh.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mh.cull_mode = BaseMaterial3D.CULL_DISABLED
	mh.albedo_color = Color(1.0, 0.9, 0.72)
	q.material = mh
	hojas.mesh = q
	raiz.add_child(hojas)


func crear_jefe():
	jefe = Node3D.new()
	jefe.name = "Jefe"
	jefe.position = centro_arena + Vector3(0, 0, -6.0)
	raiz.add_child(jefe)
	jefe_cuerpo = Node3D.new()
	jefe.add_child(jefe_cuerpo)
	var tela = material(TINTA, 0.85)
	var borde = material_brillo(Color(0.42, 0.16, 0.6), 1.2)
	var oro = material_brillo(ORO, 1.6)
	oro.metallic = 0.8
	oro.roughness = 0.3
	var tunica = CylinderMesh.new()
	tunica.top_radius = 0.95
	tunica.bottom_radius = 2.8
	tunica.height = 7.6
	tunica.radial_segments = 14
	malla(tunica, tela, Vector3(0, 4.3, 0), jefe_cuerpo)
	var ruedo = TorusMesh.new()
	ruedo.inner_radius = 2.72
	ruedo.outer_radius = 2.9
	ruedo.rings = 48
	malla(ruedo, borde, Vector3(0, 0.55, 0), jefe_cuerpo)
	var hombros = SphereMesh.new()
	hombros.radius = 1.0
	hombros.height = 2.0
	var mh = malla(hombros, tela, Vector3(0, 7.7, 0), jefe_cuerpo)
	mh.scale = Vector3(2.5, 0.85, 1.4)
	var capucha = SphereMesh.new()
	capucha.radius = 1.25
	capucha.height = 2.8
	malla(capucha, tela, Vector3(0, 9.0, -0.1), jefe_cuerpo)
	var punta = CylinderMesh.new()
	punta.top_radius = 0.02
	punta.bottom_radius = 0.7
	punta.height = 1.8
	var mp = malla(punta, tela, Vector3(0, 10.1, -0.9), jefe_cuerpo)
	mp.rotation.x = -0.9
	var rostro = SphereMesh.new()
	rostro.radius = 0.85
	rostro.height = 1.7
	malla(rostro, material(Color(0, 0, 0), 1.0), Vector3(0, 8.9, 0.55), jefe_cuerpo)
	mat_ojos = material_brillo(Color(1.0, 0.8, 0.35), 8.0)
	var ojo = SphereMesh.new()
	ojo.radius = 0.14
	ojo.height = 0.2
	for x in [-0.33, 0.33]:
		malla(ojo, mat_ojos, Vector3(x, 9.0, 1.33), jefe_cuerpo)
	for lado in [-1, 1]:
		var hombro = Vector3(lado * 2.1, 7.6, 0.1)
		var mano = Vector3(lado * 1.3, 5.3, 2.3)
		var brazo = CylinderMesh.new()
		brazo.top_radius = 0.42
		brazo.bottom_radius = 0.22
		brazo.height = hombro.distance_to(mano)
		var mb = malla(brazo, tela, (hombro + mano) / 2.0, jefe_cuerpo)
		mb.basis = basis_hacia((hombro - mano).normalized())
		var garra = SphereMesh.new()
		garra.radius = 0.3
		garra.height = 0.6
		malla(garra, material(Color(0.12, 0.09, 0.12), 0.5), mano, jefe_cuerpo)
	var libro = Node3D.new()
	libro.position = Vector3(0, 5.6, 2.6)
	libro.rotation.x = -0.5
	jefe_cuerpo.add_child(libro)
	var tapa = material(Color(0.3, 0.05, 0.06), 0.6)
	var hojas = material_brillo(Color(1.0, 0.9, 0.7), 1.8)
	for lado in [-1, 1]:
		var pag = BoxMesh.new()
		pag.size = Vector3(1.1, 0.12, 1.5)
		var mi = malla(pag, hojas, Vector3(lado * 0.56, 0.06, 0), libro)
		mi.rotation.z = lado * 0.18
		var cub = BoxMesh.new()
		cub.size = Vector3(1.2, 0.05, 1.6)
		var mc = malla(cub, tapa, Vector3(lado * 0.6, -0.02, 0), libro)
		mc.rotation.z = lado * 0.18
	var luz_libro = OmniLight3D.new()
	luz_libro.light_color = Color(1.0, 0.8, 0.5)
	luz_libro.light_energy = 2.0
	luz_libro.omni_range = 6.0
	luz_libro.position = Vector3(0, 0.6, 0)
	libro.add_child(luz_libro)
	jefe_halo = Node3D.new()
	jefe_halo.position = Vector3(0, 9.1, -0.9)
	jefe_cuerpo.add_child(jefe_halo)
	var aro = TorusMesh.new()
	aro.inner_radius = 2.3
	aro.outer_radius = 2.42
	aro.rings = 64
	var ma = malla(aro, oro, Vector3.ZERO, jefe_halo)
	ma.rotation.x = PI / 2.0
	var estrella = malla_estrella(8, 0.35, 0.14, 0.2)
	for i in range(12):
		var a = TAU * i / 12.0
		var me = malla(estrella, oro, Vector3(sin(a), cos(a), 0) * 2.36, jefe_halo)
		me.scale = Vector3.ONE * (1.0 if i % 3 == 0 else 0.55)
	jefe_libros = Node3D.new()
	jefe_libros.position = Vector3(0, 5.0, 0)
	jefe.add_child(jefe_libros)
	for i in range(10):
		var a = TAU * i / 10.0
		var piv = Node3D.new()
		jefe_libros.add_child(piv)
		var b = BoxMesh.new()
		b.size = Vector3(0.6, 0.8, 0.18)
		var mi = malla(b, material(COLORES_LIBROS[i % COLORES_LIBROS.size()], 0.7), Vector3(sin(a), 0, cos(a)) * 4.4, piv)
		mi.rotation = Vector3(rng.randf_range(-0.5, 0.5), a, rng.randf_range(-0.4, 0.4))
	var aura = OmniLight3D.new()
	aura.light_color = Color(0.6, 0.3, 0.85)
	aura.light_energy = 3.0
	aura.omni_range = 14.0
	aura.position = Vector3(0, 4.0, 2.5)
	jefe.add_child(aura)
	var gotas = CPUParticles3D.new()
	gotas.amount = 80
	gotas.lifetime = 2.5
	gotas.position = Vector3(0, 4.5, 0)
	gotas.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	gotas.emission_sphere_radius = 2.2
	gotas.direction = Vector3.DOWN
	gotas.spread = 15.0
	gotas.gravity = Vector3(0, -2.5, 0)
	gotas.initial_velocity_min = 0.1
	gotas.initial_velocity_max = 0.4
	var g = SphereMesh.new()
	g.radius = 0.05
	g.height = 0.12
	g.radial_segments = 6
	g.rings = 3
	g.material = material_aditivo(Color(0.55, 0.25, 0.85, 0.8))
	gotas.mesh = g
	jefe.add_child(gotas)
	var f = CylinderShape3D.new()
	f.radius = 2.8
	f.height = 10.0
	cuerpo(f, Transform3D(Basis(), Vector3(0, 5.0, 0)), jefe)
	if not Engine.is_editor_hint():
		var c = Node.new()
		c.name = "Combate"
		c.set_script(load("res://enemigo_combate.gd"))
		var pesos: Array[int] = [40, 40, 20]
		c.set("nombre", "El Último Bibliotecario")
		c.set("vida", 160)
		c.set("danio", 18)
		c.set("danio_fuerte", 32)
		c.set("pesos", pesos)
		c.set("curas", 2)
		c.set("cura", 20)
		c.set("vida_baja", 60)
		c.set("semilla", 21)
		c.set("ritmo", 0.75)
		c.set("habilidad", "llama")
		c.set("radio", 8.5)
		c.set("color_luz", ORO)
		c.set("es_jefe", true)
		c.set("lore", "Escribió cada libro de la torre para no olvidar a nadie. Cuando la tinta empezó a pudrirse, prefirió fundirse con ella antes que cerrar la biblioteca.")
		jefe.add_child(c)
