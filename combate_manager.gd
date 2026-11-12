class_name CombateManager
extends Node
# Combate por turnos de The Lost Library. Une las piezas del equipo sin
# cambiarlas: turno_enemigo.gd (decide al enemigo), salud.gd (los 100 HP de
# Velam), hud_trivia.gd (Enigma de Tinta) y partida.gd (metas y derrota).
#
# Fases:  EXPLORAR -> ELECCION -> (TRIVIA) -> ENEMIGO -> PARRY -> ... -> DILEMA
# Reglas acordadas (tabla de balance del equipo):
#  - Fallar la trivia NO quita HP: anula el ataque, el enemigo se acelera
#    (x0.8) y el próximo parry baja de 0.5 s a 0.25 s.
#  - Tinta: empieza en 1, máximo 6. Acierto +1, crítico +2, parry perfecto +1.
#  - Al vencer: Leer el tomo (+1 s permanente) o Quemarlo (aprendes su habilidad).

enum Fase { EXPLORAR, ELECCION, TRIVIA, ENEMIGO, PARRY, DILEMA }

const HABILIDADES = {
	"hoja": {"nombre": "Hoja cortante", "costo": 2, "detalle": "2 Tinta · 15 seguro"},
	"escudo": {"nombre": "Página escudo", "costo": 2, "detalle": "2 Tinta · parry 0.5 s"},
	"llama": {"nombre": "Llama de Alejandría", "costo": 3, "detalle": "3 Tinta · +10 y quema"},
}

@export var tinta_inicial := 1
@export var tinta_max := 6
@export var ventana_parry := 0.5
@export var ventana_fallo := 0.25
@export var aviso_min := 0.35          # el aviso del golpe nunca baja de esto
@export var danio_hoja := 15
@export var extra_llama := 10
@export var danio_quema := 10
@export var turnos_quema := 2
@export var pausa_mensaje := 0.9

# static: sobreviven a recargar la escena, como el récord de partida.gd.
static var habilidades: Array = []     # ids de HABILIDADES aprendidas quemando tomos
static var tomos := {}                 # "Tomo_E1_LibroDebil" -> "leido" / "quemado"

var fase := Fase.EXPLORAR
var pj: Node3D
var salud: Node
var trivia: HudTrivia
var hud: HudCombate
var enemigo: EnemigoCombate
var turno: Node
var vida_max_enemigo := 1

var tinta := 0
var fallo_trivia := false
var escudo := false
var quema := 0
var analizar := 0
var defendiendo := false
var parry_presionado := false
var parry_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("combate")
	pj = get_tree().get_first_node_in_group("jugador")
	if pj:
		salud = pj.get_node_or_null("Salud")
	trivia = get_node_or_null("HudTrivia")
	hud = get_node_or_null("HudCombate")
	if trivia:
		trivia.pausar_mundo = false        # el combate ya pausa el mundo


func _physics_process(_d: float) -> void:
	if fase != Fase.EXPLORAR or pj == null or get_tree().paused:
		return
	for e in get_tree().get_nodes_in_group("enemigo_combate"):
		if e.puede_iniciar(pj):
			iniciar(e)
			return


func _input(event: InputEvent) -> void:
	if fase != Fase.PARRY:
		return
	var espacio: bool = event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE
	var clic: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	if (espacio or clic) and not parry_presionado:
		parry_presionado = true
		parry_ms = Time.get_ticks_msec()     # la hora exacta de la tecla, no la del cuadro
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------- inicio y fin

func iniciar(e: EnemigoCombate) -> void:
	enemigo = e
	turno = e.turno
	vida_max_enemigo = maxi(turno.vida, 1)
	tinta = tinta_inicial
	fallo_trivia = false
	escudo = false
	quema = 0
	analizar = 0
	defendiendo = false
	trivia.enemigo = turno
	get_tree().paused = true
	enemigo.en_combate(true)
	hud.abrir(e.nombre)
	_refrescar()
	print("combate: empieza contra ", e.nombre, " (", turno.vida, " HP)")
	hud.mensaje("¡%s te cierra el paso!" % e.nombre, hud.c_magia)
	await _esperar(pausa_mensaje)
	_bucle()


func _bucle() -> void:
	while true:
		var accion: String = await _eleccion()
		if accion == "huir":
			await _huir()
			return
		await _accion_jugador(accion)
		if turno.vida <= 0:
			await _dilema()
			return
		await _turno_enemigo()
		if salud and salud.vida <= 0:
			await _velam_cayo()
			return
		if turno.vida <= 0:
			await _dilema()
			return


func _cerrar() -> void:
	fase = Fase.EXPLORAR
	enemigo.en_combate(false)
	await hud.cerrar()
	var partida := get_tree().get_first_node_in_group("partida")
	# Si la partida terminó (ganó o perdió), ella maneja la pausa y el reinicio.
	if partida == null or partida.estado == partida.Estado.JUGANDO:
		get_tree().paused = false


# ------------------------------------------------------------- turno de Velam

