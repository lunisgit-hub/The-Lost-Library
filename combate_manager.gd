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
@export var ventana_parry := 0.3       # segundos para el parry (antes 0.5: muy fácil)
@export var ventana_fallo := 0.18      # tras fallar la trivia
@export var ventana_escudo := 0.5      # con «Página escudo»
@export var aviso_min := 0.35          # el aviso del golpe nunca baja de esto
@export_group("Dificultad")
@export var multiplicador_danio := 1.3 # daño de los enemigos x esto
@export var mostrar_ventana := false   # true = el anillo se ilumina al abrirse la ventana (modo fácil)
@export var danio_contraataque := 10   # al parar TODOS los golpes de un combo: este + 4 por golpe
@export var ventana_esquiva := 0.5     # esquivar (Ctrl / acción "rodar"): más fácil, pero sin Tinta ni contraataque
@export var aviso_sonoro := 0.3        # el sonido de aviso suena esto antes del impacto (0 = sin aviso)
@export_group("")

const SONIDOS = {
	"parry": "res://sonidos/parry.wav",
	"aviso": "res://sonidos/aviso_golpe.wav",
	"herida": "res://sonidos/herida.wav",
	"esquiva": "res://sonidos/esquiva.wav",
	"contra": "res://sonidos/contraataque.wav",
}
var altavoces := {}
var esquiva_presionada := false
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
var azar := RandomNumberGenerator.new()   # tiempos del enemigo: distintos en cada partida
var ultimo_patron := ""

var cam_combate: Camera3D
var cam_anterior: Camera3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	azar.randomize()
	cam_combate = Camera3D.new()
	cam_combate.name = "CamaraCombate"
	cam_combate.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cam_combate)
	for clave in SONIDOS:
		var st := load(SONIDOS[clave]) as AudioStream
		if st == null:
			continue
		var a := AudioStreamPlayer.new()
		a.stream = st
		a.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(a)
		altavoces[clave] = a
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
	var esquivar: bool = InputMap.has_action("rodar") and event.is_action_pressed("rodar") and not event.is_echo()
	if (espacio or clic or esquivar) and not parry_presionado:
		parry_presionado = true
		esquiva_presionada = esquivar and not (espacio or clic)
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
	var anim_cab := enemigo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_cab != null:
		anim_cab.process_mode = Node.PROCESS_MODE_ALWAYS
		anim_cab.play("Walking", -1, 0.35) # Respira/camina lento en guardia
	hud.abrir(e.nombre)
	_activar_camara_combate(e.get_node_or_null(e.punto) as Node3D)
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
	_desactivar_camara_combate()
	enemigo.en_combate(false)
	await hud.cerrar()
	var partida := get_tree().get_first_node_in_group("partida")
	# Si la partida terminó (ganó o perdió), ella maneja la pausa y el reinicio.
	if partida == null or partida.estado == partida.Estado.JUGANDO:
		get_tree().paused = false


# ------------------------------------------------------------- cámara de combate

func _activar_camara_combate(objetivo: Node3D) -> void:
	# Hacer que Velam y el enemigo se miren de frente (sin inclinarse arriba/abajo)
	var pos_enemigo_plana := Vector3(objetivo.global_position.x, pj.global_position.y, objetivo.global_position.z)
	if pj.global_position.distance_to(pos_enemigo_plana) > 0.05:
		pj.look_at(pos_enemigo_plana, Vector3.UP)

	var pos_pj_plana := Vector3(pj.global_position.x, objetivo.global_position.y, pj.global_position.z)
	if objetivo.global_position.distance_to(pos_pj_plana) > 0.05:
		objetivo.look_at(pos_pj_plana, Vector3.UP)
	if pj == null or objetivo == null:
		return
	cam_anterior = get_viewport().get_camera_3d()
	if cam_anterior != null and cam_anterior != cam_combate:
		cam_combate.global_transform = cam_anterior.global_transform
		cam_combate.fov = cam_anterior.fov
	cam_combate.current = true

	var dir_hacia_pj := pj.global_position - objetivo.global_position
	dir_hacia_pj.y = 0.0
	if dir_hacia_pj.length() < 0.01:
		dir_hacia_pj = Vector3.BACK
	dir_hacia_pj = dir_hacia_pj.normalized()

	var derecha := Vector3.UP.cross(dir_hacia_pj).normalized()

	# Encuadre estilo Expedition 33: sobre el hombro derecho, bajo y cercano
	var pos_final := pj.global_position \
		+ (dir_hacia_pj * 2.2) \
		+ (derecha * 0.95) \
		+ Vector3(0, 1.35, 0)

	var mira := objetivo.global_position + Vector3(0, 1.25, 0)
	var transform_final := Transform3D(Basis(), pos_final).looking_at(mira, Vector3.UP)

	var tw := create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(cam_combate, "fov", 50.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cam_combate, "global_transform", transform_final, 0.45).set_trans(Tween.TRANS_SINE)


