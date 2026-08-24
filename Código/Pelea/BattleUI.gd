extends CanvasLayer

@export var player1: NodePath
@export var player2: NodePath

# ─── Referencias de jugadores ────────────────────────────────────────────────
var p1_body: FighterBody
var p2_body: FighterBody

# ─── Nodos UI ────────────────────────────────────────────────────────────────
var _letterbox_top: ColorRect
var _letterbox_bottom: ColorRect
var _top_container: MarginContainer
var _msg_container: Control
var _p1_health_bar: ProgressBar
var _p2_health_bar: ProgressBar
var _p1_name_label: Label
var _p2_name_label: Label
var _p1_hp_text: Label
var _p2_hp_text: Label
var _p1_rounds_label: Label
var _p2_rounds_label: Label
var _combo_label: Label
var _input_history_label: RichTextLabel
var _match_manager: Node = null
var _bottom_hud: MarginContainer
var _letterbox_out_played := false
var _headline_tween: Tween = null

# ─── Fuentes ─────────────────────────────────────────────────────────────────
var _font_title: Font
var _font_ui: Font
var _font_announcer: Font

# ─── Animación de vida ───────────────────────────────────────────────────────
var _p1_target_hp: float = 100.0
var _p2_target_hp: float = 100.0
var _p1_display_hp: float = 100.0
var _p2_display_hp: float = 100.0
var _p1_flash: float = 0.0
var _p2_flash: float = 0.0

# ─── Letterbox ──────────────────────────────────────────────────────────────
@export var letterbox_height_top: float = 75.0
@export var letterbox_height_bottom: float = 75.0
@export var hud_background_opacity: float = 0.75

# ─── Colores ─────────────────────────────────────────────────────────────────
const COLOR_P1 := Color(0.15, 0.85, 0.35) # Verde
const COLOR_P2 := Color(0.9, 0.2, 0.15) # Rojo
const COLOR_NEUTRAL := Color(0.85, 0.6, 0.1) # Dorado
const COLOR_BG := Color(0.02, 0.02, 0.03, 0.85)
const COLOR_BORDER := Color(0.3, 0.3, 0.3, 0.8)

func _ready() -> void:
	_load_fonts()
	_setup_ui()
	_resolve_players()
	_init_letterbox_anim()

func _load_fonts() -> void:
	var base := "res://Fuentes/"
	var paths := {
		"title": base + "DirtyBrush.ttf",
		"ui": base + "sing_14l.ttf",
		"announcer": base + "Mom«t___.ttf"
	}
	for key in paths:
		if FileAccess.file_exists(paths[key]) or ResourceLoader.exists(paths[key]):
			match key:
				"title": _font_title = load(paths[key])
				"ui": _font_ui = load(paths[key])
				"announcer": _font_announcer = load(paths[key])
	# Fallbacks
	if not _font_title:
		_font_title = ThemeDB.fallback_font
	if not _font_ui:
		_font_ui = ThemeDB.fallback_font
	if not _font_announcer:
		_font_announcer = ThemeDB.fallback_font

