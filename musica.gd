extends Node

@export var volumen_db := -6.0
@export var fundido := 1.5

var pistas := {
	"menu": "res://audio/musica/menu_greenpath.mp3",
	"explorar": "res://audio/musica/lobby.mp3",
	"jefe": "res://audio/musica/jefe_pure_vessel.mp3",
}
var reproductores: Array[AudioStreamPlayer] = []
var activo := 0
var actual := ""
var tw: Tween


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var r := AudioStreamPlayer.new()
		r.volume_db = -80.0
		add_child(r)
		reproductores.append(r)


func _process(_delta):
	var deseada := _pista_deseada()
	if deseada != "" and deseada != actual:
		_cambiar(deseada)


func _pista_deseada() -> String:
	var escena := get_tree().current_scene
	if escena == null:
		return ""
	if escena.scene_file_path == "res://menu.tscn" or escena.scene_file_path == "res://final.tscn":
		return "menu"
	var combate = get_tree().get_first_node_in_group("combate")
	if combate != null and combate.get("fase") != 0 and combate.get("es_jefe") == true:
		return "jefe"
	return "explorar"


func _cambiar(nombre: String):
	actual = nombre
	if tw:
		tw.kill()
	var viejo := reproductores[activo]
	activo = 1 - activo
	var nuevo := reproductores[activo]
	var pista = load(pistas[nombre])
	if pista is AudioStreamMP3:
		pista.loop = true
	nuevo.stream = pista
	nuevo.volume_db = -40.0
	nuevo.play()
	tw = create_tween().set_parallel()
	tw.tween_property(nuevo, "volume_db", volumen_db, fundido)
	tw.tween_property(viejo, "volume_db", -80.0, fundido)
	tw.chain().tween_callback(viejo.stop)