func _desactivar_camara_combate() -> void:
	if is_instance_valid(cam_anterior):
		cam_anterior.current = true
	cam_anterior = null


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
			await _ataque_enemigo(false)
		A.GOLPE_FUERTE:
			enemigo.cargando(false)
			await _ataque_enemigo(true)
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


# ------------------------------------------------------------- ataques y parry

const PATRONES_NIVEL = [
	{"rapido": 30, "normal": 40, "retrasado": 15, "doble": 15},
	{"rapido": 20, "normal": 20, "retrasado": 20, "doble": 25, "triple": 15},
	{"rapido": 10, "normal": 10, "retrasado": 20, "doble": 25, "triple": 35},
]
const IMPACTO_SLASH := 1.25   # segundo de Charged_Slash (caballero) en el que cae el tajo


func _nivel_enemigo() -> int:
	if es_jefe:
		return 2
	if vida_max_enemigo >= 45 or turno.ritmo < 1.0:
		return 1
	return 0


func _r(a: float, b: float) -> float:
	return azar.randf_range(a, b)


func _elegir_patron(fuerte: bool) -> Array:
	var a := maxf(turno.ritmo, aviso_min)
	if fuerte:
		var gf := [{"espera": a * _r(1.3, 1.9), "amago": azar.randf() < 0.5, "mult": 1.0}]
		if es_jefe:
			gf.append({"espera": a * _r(0.35, 0.6), "amago": false, "mult": 0.45})
		ultimo_patron = "fuerte"
		return gf
	var pesos: Dictionary = PATRONES_NIVEL[_nivel_enemigo()].duplicate()
	if enfurecido:
		pesos["furia"] = 30
	pesos.erase(ultimo_patron)
	var total := 0
	for k in pesos:
		total += pesos[k]
	var sale := azar.randi_range(1, total)
	var nombre := "normal"
	for k in pesos:
		sale -= pesos[k]
		if sale <= 0:
			nombre = k
			break
	ultimo_patron = nombre
	match nombre:
		"rapido":
			return [{"espera": a * _r(0.5, 0.75), "amago": false, "mult": 0.9}]
		"retrasado":
			return [{"espera": a * _r(1.6, 2.4), "amago": true, "mult": 1.1}]
		"doble":
			return [
				{"espera": a * _r(0.8, 1.2), "amago": false, "mult": 0.7},
				{"espera": a * _r(0.35, 0.7), "amago": false, "mult": 0.7},
			]
		"triple":
			return [
				{"espera": a * _r(0.8, 1.2), "amago": false, "mult": 0.6},
				{"espera": a * _r(0.35, 0.55), "amago": false, "mult": 0.6},
				{"espera": a * _r(0.7, 1.5), "amago": azar.randf() < 0.5, "mult": 0.7},
			]
		"furia":
			var g := []
			for k in 4:
				g.append({"espera": a * (_r(0.9, 1.2) if k == 0 else _r(0.3, 0.8)), "amago": k == 3 and azar.randf() < 0.5, "mult": 0.5})
			return g
	return [{"espera": a * _r(0.9, 1.35), "amago": false, "mult": 1.0}]


