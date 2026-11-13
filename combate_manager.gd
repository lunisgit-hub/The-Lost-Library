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

var anim_pj: AnimationPlayer
var anim_e: AnimationPlayer
var cuerpo_e: Node3D
var base_e := Vector3.ZERO
var tw_flota: Tween
var modos_anim := {}
var sin_idle := []
var alto_e := 2.0
var vineta: CanvasLayer
var es_jefe := false
var enfurecido := false


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


func _process(_d: float) -> void:
	if fase == Fase.EXPLORAR:
		return
	for a in [anim_pj, anim_e]:
		if a != null and is_instance_valid(a) and not sin_idle.has(a) and not a.is_playing():
			_anim(a, "idle")


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
	es_jefe = e.es_jefe
	enfurecido = false
	trivia.enemigo = turno
	get_tree().paused = true
	enemigo.en_combate(true)
	var anim_e := enemigo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_e != null:
		anim_e.process_mode = Node.PROCESS_MODE_ALWAYS
		anim_e.play("Walking", -1, 0.35) # Respira/camina lento en guardia
	hud.abrir(e.nombre)
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("enfocar_combate"):
		cam.call("enfocar_combate", e.get_node_or_null(e.punto))
	_preparar_animaciones(e)
	_refrescar()
	print("combate: empieza contra ", e.nombre, " (", turno.vida, " HP)")
	_poner_vineta()
	if es_jefe:
		_camara("sacudir", 0.3)
		_destello(Color(0.5, 0.05, 0.1, 0.4))
		await _entrada(e.nombre, "JEFE FINAL", hud.c_error, 1.6)
	else:
		await _entrada("¡%s te cierra el paso!" % e.nombre)
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
		if es_jefe and not enfurecido and turno.vida * 2 <= vida_max_enemigo:
			await _enfurecer()
		await _turno_enemigo()
		if salud and salud.vida <= 0:
			await _velam_cayo()
			return
		if turno.vida <= 0:
			await _dilema()
			return


func _cerrar() -> void:
	fase = Fase.EXPLORAR
	Engine.time_scale = 1.0
	_quitar_vineta()
	_soltar_animaciones()
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("soltar_combate"):
		cam.call("soltar_combate")
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
			_golpe_de_velam()
			_danar(danio_hoja, hud.c_texto)
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
		_golpe_de_velam()
		_danar(r[2] + extra, hud.c_magia if critico else hud.c_texto, critico)
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


func _danar(n: int, color := Color.WHITE, grande := false) -> void:
	if defendiendo:
		n = int(n / 2.0)
	var antes: int = turno.vida
	turno.recibir_golpe(n)
	turno.vida = maxi(turno.vida, 0)
	_numero(str(n), _sobre_enemigo(), color, grande)
	if antes > 0 and turno.vida <= 0:
		_camara_lenta()
	_refrescar()


# ------------------------------------------------------------- turno enemigo

func _turno_enemigo() -> void:
	fase = Fase.ENEMIGO
	if quema > 0:
		quema -= 1
		hud.mensaje("La llama quema el tomo: −%d" % danio_quema, hud.c_papel.lightened(0.4))
		_danar(danio_quema, hud.c_oro)
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
			_numero("+%d" % turno.cura, _sobre_enemigo(), hud.c_sabiduria)
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
	_anim(anim_e, "interact-right")
	var golpeo := false
	var inicio := Time.get_ticks_msec()
	var anim_e := enemigo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_e != null and anim_e.has_animation("Charged_Slash"):
		anim_e.play("Charged_Slash")
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
			if not golpeo:
				golpeo = true
				_embestida_enemigo()
	var bien := false
	if parry_presionado:
		var tp := (parry_ms - inicio) / 1000.0
		bien = tp >= aviso and tp < aviso + ventana
	hud.parry("fin")
	fase = Fase.ENEMIGO
	print("parry: ", "perfecto" if bien else "fallado", " (ventana ", ventana, " s, aviso ", snappedf(aviso, 0.01), " s)")
	if not golpeo:
		_embestida_enemigo()
	if bien:
		_anim(anim_pj, "attack-melee-left")
		_camara("golpe_fov", 7.0)
		_camara("sacudir", 0.08)
		_destello(Color(0.69, 0.6, 0.78, 0.35))
		_numero("¡Parry!", _sobre_velam(), hud.c_magia, true)
		tinta = mini(tinta + 1, tinta_max)
		hud.mensaje("¡Parry perfecto! 0 de daño · +1 Tinta", hud.c_sabiduria)
	else:
		_retroceso(pj.get_node_or_null("Modelo"), cuerpo_e)
		_camara("sacudir", 0.25)
		_destello(Color(0.8, 0.1, 0.1, 0.35))
		if salud:
			salud.recibir_golpe(danio)
		_numero("−%d" % danio, _sobre_velam(), hud.c_error, true)
		hud.mensaje("−%d HP" % danio, hud.c_error)
	_refrescar()
	await _esperar(pausa_mensaje)