func _eleccion() -> String:
	fase = Fase.ELECCION
	var ops := [
		{"id": "atacar", "texto": "Atacar", "detalle": "Enigma de tinta", "activo": true},
		{"id": "habilidades", "texto": "Habilidades", "detalle": "%d aprendidas" % habilidades.size(), "activo": not habilidades.is_empty()},
		{"id": "analizar", "texto": "Analizar", "detalle": "1 Tinta · −1 opción", "activo": tinta >= 1},
		{"id": "huir", "texto": "Huir", "detalle": "no si está cargando" if turno.cargado else "", "activo": not turno.cargado},
	]
	hud.mostrar_menu(ops)
	var id: String = await hud.accion_elegida
	if id != "habilidades":
		return id
	var sub := []
	for h in habilidades:
		var datos: Dictionary = HABILIDADES[h]
		sub.append({"id": h, "texto": datos.nombre, "detalle": datos.detalle, "activo": tinta >= datos.costo})
	sub.append({"id": "volver", "texto": "Volver", "detalle": "Esc", "activo": true})
	hud.mostrar_menu(sub)
	id = await hud.accion_elegida
	if id == "volver":
		return await _eleccion()
	return id


func _accion_jugador(id: String) -> void:
	hud.ocultar_menu()
	match id:
		"atacar":
			await _con_trivia(0, false)
		"llama":
			_gastar("llama")
			await _con_trivia(extra_llama, true)
		"hoja":
			_gastar("hoja")
			hud.mensaje("Hoja cortante", hud.c_papel.lightened(0.4))
			_danar(danio_hoja)
			await _esperar(pausa_mensaje)
		"escudo":
			_gastar("escudo")
			escudo = true
			hud.mensaje("Página escudo: tu próximo parry tendrá 0.5 s", hud.c_sabiduria)
			_refrescar()
			await _esperar(pausa_mensaje)
		"analizar":
			tinta -= 1
			analizar = 1
			hud.mensaje("Lees el tomo enemigo: la próxima pregunta tendrá una opción menos", hud.c_magia)
			_refrescar()
			await _esperar(pausa_mensaje * 1.4)
	defendiendo = false


func _con_trivia(extra: int, es_llama: bool) -> void:
	fase = Fase.TRIVIA
	trivia.preguntar({}, analizar)
	analizar = 0
	var r: Array = await trivia.respuesta_elegida
	await trivia.cerrado
	var bien: bool = r[0]
	var critico: bool = r[1]
	if bien:
		tinta = mini(tinta + (2 if critico else 1), tinta_max)
		_danar(r[2] + extra)
		if es_llama:
			quema = turnos_quema
		hud.mensaje(("¡Crítico! " if critico else "") + "+%d Tinta" % (2 if critico else 1), hud.c_sabiduria)
	else:
		# hud_trivia ya avisó a turno.jugador_fallo(): el enemigo se aceleró.
		fallo_trivia = true
		hud.mensaje("Tu ataque se anula: el próximo parry será de %s s" % ventana_fallo, hud.c_error)
	_refrescar()
	await _esperar(pausa_mensaje)


func _gastar(h: String) -> void:
	tinta -= HABILIDADES[h].costo
	_refrescar()


func _danar(n: int) -> void:
	if defendiendo:
		n = int(n / 2.0)
	turno.recibir_golpe(n)
	turno.vida = maxi(turno.vida, 0)
	_refrescar()


# ------------------------------------------------------------- turno enemigo

func _turno_enemigo() -> void:
	fase = Fase.ENEMIGO
	if quema > 0:
		quema -= 1
		hud.mensaje("La llama quema el tomo: −%d" % danio_quema, hud.c_papel.lightened(0.4))
		_danar(danio_quema)
		await _esperar(pausa_mensaje)
		if turno.vida <= 0:
			return
	var accion: int = turno.jugar_turno()
	var A = turno.Accion
	match accion:
		A.ATACAR:
			await _parry(enemigo.danio, "%s ataca" % enemigo.nombre)
		A.GOLPE_FUERTE:
			enemigo.cargando(false)
			await _parry(enemigo.danio_fuerte, "¡Golpe fuerte!")
		A.CARGAR:
			enemigo.cargando(true)
			hud.mensaje("%s carga tinta… su próximo golpe será fuerte" % enemigo.nombre, hud.c_magia)
			await _esperar(pausa_mensaje * 1.3)
		A.DEFENDER:
			defendiendo = true
			hud.mensaje("%s se cubre: tu próximo daño se reduce a la mitad" % enemigo.nombre, hud.c_magia)
			await _esperar(pausa_mensaje * 1.3)
		A.CURARSE:
			hud.mensaje("%s recompone sus páginas (+%d)" % [enemigo.nombre, turno.cura], hud.c_magia)
			await _esperar(pausa_mensaje)
	fallo_trivia = false
	_refrescar()