func _ataque_enemigo(fuerte: bool) -> void:
	var patron := _elegir_patron(fuerte)
	var base: int = enemigo.danio_fuerte if fuerte else enemigo.danio
	var total := patron.size()
	if fuerte:
		hud.mensaje("¡Golpe fuerte!", hud.c_error)
	elif total > 1:
		hud.mensaje("¡%s encadena %d golpes!" % [enemigo.nombre, total], hud.c_error)
	else:
		hud.mensaje("%s ataca" % enemigo.nombre, hud.c_error)
	var ventana := ventana_escudo if escudo else (ventana_fallo if fallo_trivia else ventana_parry)
	escudo = false
	_flotar(false)
	var parados := 0
	var esquivados := 0
	for i in total:
		var g: Dictionary = patron[i]
		var danio := maxi(int(round(base * g.mult * multiplicador_danio)), 1)
		var r: int = await _parry_golpe(g.espera, g.amago, ventana, danio, i, total)
		if r == 1:
			parados += 1
		elif r == 2:
			esquivados += 1
		if salud and salud.vida <= 0:
			break
	hud.parry("fin")
	fase = Fase.ENEMIGO
	_flotar(true)
	_refrescar()
	await _esperar(pausa_mensaje * 0.6)
	if salud and salud.vida <= 0:
		return
	if parados == total:
		tinta = mini(tinta + 1, tinta_max)
		if total >= 2:
			await _contraataque(total)
		else:
			hud.mensaje("¡Parry perfecto! 0 de daño · +1 Tinta", hud.c_sabiduria)
			_refrescar()
			await _esperar(pausa_mensaje * 0.6)
	elif parados + esquivados == total:
		hud.mensaje("Lo evitaste todo (esquivar no da Tinta)", hud.c_texto)
		await _esperar(pausa_mensaje * 0.6)
	elif parados + esquivados > 0:
		hud.mensaje("Evitaste %d de %d golpes" % [parados + esquivados, total], hud.c_oro)
		await _esperar(pausa_mensaje * 0.6)


func _parry_golpe(espera: float, amago: bool, ventana: float, danio: int, i: int, total: int) -> int:
	fase = Fase.PARRY
	parry_presionado = false
	esquiva_presionada = false
	_telegrafiar(espera, amago)
	var golpeo := false
	var avisado := aviso_sonoro <= 0.0
	var inicio := Time.get_ticks_msec()
	while true:
		await get_tree().process_frame
		var t := (Time.get_ticks_msec() - inicio) / 1000.0
		if not avisado and t >= espera - aviso_sonoro:
			avisado = true
			_sonar("aviso")
		if not golpeo and t >= espera - 0.12:
			golpeo = true
			_impacto_enemigo()
		var v := ventana_esquiva if esquiva_presionada else ventana
		if parry_presionado:
			var tp_ := (parry_ms - inicio) / 1000.0
			if tp_ >= espera - v * 0.5 or t >= espera:
				break
		if t >= espera + maxf(ventana, ventana_esquiva) * 0.5:
			break
		if mostrar_ventana and t >= espera - ventana * 0.5:
			hud.parry("ventana")
		else:
			hud.parry("atento", t)
	if not golpeo:
		_impacto_enemigo()
	var tp := (parry_ms - inicio) / 1000.0
	var vent := ventana_esquiva if esquiva_presionada else ventana
	var a_tiempo := parry_presionado and absf(tp - espera) <= vent * 0.5
	var resultado := 0
	if a_tiempo:
		resultado = 2 if esquiva_presionada else 1
	fase = Fase.ENEMIGO
	print("golpe %d/%d: %s (impacto a %s s%s, tecla a %s s)" % [i + 1, total,
		["te pega", "parry", "esquiva"][resultado], snappedf(espera, 0.01),
		", amago" if amago else "", str(snappedf(tp, 0.01)) if parry_presionado else "-"])
	match resultado:
		1:
			_sonar("parry")
			_anim(anim_pj, "attack-melee-left")
			_camara("golpe_fov", 5.0)
			_camara("sacudir", 0.08)
			_destello(Color(0.69, 0.6, 0.78, 0.35))
			_numero("¡Parry!" if total == 1 else "¡Parry %d/%d!" % [i + 1, total], _sobre_velam(), hud.c_magia, true)
		2:
			_sonar("esquiva")
			_esquivar_visual()
			_numero("Esquiva", _sobre_velam(), hud.c_texto)
		_:
			_sonar("herida")
			var modelo_pj = pj.get_node_or_null("Heroe")
			if modelo_pj == null:
				modelo_pj = pj.get_node_or_null("Modelo")
			_retroceso(modelo_pj, cuerpo_e)
			_camara("sacudir", 0.25)
			_destello(Color(0.8, 0.1, 0.1, 0.35))
			if salud:
				salud.recibir_golpe(danio, true)
			_numero("−%d" % danio, _sobre_velam(), hud.c_error, true)
			hud.mensaje("−%d HP" % danio + ("  (muy pronto)" if parry_presionado and tp < espera else ""), hud.c_error)
	_refrescar()
	return resultado


