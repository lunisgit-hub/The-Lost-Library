class_name Lectura
extends Node3D
# Punto de lectura (R0, R1...). Va como hijo de un atril o estantería.
# Mantener "interactuar" (E) cerca durante tiempo_lectura suma segundos al
# reloj de la trivia, una sola vez por atril y para toda la partida.

signal leido(segundos)

const RELOJ_BASE = 10.0      # reloj de la trivia sin lecturas (Documento de concepto)
const VERDE = Color("#93B95A")  # sabiduría: mientras se lee
const LILA = Color("#AF98C7")   # magia/acierto: al terminar

@export var tecla = "interactuar"
@export var alcance = 1.5         # m, medido en el piso (x, z)
@export var tiempo_lectura = 1.5  # s que hay que mantener la tecla
@export var segundos = 1.0        # lo que suma al reloj de la trivia
@export var altura_texto = 2.0

# static: es del script, no del nodo. Sobrevive a recargar la escena,
# así que un atril leído no vuelve a dar el bono al reiniciar el piso.
static var leidas = {}   # nombre del atril -> segundos que dio
static var bono = 0.0

var progreso = 0.0
var texto: Label3D
var pj: Node3D
var luz: OmniLight3D      # la vela del atril, si tiene: verde mientras se puede leer
var color_calido: Color
var energia_calida = 0.0
var t = 0.0
var aura: MeshInstance3D  # halo verde que brilla con el glow mientras falta leer
var mat_aura: StandardMaterial3D


# La llama la trivia: cuánto dura su reloj con las lecturas hechas.
static func reloj_trivia():
	return RELOJ_BASE + bono


func _ready():
	add_to_group("lecturas")
	texto = Label3D.new()
	texto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texto.no_depth_test = true
	texto.font_size = 48
	texto.outline_size = 12
	texto.position = Vector3(0, altura_texto, 0)
	texto.visible = false
	add_child(texto)
	for hermano in get_parent().get_children():
		if hermano is OmniLight3D:
			luz = hermano
			color_calido = luz.light_color
			energia_calida = luz.light_energy
			break
	crear_aura()


func crear_aura():
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var tex = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	mat_aura = StandardMaterial3D.new()
	mat_aura.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_aura.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_aura.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat_aura.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat_aura.albedo_texture = tex
	var quad = QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	quad.material = mat_aura
	aura = MeshInstance3D.new()
	aura.mesh = quad
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.position = Vector3(0, 1.2, 0)
	add_child(aura)


# Aura de la luz: verde que respira mientras falta leer; cálida al terminar.
func _process(delta):
	t += delta
	var pulso_aura = 0.5 + 0.5 * sin(t * 2.2)
	if ya_leida():
		aura.visible = false
	else:
		var lleno = progreso / tiempo_lectura
		mat_aura.albedo_color = VERDE * (1.6 + 1.2 * pulso_aura + 2.0 * lleno)
		aura.scale = Vector3.ONE * (0.85 + 0.15 * pulso_aura + 0.4 * lleno)
	if luz == null:
		return
	if ya_leida():
		luz.light_color = luz.light_color.lerp(color_calido, 3.0 * delta)
		luz.light_energy = lerpf(luz.light_energy, energia_calida, 3.0 * delta)
	else:
		var pulso = 0.5 + 0.5 * sin(t * 2.2)
		luz.light_color = color_calido.lerp(VERDE, 0.75 + 0.25 * pulso)
		luz.light_energy = energia_calida * (0.8 + 0.5 * pulso + 0.6 * progreso / tiempo_lectura)


func _physics_process(delta):
	if pj == null:
		pj = get_tree().get_first_node_in_group("jugador")
		if pj == null:
			return
	var cerca = distancia_a(pj) <= alcance and soy_la_mas_cercana()
	texto.visible = cerca
	if not cerca:
		progreso = 0.0
		return
	if ya_leida():
		mostrar(resultado(), LILA)
		return
	if Input.is_action_pressed(tecla):
		progreso = minf(progreso + delta, tiempo_lectura)
		if progreso >= tiempo_lectura:
			completar()
			return
		mostrar(barra(progreso / tiempo_lectura), VERDE)
	else:
		progreso = 0.0
		mostrar("Mantén E para leer", Color.WHITE)


func completar():
	leidas[clave()] = segundos
	bono += segundos
	print(clave(), " leído cuadro ", Engine.get_physics_frames(),
		" · reloj de trivia ", num(reloj_trivia()), " s")
	mostrar(resultado(), LILA)
	leido.emit(segundos)


func resultado():
	return "+" + num(leidas[clave()]) + " s · reloj " + num(reloj_trivia()) + " s"


# 11.0 -> "11", 11.5 -> "11.5"
func num(x):
	return str(int(x)) if is_equal_approx(x, round(x)) else str(snappedf(x, 0.1))


func ya_leida():
	return leidas.has(clave())


# El nombre del atril (el padre): "R0_Atril", "R1_AtrilLectura"...
func clave():
	return str(get_parent().name)


func soy_la_mas_cercana():
	for otra in get_tree().get_nodes_in_group("lecturas"):
		if otra != self and otra.distancia_a(pj) < distancia_a(pj):
			return false
	return true


func distancia_a(obj):
	var a = Vector2(obj.global_position.x, obj.global_position.z)
	var b = Vector2(global_position.x, global_position.z)
	return a.distance_to(b)


func barra(f):
	var llenos = int(round(f * 10))
	return "▮".repeat(llenos) + "▯".repeat(10 - llenos)


<<<<<<< HEAD
func mostrar(t, color):
	texto.text = t
=======
func mostrar(contenido, color):
	texto.text = contenido
>>>>>>> 415c2f486c5282aaa527cec2dc2a1ba88139ec95
	texto.modulate = color