# El aviso dura turno.ritmo (más corto si fallaste trivias); luego se abre la
# ventana. Presionar antes de tiempo cuenta como fallo, para que no se pueda
# spamear el Espacio.
func _parry(danio: int, texto: String) -> void:
	fase = Fase.PARRY
	var ventana := ventana_parry if (escudo or not fallo_trivia) else ventana_fallo
	escudo = false
	var aviso := maxf(turno.ritmo, aviso_min)
	hud.mensaje(texto, hud.c_error)
	parry_presionado = false
	var inicio := Time.get_ticks_msec()
	# Se juzga con la hora de la tecla (parry_ms), así un tirón de FPS no
	# convierte un parry a tiempo en uno tarde.
	while true:
		await get_tree().process_frame
		var t := (Time.get_ticks_msec() - inicio) / 1000.0
		if parry_presionado or t >= aviso + ventana:
			break
		if t < aviso:
			hud.parry("aviso", t / aviso)
		else:
			hud.parry("ventana")
	var bien := false
	if parry_presionado:
		var tp := (parry_ms - inicio) / 1000.0
		bien = tp >= aviso and tp < aviso + ventana
	hud.parry("fin")
	fase = Fase.ENEMIGO
	print("parry: ", "perfecto" if bien else "fallado", " (ventana ", ventana, " s, aviso ", snappedf(aviso, 0.01), " s)")
	if bien:
		tinta = mini(tinta + 1, tinta_max)
		hud.mensaje("¡Parry perfecto! 0 de daño · +1 Tinta", hud.c_sabiduria)
	else:
		if salud:
			salud.recibir_golpe(danio)
		hud.mensaje("−%d HP" % danio, hud.c_error)
	_refrescar()
	await _esperar(pausa_mensaje)


func _velam_cayo() -> void:
	# salud.gd ya llamó a partida.perder("sin vida") (o hizo reaparecer a Velam).
	hud.mensaje("Velam cae…", hud.c_error)
	await _esperar(pausa_mensaje)
	await _cerrar()


# ------------------------------------------------------------- huir y dilema

func _huir() -> void:
	enemigo.enfriado = true
	hud.mensaje("Te retiras entre las estanterías", hud.c_texto)
	await _esperar(pausa_mensaje)
	print("combate: huye de ", enemigo.nombre, " (sigue vivo con ", turno.vida, " HP)")
	await _cerrar()


func _dilema() -> void:
	fase = Fase.DILEMA
	enemigo.cargando(false)
	var h: String = enemigo.habilidad
	hud.mensaje("")
	hud.mostrar_dilema(enemigo.nombre, enemigo.lore, HABILIDADES[h].nombre)
	var op: String = await hud.dilema_elegido
	var clave := enemigo.clave()
	var repetido := tomos.has(clave)          # ya decidido en un intento anterior
	if op == "leer":
		if not repetido:
			Lectura.bono += 1.0
		tomos[clave] = "leido"
		hud.mensaje("Lees el tomo · reloj de trivia: %s s" % Lectura.reloj_trivia(), hud.c_sabiduria)
	else:
		if not habilidades.has(h):
			habilidades.append(h)
		tomos[clave] = "quemado"
		hud.mensaje("El tomo arde · aprendes «%s»" % HABILIDADES[h].nombre, hud.c_error)
	print("combate: ", enemigo.nombre, " vencido · tomo ", tomos[clave], " · leídos ", tomos_leidos(), " (final sabiduría con 6)")
	await _esperar(pausa_mensaje * 1.5)
	enemigo.vencer()
	var partida := get_tree().get_first_node_in_group("partida")
	if partida:
		partida.avisar_meta()
	await _cerrar()


static func tomos_leidos() -> int:
	return tomos.values().count("leido")


# ------------------------------------------------------------- apoyo

func _refrescar() -> void:
	var est := []
	if turno.cargado:
		est.append("Cargando golpe fuerte")
	if defendiendo:
		est.append("Defendiéndose")
	if quema > 0:
		est.append("Quemado (%d)" % quema)
	if fallo_trivia:
		est.append("Parry corto: %s s" % ventana_fallo)
	if escudo:
		est.append("Página escudo")
	hud.actualizar({
		"vida_e": maxi(turno.vida, 0), "vida_e_max": vida_max_enemigo,
		"vida_v": salud.vida if salud else 0,
		"vida_v_max": salud.vida_inicial if salud and salud.vida_inicial > 0 else 100,
		"tinta": tinta, "tinta_max": tinta_max,
		"estados": "  ·  ".join(est),
	})


func _esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout
	
	
	
	# Variables para recordar dónde estaba la cámara antes del combate
var _cam_largo_orig := 4.5
var _cam_rot_x_orig := -15.0

func _enfocar_camara_combate(activar: bool) -> void:
	if pj == null:
		return
	var brazo := pj.get_node_or_null("BrazoCamara") as SpringArm3D
	if brazo == null:
		return
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if activar:
		_cam_largo_orig = brazo.spring_length
		_cam_rot_x_orig = brazo.rotation_degrees.x
		# Zoom estilo Expedition 33: más cerca y a la altura del hombro
		tw.tween_property(brazo, "spring_length", 2.6, 0.45)
		tw.parallel().tween_property(brazo, "rotation_degrees:x", -8.0, 0.45)
	else:
		tw.tween_property(brazo, "spring_length", _cam_largo_orig, 0.4)
		tw.parallel().tween_property(brazo, "rotation_degrees:x", _cam_rot_x_orig, 0.4)
