extends Node
class_name DialogBox

@export var altura: float = 100.0
@export var ancho_fraccion: float = 0.5
@export var margen: float = 20.0
@export var lado_derecho: bool = false
@export var transparencia_fondo: float = 0.5
@export var grosor_marco: int = 5
@export var grosor_banda: int = 6
@export var tamano_texto: int = 17
@export var color_marco: Color = Color("#F1E9D4")
@export var color_banda: Color = Color("000000ff")
@export var color_texto: Color = Color("#F1E9D4")
@export var pausa_letra: float = 0.02
@export var pausa_palabra: float = 0.06
@export var pausa_puntuacion: float = 0.28
@export var gracia_input: float = 0.25
@export var tecla_avanzar: Key = KEY_E
@export var accion_avanzar: String = ""
@export var ola_amplitud: float = 0.005
@export var ola_frecuencia: float = 12.0
@export var ola_velocidad: float = 2.2
@export var ola_tinte: Color = Color("ffffffec")
@export var ola_tinte_mix: float = 0.65
@export var usar_camara_hombro: bool = true
@export var test_al_iniciar: String = ""

const FUENTE_PATH := "res://Fuentes/TimesNewerRoman-Regular.otf"
const OLA_SHADER_PATH := "res://Shaders/texto_ola.gdshader"
const CAPA_UI: int = 110
const MARCA_OLA := "~"
const PUNTUACION := ".,;:!?"

signal pagina_completa
signal dialogo_cerrado

enum Estado {OCULTO, ESCRIBIENDO, COMPLETO}
var _estado: Estado = Estado.OCULTO

var _layer: CanvasLayer
var _panel: Panel
var _vbox: VBoxContainer
var _tri: Label
var _font: Font
var _shader: Shader

var _paginas: Array[String] = []
var _paginaIdx: int = 0
var _tokens: Array[Dictionary] = []
var _tokenIdx: int = 0
var _charIdx: int = 0
var _timer: float = 0.0
var _gracia: float = 0.0
var _filaActual: HFlowContainer = null
var _teclaPrev: bool = false
var _tiempo: float = 0.0

func _ready() -> void:
	_build_ui()
	ocultar()
	if test_al_iniciar != "":
		call_deferred("_mostrar_test")

func _mostrar_test() -> void:
	mostrar(test_al_iniciar)