func _velam_cayo() -> void:
	# salud.gd ya llamó a partida.perder("sin vida") (o hizo reaparecer a Velam).
	_anim(anim_pj, "die")
	sin_idle.append(anim_pj)
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
	_enemigo_cae()
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




func _preparar_animaciones(e: EnemigoCombate) -> void:
	sin_idle.clear()
	modos_anim.clear()
	anim_pj = pj.get_node_or_null("Modelo/AnimationPlayer") as AnimationPlayer
	cuerpo_e = e.get_node_or_null(e.punto) as Node3D
	anim_e = null
	alto_e = 2.0
	if cuerpo_e:
		base_e = cuerpo_e.position
		var caja := _caja_visual(cuerpo_e)
		if caja.size.y > 0.05:
			alto_e = caja.end.y - cuerpo_e.global_position.y
		var lista := cuerpo_e.find_children("*", "AnimationPlayer", true, false)
		if not lista.is_empty():
			anim_e = lista[0] as AnimationPlayer
	for a in [anim_pj, anim_e]:
		if a:
			modos_anim[a] = a.process_mode
			a.process_mode = Node.PROCESS_MODE_ALWAYS
			a.speed_scale = 1.0
	_anim(anim_pj, "idle")
	if anim_e:
		_anim(anim_e, "idle")
	elif cuerpo_e:
		tw_flota = create_tween().set_loops()
		tw_flota.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_flota.tween_property(cuerpo_e, "position:y", base_e.y + 0.3, 1.1)
		tw_flota.tween_property(cuerpo_e, "position:y", base_e.y, 1.1)


func _soltar_animaciones() -> void:
	if tw_flota:
		tw_flota.kill()
		tw_flota = null
	if is_instance_valid(cuerpo_e) and anim_e == null:
		cuerpo_e.position = base_e
	for a in modos_anim:
		if is_instance_valid(a):
			a.process_mode = modos_anim[a]
	modos_anim.clear()


func _anim(a: AnimationPlayer, nombre: String) -> void:
	if a != null and is_instance_valid(a) and a.has_animation(nombre):
		a.play(nombre, 0.15)


func _golpe_de_velam() -> void:
	_anim(anim_pj, "attack-melee-right")
	_retroceso(cuerpo_e, pj)
	_camara("sacudir", 0.1)