func _sonar(clave: String) -> void:
	var a: AudioStreamPlayer = altavoces.get(clave)
	if a:
		a.pitch_scale = azar.randf_range(0.95, 1.05)
		a.play()


func _esquivar_visual() -> void:
	var m := pj.get_node_or_null("Heroe") as Node3D
	if m == null or not is_instance_valid(cuerpo_e):
		return
	var hacia := cuerpo_e.global_position - pj.global_position
	hacia.y = 0.0
	if hacia.length() < 0.05:
		return
	var lado := hacia.normalized().cross(Vector3.UP) * 0.7
	var local := pj.global_basis.inverse() * lado
	var origen := m.position
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "position", origen + local, 0.1)
	tw.tween_interval(0.12)
	tw.tween_property(m, "position", origen, 0.25).set_ease(Tween.EASE_IN_OUT)


func _contraataque(golpes: int) -> void:
	hud.mensaje("¡Contraataque! +1 Tinta", hud.c_oro)
	_sonar("contra")
	_anim(anim_pj, "attack-melee-right")
	_camara("golpe_fov", 8.0)
	_camara("sacudir", 0.2)
	_destello(Color(0.83, 0.64, 0.35, 0.35))
	_retroceso(cuerpo_e, pj)
	_danar(danio_contraataque + 4 * golpes, hud.c_oro, true)
	await _esperar(pausa_mensaje)


func _telegrafiar(espera: float, amago: bool) -> void:
	var ap := _anim_caballero()
	if ap != null:
		ap.play("Charged_Slash", 0.1)
		ap.seek(0.0, true)
		var tw := create_tween()
		if amago and espera > 0.6:
			var alto := 0.75
			ap.speed_scale = alto / (espera * 0.4)
			tw.tween_interval(espera * 0.4)
			tw.tween_callback(func(): ap.speed_scale = 0.0)
			tw.tween_interval(maxf(espera * 0.6 - (IMPACTO_SLASH - alto) / 2.0, 0.0))
			tw.tween_callback(func(): ap.speed_scale = 2.0)
		else:
			ap.speed_scale = clampf(IMPACTO_SLASH / espera, 0.3, 4.0)
			tw.tween_interval(espera)
		tw.tween_interval(0.7)
		tw.tween_callback(func():
			ap.speed_scale = 1.0
			if ap.has_animation("Walking"):
				ap.play("Walking", 0.2, 0.35))
		return
	if not is_instance_valid(cuerpo_e) or pj == null:
		return
	var atras := _hacia_pj_local(-0.45)
	var arriba := Vector3(0, 0.3, 0)
	var prep := maxf(espera - 0.12, 0.05)
	var tw2 := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if amago and prep > 0.7:
		tw2.tween_property(cuerpo_e, "position", base_e + atras + arriba, prep * 0.3)
		tw2.tween_property(cuerpo_e, "position", base_e + _hacia_pj_local(0.35), 0.12)
		tw2.tween_property(cuerpo_e, "position", base_e + atras * 1.3 + arriba * 1.2, 0.25)
		tw2.tween_interval(maxf(prep * 0.7 - 0.37, 0.0))
	else:
		tw2.tween_property(cuerpo_e, "position", base_e + atras + arriba, prep * 0.7)
		for k in 4:
			tw2.tween_property(cuerpo_e, "position:y", base_e.y + arriba.y + (0.04 if k % 2 == 0 else -0.04), prep * 0.075)


