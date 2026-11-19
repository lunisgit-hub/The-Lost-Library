extends Node3D
## Modelo animado del personaje principal.
## principal.glb no tiene esqueleto, así que se usa la misma malla con rig que traen
## quieto.glb / caminar.glb / correr.glb / golpe.glb / muerte.glb, y aquí se juntan sus animaciones
## en un solo AnimationPlayer con nombres en español (+ alias para combate_manager.gd).

const FUENTES = {
	"quieto": "res://assets/quieto.glb",
	"caminar": "res://assets/caminar.glb",
	"correr": "res://assets/correr.glb",
	"golpe": "res://assets/golpe.glb",
	"muerte": "res://assets/muerte.glb",
	"herida": "res://assets/recibir_daño.glb",
}
const EN_BUCLE = ["caminar", "correr", "quieto"]
# Nombres que usan otros scripts (combate_manager.gd usa los del modelo viejo de Kenney)
const ALIAS = {
	"idle": "quieto",
	"walk": "caminar",
	"sprint": "correr",
	"attack-melee-right": "tajo",
	"attack-melee-left": "parry",
	"die": "muerte",
	"hit": "herida",
}

## Solo si falta quieto.glb: de qué animación se saca una pose de "quieto" de respaldo.
@export var pose_quieto_desde = "caminar"
## Segundo de esa animación que se usa como pose. -1 = automático (cuando la cadera está más alta).
@export var momento_pose_quieto = -1.0
## Cuánto baja la cadera al "respirar" estando quieto (metros). 0 = sin respiración.
@export var respiracion = 0.012

# Compartido entre escenas: las animaciones se preparan una sola vez.
static var _cache: Dictionary = {}

var anim: AnimationPlayer = null


func _ready():
	for nodo in find_children("*", "AnimationPlayer", true, false):
		anim = nodo as AnimationPlayer
		break
	if anim == null:
		push_warning("Heroe: no encontré AnimationPlayer en el modelo")
		return
	var lib := AnimationLibrary.new()
	for nombre in FUENTES:
		var a := _cargar(nombre)
		if a != null:
			lib.add_animation(nombre, a)
	if not lib.has_animation("quieto") and lib.has_animation(pose_quieto_desde):
		lib.add_animation("quieto", _pose_quieta(lib.get_animation(pose_quieto_desde)))
	# Trozos cortos del combo de golpe.glb para el combate por turnos
	if lib.has_animation("golpe"):
		lib.add_animation("tajo", _recortar(lib.get_animation("golpe"), 0.0, 1.1))
		lib.add_animation("parry", _recortar(lib.get_animation("golpe"), 0.25, 0.85))
	for alias in ALIAS:
		if lib.has_animation(ALIAS[alias]):
			lib.add_animation(alias, lib.get_animation(ALIAS[alias]))
	for vieja in anim.get_animation_library_list():
		anim.remove_animation_library(vieja)
	anim.add_animation_library("", lib)
	if anim.has_animation("quieto"):
		anim.play("quieto")


func _cargar(nombre: String) -> Animation:
	if _cache.has(nombre):
		return _cache[nombre]
	var escena := load(FUENTES[nombre]) as PackedScene
	if escena == null:
		push_warning("Heroe: no se pudo cargar " + FUENTES[nombre])
		return null
	var temp := escena.instantiate()
	var origen: Animation = null
	for nodo in temp.find_children("*", "AnimationPlayer", true, false):
		var ap := nodo as AnimationPlayer
		for n in ap.get_animation_list():
			if n != "RESET":
				origen = ap.get_animation(n).duplicate(true)
				break
		if origen != null:
			break
	temp.free()
	if origen == null:
		push_warning("Heroe: " + FUENTES[nombre] + " no tiene animación")
		return null
	_quitar_desplazamiento(origen)
	origen.loop_mode = Animation.LOOP_LINEAR if nombre in EN_BUCLE else Animation.LOOP_NONE
	_cache[nombre] = origen
	return origen


func _pista_cadera(a: Animation) -> int:
	for t in a.get_track_count():
		if a.track_get_type(t) == Animation.TYPE_POSITION_3D and str(a.track_get_path(t)).ends_with("Hips"):
			return t
	return -1


# Las animaciones de Meshy/Mixamo avanzan la cadera (caminar 1.4 m, golpe 1.7 m).
# El CharacterBody3D ya se mueve solo, así que se deja la cadera en su sitio (X/Z).
func _quitar_desplazamiento(a: Animation):
	var t := _pista_cadera(a)
	if t < 0 or a.track_get_key_count(t) == 0:
		return
	var base: Vector3 = a.track_get_key_value(t, 0)
	for k in a.track_get_key_count(t):
		var v: Vector3 = a.track_get_key_value(t, k)
		v.x = base.x
		v.z = base.z
		a.track_set_key_value(t, k, v)


# Crea una animación "quieto" congelando una pose de otra animación,
# con una respiración suave de la cadera.
func _pose_quieta(src: Animation) -> Animation:
	var momento: float = momento_pose_quieto
	var cadera := _pista_cadera(src)
	if momento < 0.0:
		momento = 0.0
		if cadera >= 0:
			var y_max := -INF
			for k in src.track_get_key_count(cadera):
				var v: Vector3 = src.track_get_key_value(cadera, k)
				if v.y > y_max:
					y_max = v.y
					momento = src.track_get_key_time(cadera, k)
	var a := Animation.new()
	a.length = 2.4
	a.loop_mode = Animation.LOOP_LINEAR
	for t in src.get_track_count():
		var tipo := src.track_get_type(t)
		var valor
		match tipo:
			Animation.TYPE_POSITION_3D:
				valor = src.position_track_interpolate(t, momento)
			Animation.TYPE_ROTATION_3D:
				valor = src.rotation_track_interpolate(t, momento)
			Animation.TYPE_SCALE_3D:
				valor = src.scale_track_interpolate(t, momento)
			_:
				continue
		var n := a.add_track(tipo)
		a.track_set_path(n, src.track_get_path(t))
		a.track_insert_key(n, 0.0, valor)
		if t == cadera and respiracion > 0.0:
			a.track_insert_key(n, a.length * 0.5, valor - Vector3(0, respiracion, 0))
			a.track_insert_key(n, a.length, valor)
	return a


# Copia solo el tramo [desde, hasta] de una animación (para sacar un tajo del combo).
func _recortar(src: Animation, desde: float, hasta: float) -> Animation:
	var a := Animation.new()
	a.length = hasta - desde
	a.loop_mode = Animation.LOOP_NONE
	for t in src.get_track_count():
		var tipo := src.track_get_type(t)
		if tipo != Animation.TYPE_POSITION_3D and tipo != Animation.TYPE_ROTATION_3D and tipo != Animation.TYPE_SCALE_3D:
			continue
		var n := a.add_track(tipo)
		a.track_set_path(n, src.track_get_path(t))
		var paso := 1.0 / 30.0
		var tiempo := 0.0
		while tiempo <= a.length + 0.0001:
			var en := desde + tiempo
			var valor
			match tipo:
				Animation.TYPE_POSITION_3D:
					valor = src.position_track_interpolate(t, en)
				Animation.TYPE_ROTATION_3D:
					valor = src.rotation_track_interpolate(t, en)
				_:
					valor = src.scale_track_interpolate(t, en)
			a.track_insert_key(n, tiempo, valor)
			tiempo += paso
	return a