func _embestida_enemigo() -> void:
	if anim_e:
		_anim(anim_e, "attack-melee-right")
		return
	if not is_instance_valid(cuerpo_e) or pj == null:
		return
	var hacia := pj.global_position - cuerpo_e.global_position
	hacia.y = 0.0
	if hacia.length() < 0.05:
		return
	var local := cuerpo_e.get_parent_node_3d().global_basis.inverse() * (hacia.normalized() * minf(hacia.length() * 0.5, 1.2)) if cuerpo_e.get_parent_node_3d() else hacia
	var tw := create_tween().set_trans(Tween.TRANS_BACK)
	tw.tween_property(cuerpo_e, "position:x", base_e.x + local.x, 0.12).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(cuerpo_e, "position:z", base_e.z + local.z, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(cuerpo_e, "position:x", base_e.x, 0.3).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(cuerpo_e, "position:z", base_e.z, 0.3).set_ease(Tween.EASE_IN_OUT)


func _retroceso(quien: Node, desde: Node) -> void:
	var n := quien as Node3D
	var d := desde as Node3D
	if not is_instance_valid(n) or not is_instance_valid(d):
		return
	var lejos := n.global_position - d.global_position
	lejos.y = 0.0
	if lejos.length() < 0.05:
		return
	var padre := n.get_parent_node_3d()
	var local := padre.global_basis.inverse() * (lejos.normalized() * 0.35) if padre else lejos.normalized() * 0.35
	var origen := n.position
	if n == cuerpo_e:
		origen = Vector3(base_e.x, n.position.y, base_e.z)
	var tw := create_tween()
	tw.tween_property(n, "position:x", origen.x + local.x, 0.08)
	tw.parallel().tween_property(n, "position:z", origen.z + local.z, 0.08)
	tw.tween_property(n, "position:x", origen.x, 0.25).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(n, "position:z", origen.z, 0.25).set_trans(Tween.TRANS_SINE)


func _enemigo_cae() -> void:
	_camara("sacudir", 0.15)
	_destello(Color(1, 1, 1, 0.3))
	if anim_e:
		_anim(anim_e, "die")
		sin_idle.append(anim_e)
	elif is_instance_valid(cuerpo_e):
		if tw_flota:
			tw_flota.kill()
			tw_flota = null
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(cuerpo_e, "position:y", base_e.y - 0.4, 0.5)
		tw.parallel().tween_property(cuerpo_e, "rotation_degrees:z", cuerpo_e.rotation_degrees.z + 80.0, 0.5)



func _camara(metodo: String, valor: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method(metodo):
		cam.call(metodo, valor)


func _destello(color: Color) -> void:
	var capa := CanvasLayer.new()
	capa.layer = 50
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(rect)
	add_child(capa)
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, 0.25)
	tw.tween_callback(capa.queue_free)



func _caja_visual(n: Node) -> AABB:
	var caja := AABB()
	var hay := false
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		var c: AABB = gi.global_transform * gi.get_aabb()
		caja = c if not hay else caja.merge(c)
		hay = true
	return caja


func _sobre_enemigo() -> Vector3:
	if is_instance_valid(cuerpo_e):
		return cuerpo_e.global_position + Vector3(0, alto_e + 0.3, 0)
	return pj.global_position + Vector3(0, 2.5, 0) if pj else Vector3.ZERO


func _sobre_velam() -> Vector3:
	return pj.global_position + Vector3(0, 2.3, 0) if pj else Vector3.ZERO


func _numero(texto: String, donde: Vector3, color: Color, grande := false) -> void:
	var l := Label3D.new()
	l.text = texto
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0007
	l.font_size = 72 if grande else 52
	l.outline_size = 14
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.03, 0.08, 1)
	l.render_priority = 10
	l.outline_render_priority = 9
	var fuente = hud.get("fuente_combate") if hud else null
	if fuente is Font:
		l.font = fuente
	l.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(l)
	l.global_position = donde + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	l.scale = Vector3.ONE * 0.4
	var tw := create_tween().set_ignore_time_scale()
	tw.tween_property(l, "scale", Vector3.ONE * (1.3 if grande else 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "global_position:y", donde.y + 0.9, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(l, "outline_modulate:a", 0.0, 0.35)
	tw.tween_callback(l.queue_free)


func _camara_lenta() -> void:
	Engine.time_scale = 0.25
	await get_tree().create_timer(0.8, true, false, true).timeout
	Engine.time_scale = 1.0


func _poner_vineta() -> void:
	_quitar_vineta()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_offset(0, 0.45)
	g.set_color(1, Color(0.03, 0.01, 0.06, 0.85))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.modulate.a = 0.0
	vineta = CanvasLayer.new()
	vineta.layer = 0
	vineta.process_mode = Node.PROCESS_MODE_ALWAYS
	vineta.add_child(r)
	add_child(vineta)
	create_tween().set_ignore_time_scale().tween_property(r, "modulate:a", 1.0, 0.4)


func _quitar_vineta() -> void:
	if not is_instance_valid(vineta):
		return
	var capa := vineta
	vineta = null
	var r := capa.get_child(0) as CanvasItem
	var tw := create_tween().set_ignore_time_scale()
	tw.tween_property(r, "modulate:a", 0.0, 0.4)
	tw.tween_callback(capa.queue_free)


func _entrada(subtitulo: String, encabezado := "¡ENCUENTRO!", color := Color(0, 0, 0, 0), espera := 0.9) -> void:
	if color.a == 0.0:
		color = hud.c_magia
	var tam := get_viewport().get_visible_rect().size
	var capa := CanvasLayer.new()
	capa.layer = 40
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)
	var banda := Control.new()
	banda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banda.size = Vector2(tam.x, 170)
	banda.position = Vector2(-tam.x, tam.y * 0.5 - 85)
	capa.add_child(banda)
	var fondo := ColorRect.new()
	fondo.color = Color(0.04, 0.02, 0.07, 0.88)
	fondo.size = banda.size
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banda.add_child(fondo)
	for y in [0.0, banda.size.y - 4.0]:
		var linea := ColorRect.new()
		linea.color = color
		linea.size = Vector2(tam.x, 4)
		linea.position = Vector2(0, y)
		linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banda.add_child(linea)
	var fuente = hud.get("fuente_combate")
	var titulo := Label.new()
	titulo.text = encabezado
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.size = Vector2(tam.x, 90)
	titulo.position = Vector2(0, 18)
	titulo.add_theme_font_size_override("font_size", 64)
	titulo.add_theme_color_override("font_color", color)
	titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	titulo.add_theme_constant_override("outline_size", 10)
	var sub := Label.new()
	sub.text = subtitulo
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(tam.x, 40)
	sub.position = Vector2(0, 110)
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", hud.c_texto)
	for lbl in [titulo, sub]:
		if fuente is Font:
			lbl.add_theme_font_override("font", fuente)
		banda.add_child(lbl)
	var tw := create_tween().set_ignore_time_scale()
	tw.tween_property(banda, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(espera)
	tw.tween_property(banda, "position:x", tam.x, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(capa.queue_free)
	await tw.finished



func _enfurecer() -> void:
	enfurecido = true
	turno.ritmo *= 0.8
	var nuevos: Array[int] = [35, 50, 15]
	turno.pesos = nuevos
	enemigo.danio += 6
	enemigo.danio_fuerte += 10
	if enemigo.luz:
		enemigo.luz.light_color = hud.c_error
	_camara("sacudir", 0.35)
	_destello(Color(0.6, 0.05, 0.1, 0.45))
	_numero("¡FURIA!", _sobre_enemigo(), hud.c_error, true)
	hud.mensaje("¡%s se enfurece! Ataca más rápido y más fuerte" % enemigo.nombre, hud.c_error)
	_refrescar()
	await _esperar(pausa_mensaje * 1.6)
