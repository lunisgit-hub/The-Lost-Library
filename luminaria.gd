class_name Luminaria
extends Node3D
# Lámpara del nivel: va como padre del modelo (candelabro, farol, brasero...).
# Crea su propia luz y una llama brillante en cada punto de puntos_llama.
# La llama es un cuadro que siempre mira a la cámara, con emisión por encima
# de 1: el glow del WorldEnvironment la hace resplandecer sin costar otra luz.

@export var color = Color(1.0, 0.68, 0.36)
@export var energia = 1.6
@export var rango = 6.0
@export var atenuacion = 1.3
@export var sombra = false
@export var puntos_llama: Array[Vector3] = [Vector3(0, 1, 0)]
@export var tam_llama = 0.12
@export var brillo_llama = 4.0      # > 1 para que el glow la tome
@export_group("Parpadeo")
@export var amplitud = 0.25         # fracción de la energía
@export var velocidad = 5.0
@export var semilla = 1

var luz: OmniLight3D
var llamas = []
var ruido = FastNoiseLite.new()
var t = 0.0


func _ready():
	ruido.seed = semilla
	ruido.frequency = 1.0
	t = semilla * 3.7
	# El modelo no tapa su propia luz: si no, el aro de una lámpara colgante
	# proyecta una sombra gigante sobre el piso.
	for g in find_children("*", "GeometryInstance3D", true, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var centro = Vector3.ZERO
	for p in puntos_llama:
		centro += p
	centro /= maxi(puntos_llama.size(), 1)

	luz = OmniLight3D.new()
	luz.name = "Luz"
	luz.light_color = color
	luz.light_energy = energia
	luz.omni_range = rango
	luz.omni_attenuation = atenuacion
	luz.shadow_enabled = sombra
	luz.position = centro + Vector3(0, 0.15, 0)
	add_child(luz)

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = color * brillo_llama
	mat.albedo_texture = _gota()
	var quad = QuadMesh.new()
	quad.size = Vector2(tam_llama, tam_llama * 1.6)
	quad.material = mat
	for p in puntos_llama:
		var m = MeshInstance3D.new()
		m.mesh = quad
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = p + Vector3(0, tam_llama * 0.5, 0)
		add_child(m)
		llamas.append(m)


func _process(delta):
	t += delta
	var f = 1.0 + amplitud * ruido.get_noise_1d(t * velocidad)
	luz.light_energy = energia * f
	for i in llamas.size():
		var g = 1.0 + 0.35 * ruido.get_noise_1d(t * velocidad * 1.7 + i * 13.0)
		llamas[i].scale = Vector3(1.0, g, 1.0)


# Textura de gota: centro blanco que se apaga hacia el borde (hecha por código).
static var _tex_gota: Texture2D

static func _gota() -> Texture2D:
	if _tex_gota:
		return _tex_gota
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var tex = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.62)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	_tex_gota = tex
	return tex