func _setup_ui() -> void:
	# ─── Letterbox superior ────────────────
	_letterbox_top = ColorRect.new()
	_letterbox_top.color = Color.BLACK
	_letterbox_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_letterbox_top.offset_bottom = letterbox_height_top
	_letterbox_top.z_index = 1
	add_child(_letterbox_top)
	
	# ─── Letterbox inferior ──────────────────
	_letterbox_bottom = ColorRect.new()
	_letterbox_bottom.color = Color.BLACK
	_letterbox_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_letterbox_bottom.offset_top = - letterbox_height_bottom
	_letterbox_bottom.z_index = 1
	add_child(_letterbox_bottom)
	
	# ─── Contenedor superior (HUD) ──────────────────────────────────────────
	_top_container = MarginContainer.new()
	_top_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_container.add_theme_constant_override("margin_top", 6)
	_top_container.add_theme_constant_override("margin_left", 20)
	_top_container.add_theme_constant_override("margin_right", 20)
	_letterbox_top.add_child(_top_container)

	var top_vbox := VBoxContainer.new()
	top_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_vbox.add_theme_constant_override("separation", 2)
	_top_container.add_child(top_vbox)

	# ─── Rounds ganados ───────────────────────────────────────────────────
	var rounds_hbox := HBoxContainer.new()
	rounds_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rounds_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rounds_hbox.add_theme_constant_override("separation", 8)
	top_vbox.add_child(rounds_hbox)

	_p1_rounds_label = Label.new()
	_p1_rounds_label.text = "W: 0"
	_p1_rounds_label.add_theme_font_override("font", _font_announcer)
	_p1_rounds_label.add_theme_font_size_override("font_size", 12)
	_p1_rounds_label.add_theme_color_override("font_color", COLOR_P1)
	_p1_rounds_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_p1_rounds_label.add_theme_constant_override("outline_size", 2)
	rounds_hbox.add_child(_p1_rounds_label)

	var vs_label := Label.new()
	vs_label.text = "VS"
	vs_label.add_theme_font_override("font", _font_title)
	vs_label.add_theme_font_size_override("font_size", 12)
	vs_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	rounds_hbox.add_child(vs_label)

	_p2_rounds_label = Label.new()
	_p2_rounds_label.text = "W: 0"
	_p2_rounds_label.add_theme_font_override("font", _font_announcer)
	_p2_rounds_label.add_theme_font_size_override("font_size", 12)
	_p2_rounds_label.add_theme_color_override("font_color", COLOR_P2)
	_p2_rounds_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_p2_rounds_label.add_theme_constant_override("outline_size", 2)
	rounds_hbox.add_child(_p2_rounds_label)

	# ─── Fila de nombres + Barras ──────────────────────────────────────────
	var main_hbox := HBoxContainer.new()
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_theme_constant_override("separation", 10)
	top_vbox.add_child(main_hbox)

	# Lado izquierdo P1
	var p1_col := VBoxContainer.new()
	p1_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p1_col.add_theme_constant_override("separation", 1)
	main_hbox.add_child(p1_col)

	_p1_name_label = Label.new()
	_p1_name_label.text = "P1"
	_p1_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_p1_name_label.add_theme_font_override("font", _font_title)
	_p1_name_label.add_theme_font_size_override("font_size", 16)
	_p1_name_label.add_theme_color_override("font_color", COLOR_P1)
	_p1_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_p1_name_label.add_theme_constant_override("outline_size", 3)
	p1_col.add_child(_p1_name_label)

	var p1_wrap := _make_bar_wrap(COLOR_P1)
	p1_col.add_child(p1_wrap)
	_p1_health_bar = ProgressBar.new()
	_p1_health_bar.custom_minimum_size = Vector2(200, 16)
	_p1_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p1_health_bar.show_percentage = false
	_p1_health_bar.min_value = 0
	_p1_health_bar.max_value = 100
	_p1_health_bar.value = 100
	_p1_health_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	_p1_health_bar.add_theme_stylebox_override("background", _make_bg_style())
	_p1_health_bar.add_theme_stylebox_override("fill", _make_fill_style(COLOR_P1))
	p1_wrap.add_child(_p1_health_bar)

	_p1_hp_text = Label.new()
	_p1_hp_text.text = "100"
	_p1_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_p1_hp_text.add_theme_font_override("font", _font_ui)
	_p1_hp_text.add_theme_font_size_override("font_size", 10)
	_p1_hp_text.add_theme_color_override("font_color", COLOR_P1)
	_p1_hp_text.add_theme_constant_override("outline_size", 1)
	p1_col.add_child(_p1_hp_text)

	# Lado derecho P2
	var p2_col := VBoxContainer.new()
	p2_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p2_col.add_theme_constant_override("separation", 1)
	main_hbox.add_child(p2_col)

	_p2_name_label = Label.new()
	_p2_name_label.text = "P2"
	_p2_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_p2_name_label.add_theme_font_override("font", _font_title)
	_p2_name_label.add_theme_font_size_override("font_size", 16)
	_p2_name_label.add_theme_color_override("font_color", COLOR_P2)
	_p2_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_p2_name_label.add_theme_constant_override("outline_size", 3)
	p2_col.add_child(_p2_name_label)

	var p2_wrap := _make_bar_wrap(COLOR_P2)
	p2_col.add_child(p2_wrap)
	_p2_health_bar = ProgressBar.new()
	_p2_health_bar.custom_minimum_size = Vector2(200, 16)
	_p2_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p2_health_bar.show_percentage = false
	_p2_health_bar.min_value = 0
	_p2_health_bar.max_value = 100
	_p2_health_bar.value = 100
	_p2_health_bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END
	_p2_health_bar.add_theme_stylebox_override("background", _make_bg_style())
	_p2_health_bar.add_theme_stylebox_override("fill", _make_fill_style(COLOR_P2))
	p2_wrap.add_child(_p2_health_bar)

	_p2_hp_text = Label.new()
	_p2_hp_text.text = "100"
	_p2_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_p2_hp_text.add_theme_font_override("font", _font_ui)
	_p2_hp_text.add_theme_font_size_override("font_size", 10)
	_p2_hp_text.add_theme_color_override("font_color", COLOR_P2)
	_p2_hp_text.add_theme_constant_override("outline_size", 1)
	p2_col.add_child(_p2_hp_text)

	# ─── Mensajes ────────────────────────────────────────────────────────────
	_msg_container = Control.new()
	_msg_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_msg_container.custom_minimum_size = Vector2(400, 100)
	add_child(_msg_container)

	_combo_label = Label.new()
	_combo_label.text = ""
	_combo_label.visible = false
	_combo_label.anchor_left = 0.5
	_combo_label.anchor_top = 0.5
	_combo_label.anchor_right = 0.5
	_combo_label.anchor_bottom = 0.5
	_combo_label.offset_left = -200
	_combo_label.offset_top = -50
	_combo_label.offset_right = 200
	_combo_label.offset_bottom = 0
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.z_index = 10
	_combo_label.add_theme_font_override("font", _font_ui)
	_combo_label.add_theme_font_size_override("font_size", 32)
	_combo_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	_combo_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_combo_label.add_theme_constant_override("outline_size", 3)
	_msg_container.add_child(_combo_label)

	# ─── Historial de Inpu	ts ───────────────────────────────────────────────
	_bottom_hud = MarginContainer.new()
	_bottom_hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_bottom_hud.add_theme_constant_override("margin_left", 10)
	_bottom_hud.add_theme_constant_override("margin_bottom", int(letterbox_height_bottom + 6))
	add_child(_bottom_hud)

	_input_history_label = RichTextLabel.new()
	_input_history_label.custom_minimum_size = Vector2(140, 100)
	_input_history_label.scroll_active = false
	_input_history_label.bbcode_enabled = true
	_input_history_label.add_theme_font_override("normal_font", _font_ui)
	_input_history_label.add_theme_font_size_override("normal_font_size", 10)
	_input_history_label.add_theme_color_override("default_color", COLOR_NEUTRAL)
	_input_history_label.text = ""
	_bottom_hud.add_child(_input_history_label)