# ── Construcción de UI ──────────────────────────────────────────────────────
func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = CAPA_UI
	add_child(_layer)

	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var se := StyleBoxFlat.new()
	se.bg_color = Color(color_banda.r, color_banda.g, color_banda.b, 1.0 - transparencia_fondo)
	se.border_color = color_marco
	se.set_border_width_all(grosor_marco)
	se.set_corner_radius_all(6)
	se.content_margin_left = grosor_banda
	se.content_margin_right = grosor_banda
	se.content_margin_top = grosor_banda
	se.content_margin_bottom = grosor_banda
	_panel.add_theme_stylebox_override("panel", se)
	_layer.add_child(_panel)
	_set_rect()

	var inner := Panel.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var si := StyleBoxFlat.new()
	si.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	si.set_corner_radius_all(3)
	inner.add_theme_stylebox_override("panel", si)
	_panel.add_child(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_vbox = VBoxContainer.new()
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_theme_constant_override("separation", 2)
	inner.add_child(_vbox)
	_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vbox.offset_left = 12.0
	_vbox.offset_top = 6.0
	_vbox.offset_right = -24.0
	_vbox.offset_bottom = -6.0

	_tri = Label.new()
	_tri.text = "▼"
	_tri.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tri.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tri.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tri.add_theme_font_size_override("font_size", tamano_texto)
	_tri.add_theme_color_override("font_color", color_marco)
	_tri.add_theme_color_override("font_outline_color", Color.BLACK)
	_tri.add_theme_constant_override("outline_size", 4)
	inner.add_child(_tri)
	_tri.anchor_left = 1.0
	_tri.anchor_top = 1.0
	_tri.anchor_right = 1.0
	_tri.anchor_bottom = 1.0
	_tri.offset_left = -22.0
	_tri.offset_top = -22.0
	_tri.offset_right = -8.0
	_tri.offset_bottom = -6.0
	_tri.visible = false

	if ResourceLoader.exists(FUENTE_PATH):
		var f: Resource = ResourceLoader.load(FUENTE_PATH)
		if f is Font:
			_font = f as Font
	if ResourceLoader.exists(OLA_SHADER_PATH):
		_shader = ResourceLoader.load(OLA_SHADER_PATH) as Shader
	if _font != null:
		_tri.add_theme_font_override("font", _font)

func _set_rect() -> void:
	if lado_derecho:
		_panel.anchor_left = 1.0 - ancho_fraccion
		_panel.anchor_right = 1.0
	else:
		_panel.anchor_left = 0.0
		_panel.anchor_right = ancho_fraccion
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = margen
	_panel.offset_right = - margen
	_panel.offset_top = margen
	_panel.offset_bottom = margen + altura

# ── API Pública ─────────────────────────────────────────────────────────────
func mostrar(texto: String) -> void:
	var paginas: Array[String] = []
	for linea in texto.split("\n"):
		var limpio := linea.strip_edges()
		if limpio != "":
			paginas.append(limpio)
	mostrar_paginas(paginas)

func mostrar_paginas(paginas: Array[String]) -> void:
	_paginas = paginas.duplicate()
	if _paginas.is_empty():
		return
	_paginaIdx = 0
	_panel.visible = true
	_abrir_pagina(_paginas[0])
	if usar_camara_hombro:
		var cam: Node = get_tree().get_first_node_in_group("cam_ciudad")
		if cam != null and cam.has_method("enter_dialogue_mode"):
			cam.enter_dialogue_mode(get_parent() as Node3D)

func ocultar() -> void:
	var estabaVisible := _panel.visible
	_panel.visible = false
	_tri.visible = false
	_estado = Estado.OCULTO
	if usar_camara_hombro:
		var cam: Node = get_tree().get_first_node_in_group("cam_ciudad")
		if cam != null and cam.has_method("exit_dialogue_mode"):
			cam.exit_dialogue_mode()
	if estabaVisible:
		dialogo_cerrado.emit()

func saltar_escritura() -> void:
	for tok in _tokens:
		if String(tok["tipo"]) == "word":
			var lbl: Label = tok["label"] as Label
			if lbl != null:
				lbl.text = String(tok["texto"])
	_tokenIdx = _tokens.size()
	_charIdx = 0
	_entrar_completo()

# ── Ciclo de Páginas ────────────────────────────────────────────────────────
func _abrir_pagina(texto: String) -> void:
	_limpiar_texto()
	_tokens = _construir_pagina(texto)
	_tokenIdx = 0
	_charIdx = 0
	_timer = 0.0
	_gracia = gracia_input
	_estado = Estado.ESCRIBIENDO
	_tri.visible = false

func _entrar_completo() -> void:
	_estado = Estado.COMPLETO
	_gracia = gracia_input
	_tri.visible = true
	pagina_completa.emit()

func _avanzar_pagina() -> void:
	_paginaIdx += 1
	if _paginaIdx >= _paginas.size():
		ocultar()
		return
	_abrir_pagina(_paginas[_paginaIdx])

func _process(delta: float) -> void:
	_tiempo += delta
	if _estado != Estado.OCULTO:
		_gracia = maxf(0.0, _gracia - delta)
	match _estado:
		Estado.ESCRIBIENDO:
			_timer -= delta
			while _estado == Estado.ESCRIBIENDO and _timer <= 0.0:
				_revelar_paso()
			if _estado == Estado.ESCRIBIENDO and _gracia <= 0.0 and _just_avanzar():
				saltar_escritura()
		Estado.COMPLETO:
			_tri.modulate.a = 0.55 + 0.45 * sin(_tiempo * 6.0)
			if _gracia <= 0.0 and _just_avanzar():
				_avanzar_pagina()
		Estado.OCULTO:
			pass
	_teclaPrev = Input.is_physical_key_pressed(tecla_avanzar)

func _just_avanzar() -> bool:
	if accion_avanzar != "" and InputMap.has_action(accion_avanzar):
		return Input.is_action_just_pressed(accion_avanzar)
	var now := Input.is_physical_key_pressed(tecla_avanzar)
	return now and not _teclaPrev

func _construir_pagina(texto: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var enOla := false
	for token in texto.replace("\t", " ").split(" ", false):
		if token.is_empty():
			continue
		var soloGuiones := true
		for i in token.length():
			if token[i] != "_":
				soloGuiones = false
				break
		if soloGuiones:
			out.append({"tipo": "pause", "seg": float(token.length()), "texto": "", "label": null})
			continue
		var olaTok := enOla
		var limpio := token
		if not enOla and limpio.begins_with(MARCA_OLA) and limpio.length() > 1:
			if limpio.ends_with(MARCA_OLA) and limpio.length() > 2:
				limpio = limpio.substr(1, limpio.length() - 2)
				olaTok = true
			else:
				limpio = limpio.substr(1)
				enOla = true
				olaTok = true
		elif enOla:
			if limpio.ends_with(MARCA_OLA) and limpio.length() > 1:
				limpio = limpio.substr(0, limpio.length() - 1)
				enOla = false
				olaTok = true
		var lbl := _crear_palabra(limpio, olaTok)
		out.append({"tipo": "word", "seg": 0.0, "texto": limpio, "label": lbl})
	return out

func _crear_palabra(texto_completo: String, ola: bool) -> Label:
	if _filaActual == null:
		_filaActual = HFlowContainer.new()
		_filaActual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_filaActual.alignment = FlowContainer.ALIGNMENT_BEGIN
		_vbox.add_child(_filaActual)
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = ""
	lbl.custom_minimum_size = _medir(texto_completo)
	lbl.add_theme_font_size_override("font_size", tamano_texto)
	lbl.add_theme_color_override("font_color", color_texto)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	if _font != null:
		lbl.add_theme_font_override("font", _font)
	if ola and _shader != null:
		var mat := ShaderMaterial.new()
		mat.shader = _shader
		mat.set_shader_parameter("amp", ola_amplitud)
		mat.set_shader_parameter("freq", ola_frecuencia)
		mat.set_shader_parameter("speed", ola_velocidad)
		mat.set_shader_parameter("phase", randf() * TAU)
		mat.set_shader_parameter("tint", ola_tinte)
		mat.set_shader_parameter("tint_mix", ola_tinte_mix)
		lbl.material = mat
	_filaActual.add_child(lbl)
	return lbl

func _medir(texto: String) -> Vector2:
	var f: Font = _font if _font != null else ThemeDB.fallback_font
	return f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tamano_texto)

func _revelar_paso() -> void:
	if _tokenIdx >= _tokens.size():
		_entrar_completo()
		return
	var tok: Dictionary = _tokens[_tokenIdx]
	var tipo: String = String(tok["tipo"])
	if tipo == "pause":
		_tokenIdx += 1
		_charIdx = 0
		_timer = float(tok["seg"])
		return
	var lbl: Label = tok["label"] as Label
	var full: String = String(tok["texto"])
	if _charIdx < full.length():
		_charIdx += 1
		lbl.text = full.substr(0, _charIdx)
		_timer = pausa_letra
	else:
		_tokenIdx += 1
		_charIdx = 0
		var extra := 0.0
		if full.length() > 0 and PUNTUACION.find(full[full.length() - 1]) >= 0:
			extra = pausa_puntuacion
		_timer = pausa_palabra + extra

func _limpiar_texto() -> void:
	for child in _vbox.get_children():
		child.queue_free()
	_filaActual = null