func _hacia_pj_local(metros: float) -> Vector3:
	var hacia := pj.global_position - cuerpo_e.global_position
	hacia.y = 0.0
	if hacia.length() < 0.05:
		return Vector3.ZERO
	var padre := cuerpo_e.get_parent_node_3d()
	var v := hacia.normalized() * metros
	return padre.global_basis.inverse() * v if padre else v


func _impacto_enemigo() -> void:
	if _anim_caballero() == null:
		_anim(anim_e, "attack-melee-right")
	_embestida_enemigo()


func _flotar(si: bool) -> void:
	if anim_e != null or not is_instance_valid(cuerpo_e) or _anim_caballero() != null:
		return
	if tw_flota:
		tw_flota.kill()
		tw_flota = null
	if not si:
		return
	tw_flota = create_tween().set_loops()
	tw_flota.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_flota.tween_property(cuerpo_e, "position", base_e + Vector3(0, 0.3, 0), 1.1)
	tw_flota.tween_property(cuerpo_e, "position", base_e, 1.1)


func _velam_cayo() -> void:
	sin_idle.append(anim_pj)
	hud.mensaje("Velam cae…", hud.c_error)
	var partida := get_tree().get_first_node_in_group("partida")
	while salud and salud.vida <= 0 and (partida == null or partida.estado == partida.Estado.JUGANDO):
		await get_tree().process_frame
	if salud and salud.vida > 0:
		turno.vida = vida_max_enemigo
		enemigo.enfriado = true
		hud.mensaje("Velam vuelve a levantarse", hud.c_sabiduria)
		await _esperar(pausa_mensaje)
	sin_idle.erase(anim_pj)
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
	var repetido := tomos.has(clave)
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


func _preparar_animaciones(e: EnemigoCombate) -> void:
	sin_idle.clear()
	modos_anim.clear()
	anim_pj = pj.get("anim") as AnimationPlayer
	if anim_pj == null:
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
	if cam == null:
		return
	if cam == cam_combate:
		if metodo == "sacudir":
			var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			for i in 4:
				tw.tween_property(cam_combate, "h_offset", randf_range(-valor, valor) * 0.4, 0.04)
				tw.parallel().tween_property(cam_combate, "v_offset", randf_range(-valor, valor) * 0.4, 0.04)
			tw.tween_property(cam_combate, "h_offset", 0.0, 0.05)
			tw.parallel().tween_property(cam_combate, "v_offset", 0.0, 0.05)
		elif metodo == "golpe_fov":
			var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(cam_combate, "fov", 50.0 - valor, 0.08).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(cam_combate, "fov", 50.0, 0.22).set_trans(Tween.TRANS_SINE)
		return
	if cam.has_method(metodo):
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


func _anim_caballero() -> AnimationPlayer:
	if enemigo == null:
		return null
	var raiz: Node = enemigo.get_parent() if enemigo.get_parent() != null else enemigo
	for nodo in raiz.find_children("*", "AnimationPlayer", true, false):
		var ap := nodo as AnimationPlayer
		if ap != null and ap.has_animation("Charged_Slash"):
			ap.process_mode = Node.PROCESS_MODE_ALWAYS
			return ap
	return null