# ─── Helpers de estilo ───────────────────────────────────────────────────────
func _make_bar_wrap(accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = accent
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel

func _make_bg_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	s.corner_radius_top_left = 2
	s.corner_radius_top_right = 2
	s.corner_radius_bottom_left = 2
	s.corner_radius_bottom_right = 2
	return s

func _make_fill_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = 2
	s.corner_radius_top_right = 2
	s.corner_radius_bottom_left = 2
	s.corner_radius_bottom_right = 2
	s.border_color = Color(1, 1, 1, 0.2)
	s.border_width_top = 1
	s.border_width_bottom = 1
	return s

func _init_letterbox_anim() -> void:
	var w: float = get_viewport().get_visible_rect().size.x
	_letterbox_top.position.x = -w # P1: fuera por la izquierda
	_letterbox_bottom.position.x = w # P2: fuera por la derecha
	if _bottom_hud:
		_bottom_hud.position.x = w
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_letterbox_top, "position:x", 0.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_letterbox_bottom, "position:x", 0.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _bottom_hud:
		tw.tween_property(_bottom_hud, "position:x", 0.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _check_letterbox_out() -> void:
	if _letterbox_out_played:
		return
	var mm := get_node_or_null("../MatchManager")
	if not mm:
		mm = get_node_or_null("/root/MatchManager")
	if mm and mm.get("_phase") == "MATCH_END":
		_letterbox_out_played = true
		var w: float = get_viewport().get_visible_rect().size.x
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_letterbox_top, "position:x", -w, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(_letterbox_bottom, "position:x", w, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		if _bottom_hud:
			tw.tween_property(_bottom_hud, "position:x", w, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

# side: 1 = P1 (entra por la izquierda), 2 = P2 (entra por la derecha)
func show_headline(text: String, side: int, force: bool = true) -> void:
	if not _combo_label:
		return
	# Combo en curso sin forzar: solo actualiza el número en el sitio
	if _headline_tween and _headline_tween.is_valid() and _headline_tween.is_running() and not force:
		_combo_label.text = text
		return
	if _headline_tween and _headline_tween.is_valid():
		_headline_tween.kill()
	_combo_label.text = text
	_combo_label.visible = true
	# ── Autocalibración: medimos el desvío del origen del label respecto
	#    al centro REAL de la pantalla (el contenedor lo desplaza +200px).
	_combo_label.position.x = 0.0
	var vp_w: float = get_viewport().get_visible_rect().size.x
	var base_x: float = (_combo_label.global_position.x + _combo_label.size.x * 0.5) - (vp_w * 0.5)
	var dir_sign: float = -1.0 if side == 1 else 1.0
	var rest_x: float = (0.30 * vp_w * dir_sign) - base_x
	var off_x: float = (0.85 * vp_w * dir_sign) - base_x
	_combo_label.position.x = off_x
	_headline_tween = create_tween()
	_headline_tween.tween_property(_combo_label, "position:x", rest_x, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_headline_tween.tween_interval(0.55)
	_headline_tween.tween_property(_combo_label, "position:x", off_x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_headline_tween.tween_callback(func(): _combo_label.visible = false)

# ─── Resolución de jugadores ────────────────────────────────────────────────
func _resolve_players() -> void:
	if not p1_body:
		if not player1.is_empty() and has_node(player1):
			p1_body = get_node(player1) as FighterBody
		elif has_node("../Player1"):
			p1_body = get_node("../Player1") as FighterBody

	if not p2_body:
		if not player2.is_empty() and has_node(player2):
			p2_body = get_node(player2) as FighterBody
		elif has_node("../AI"):
			p2_body = get_node("../AI") as FighterBody

	if p1_body:
		if p1_body.has_signal("health_changed") and not p1_body.health_changed.is_connected(_on_p1_health_changed):
			p1_body.health_changed.connect(_on_p1_health_changed)
		_p1_target_hp = float(p1_body.stats.get("current_health", 100))
		_p1_display_hp = _p1_target_hp
		_update_p1_name()
		_update_rounds()

	if p2_body:
		if p2_body.has_signal("health_changed") and not p2_body.health_changed.is_connected(_on_p2_health_changed):
			p2_body.health_changed.connect(_on_p2_health_changed)
		_p2_target_hp = float(p2_body.stats.get("current_health", 100))
		_p2_display_hp = _p2_target_hp
		_update_p2_name()
		_update_rounds()

# ─── Señales de vida ─────────────────────────────────────────────────────────
func _on_p1_health_changed(cur_hp: int, _max_hp: int) -> void:
	_p1_target_hp = float(cur_hp)
	_p1_flash = 1.0

func _on_p2_health_changed(cur_hp: int, _max_hp: int) -> void:
	_p2_target_hp = float(cur_hp)
	_p2_flash = 1.0

# ─── Actualización de nombres ────────────────────────────────────────────────
func _update_p1_name() -> void:
	if not _p1_name_label or not p1_body:
		return
	_p1_name_label.text = p1_body.character_name.to_upper() if p1_body.character_name != "" else p1_body.name.to_upper()

func _update_p2_name() -> void:
	if not _p2_name_label or not p2_body:
		return
	_p2_name_label.text = p2_body.character_name.to_upper() if p2_body.character_name != "" else "IA (RIVAL)"

func _update_rounds() -> void:
	if not _p1_rounds_label or not _p2_rounds_label:
		return
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		_p1_rounds_label.text = "W: %d" % int(gm.p1_wins)
		_p2_rounds_label.text = "W: %d" % int(gm.p2_wins)

# ─── Proceso Principal ───────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not p1_body or not p2_body:
		_resolve_players()

	_update_p1_name()
	_update_p2_name()
	_update_health_bars(delta)
	_update_rounds()
	_update_input_history()
	_check_letterbox_out()

# ─── Barras de vida con Lerp y Flash ────────────────────────────────────────
func _update_health_bars(delta: float) -> void:
	if p1_body and p1_body.stats:
		var max_hp1 := float(p1_body.stats.get("max_health", 100))
		_p1_target_hp = float(p1_body.stats.get("current_health", 100))
		_p1_display_hp = lerp(_p1_display_hp, _p1_target_hp, 14.0 * delta)
		_p1_flash = max(0.0, _p1_flash - 6.0 * delta)
		_p1_health_bar.max_value = max_hp1
		_p1_health_bar.value = clamp(_p1_display_hp, 0.0, max_hp1)
		_p1_hp_text.text = str(int(ceil(_p1_target_hp)))
		if _p1_flash > 0.0:
			_p1_health_bar.modulate = Color(1, 0.3, 0.3, 1)
		else:
			_p1_health_bar.modulate = Color.WHITE

	if p2_body and p2_body.stats:
		var max_hp2 := float(p2_body.stats.get("max_health", 100))
		_p2_target_hp = float(p2_body.stats.get("current_health", 100))
		_p2_display_hp = lerp(_p2_display_hp, _p2_target_hp, 14.0 * delta)
		_p2_flash = max(0.0, _p2_flash - 6.0 * delta)
		_p2_health_bar.max_value = max_hp2
		_p2_health_bar.value = clamp(_p2_display_hp, 0.0, max_hp2)
		_p2_hp_text.text = str(int(ceil(_p2_target_hp)))
		if _p2_flash > 0.0:
			_p2_health_bar.modulate = Color(1, 0.3, 0.3, 1)
		else:
			_p2_health_bar.modulate = Color.WHITE

func _get_match_manager() -> Node:
	if is_instance_valid(_match_manager):
		return _match_manager
	# MatchManager vive como hermano de BattleUI bajo la raíz de node_3d.tscn
	_match_manager = get_node_or_null("../MatchManager")
	if not _match_manager:
		_match_manager = get_tree().current_scene.get_node_or_null("MatchManager")
	return _match_manager

# ─── Historial de Inputs ─────────────────────────────────────────────────────
func _update_input_history() -> void:
	if not _input_history_label or not p1_body or not p1_body.player_input:
		return
	var buffer = p1_body.player_input._input_buffer
	var active_frames: Array = []
	for i in range(mini(buffer.size(), 10)):
		var state = buffer[i]
		var active_keys: Array[String] = []
		if state.get("dir_x", 0.0) < -0.1:
			active_keys.append("[color=yellow]◀[/color]")
		if state.get("dir_x", 0.0) > 0.1:
			active_keys.append("[color=yellow]▶[/color]")
		if state.get("crouch", false):
			active_keys.append("[color=cyan]▼[/color]")
		if state.get("jump", false):
			active_keys.append("[color=lime]▲[/color]")
		if state.get("heavy_punch", false):
			active_keys.append("[color=red]HP[/color]")
		if state.get("light_punch", false):
			active_keys.append("[color=orange]LP[/color]")
		if state.get("heavy_kick", false):
			active_keys.append("[color=blue]HK[/color]")
		if state.get("light_kick", false):
			active_keys.append("[color=cyan]LK[/color]")
		if state.get("guard", false):
			active_keys.append("[color=white]GD[/color]")
		if active_keys.size() > 0:
			active_frames.append(str(i) + "f: " + " ".join(active_keys))
		if active_frames.size() >= 6:
			break
	_input_history_label.text = "\n".join(active_frames)
