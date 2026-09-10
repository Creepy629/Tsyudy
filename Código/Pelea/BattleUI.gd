extends CanvasLayer

@export var player1: NodePath
@export var player2: NodePath

# ── Knobs de Profundidad 3D (Ajusta a ojo en el inspector) ────────────────
@export var combo_3d_pixel_size: float = 0.006
@export var combo_3d_depth: float = 2.5
@export var letterbox_height_top: float = 75.0
@export var letterbox_height_bottom: float = 75.0
@export var hud_background_opacity: float = 0.75

# ── Referencias de jugadores ─────────────────────────────────────────────
var p1_body: FighterBody
var p2_body: FighterBody

# ── Nodos UI 2D (HUD) ────────────────────────────────────────────────────
var _letterbox_top: ColorRect
var _letterbox_bottom: ColorRect
var _top_container: MarginContainer
var _msg_container: Control
var _p1_base_rect: ColorRect
var _p1_trail_rect: ColorRect
var _p1_fill_rect: ColorRect
var _p2_base_rect: ColorRect
var _p2_trail_rect: ColorRect
var _p2_fill_rect: ColorRect
var _p1_name_label: Label
var _p2_name_label: Label
var _p1_pips: Array[Panel] = []
var _p2_pips: Array[Panel] = []
var _combo_label: Label
var _input_history_label: RichTextLabel
var _bottom_hud: MarginContainer
var _letterbox_out_played := false
var _headline_tween: Tween = null
var _last_w1 := -1
var _last_w2 := -1
var _last_input_text := ""
var _gm_cache: Node = null

# ── Nodo 3D (Solo para el contador de hits) ──────────────────────────────
var _combo_counter_3d: Label3D = null
var _current_combo_count: int = 0

# ── Fuentes ──────────────────────────────────────────────────────────────
var _font_title: Font
var _font_ui: Font
var _font_announcer: Font

# ── Animación de vida ────────────────────────────────────────────────────
var _p1_target_hp: float = 100.0
var _p2_target_hp: float = 100.0
var _p1_display_hp: float = 100.0
var _p2_display_hp: float = 100.0
var _p1_trail_hp: float = 100.0
var _p2_trail_hp: float = 100.0
var _p1_flash: float = 0.0
var _p2_flash: float = 0.0

# ── Colores ──────────────────────────────────────────────────────────────
const COLOR_BAR := Color(0, 0, 0, 0)
const COLOR_FILL := Color("3d0086e2")
const COLOR_TRAIL := Color("#E30103")
const COLOR_NEUTRAL := Color("7d0015b8")
const COLOR_BG := Color(0.07, 0.05, 0.11, 0.9)
const COLOR_BORDER := Color(0.0, 0.0, 0.0, 1.0)
const COLOR_P1 := Color("#8CC63E")
const COLOR_P2 := Color("#E30103")

# ── Knobs de forma ───────────────────────────────────────────────────────
const BAR_SKEW: float = 0.22
const BAR_HEIGHT: int = 22
const WIN_PIPS: int = 3

func _ready() -> void:
	_load_fonts()
	_setup_ui()
	_resolve_players()
	_init_letterbox_anim()
	call_deferred("_setup_3d_combo_counter")

func _load_fonts() -> void:
	# Fuente Strive para títulos, nombres y mensajes
	if ResourceLoader.exists("res://Fuentes/Strive.otf"):
		_font_title = ResourceLoader.load("res://Fuentes/Strive.otf") as Font
	else:
		_font_title = ResourceLoader.load("res://Fuentes/DirtyBrush.ttf") as Font
	
	_font_ui = ResourceLoader.load("res://Fuentes/sing_14l.ttf") as Font
	_font_announcer = ResourceLoader.load("res://Fuentes/Mom«t___.ttf") as Font
	
	if _font_announcer == null or _font_announcer == ThemeDB.fallback_font:
		var dir := DirAccess.open("res://Fuentes/")
		if dir != null:
			dir.list_dir_begin()
			var entry: String = dir.get_next()
			while entry != "":
				if not dir.current_is_dir() and entry.begins_with("Mom") and entry.ends_with(".ttf"):
					_font_announcer = ResourceLoader.load("res://Fuentes/" + entry) as Font
					break
				entry = dir.get_next()

# ── Setup UI 2D ──────────────────────────────────────────────────────────
func _setup_ui() -> void:
	_letterbox_top = ColorRect.new()
	_letterbox_top.color = Color.BLACK
	_letterbox_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_letterbox_top.offset_bottom = letterbox_height_top
	_letterbox_top.z_index = 1
	add_child(_letterbox_top)

	_letterbox_bottom = ColorRect.new()
	_letterbox_bottom.color = Color.BLACK
	_letterbox_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_letterbox_bottom.offset_top = -letterbox_height_bottom
	_letterbox_bottom.z_index = 1
	add_child(_letterbox_bottom)

	_top_container = MarginContainer.new()
	_top_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_container.add_theme_constant_override("margin_top", 8)
	_top_container.add_theme_constant_override("margin_left", 20)
	_top_container.add_theme_constant_override("margin_right", 20)
	_letterbox_top.add_child(_top_container)

	var main_hbox := HBoxContainer.new()
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_theme_constant_override("separation", 12)
	_top_container.add_child(main_hbox)

	var p1_wrap := _make_bar_wrap(-BAR_SKEW)
	main_hbox.add_child(p1_wrap)
	var p1_root := Control.new()
	p1_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p1_wrap.add_child(p1_root)

	_p1_base_rect = _make_layer_rect(COLOR_BAR, 0.0, 1.0)
	p1_root.add_child(_p1_base_rect)
	_p1_trail_rect = _make_layer_rect(COLOR_TRAIL, 0.0, 1.0)
	p1_root.add_child(_p1_trail_rect)
	_p1_fill_rect = _make_layer_rect(COLOR_FILL, 0.0, 1.0)
	p1_root.add_child(_p1_fill_rect)

	_p1_name_label = Label.new()
	_p1_name_label.text = "P1"
	_p1_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_p1_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_p1_name_label.add_theme_font_override("font", _font_title)
	_p1_name_label.add_theme_font_size_override("font_size", 16)
	_p1_name_label.add_theme_color_override("font_color", Color(0.894, 0.839, 1.0, 0.784))
	_p1_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_p1_name_label.add_theme_constant_override("outline_size", 3)
	p1_wrap.add_child(_p1_name_label)

	var center_col := VBoxContainer.new()
	center_col.custom_minimum_size = Vector2(110, 0)
	center_col.alignment = BoxContainer.ALIGNMENT_CENTER
	center_col.add_theme_constant_override("separation", 3)
	main_hbox.add_child(center_col)

	var vs_label := Label.new()
	vs_label.text = "VS"
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.add_theme_font_override("font", _font_title)
	vs_label.add_theme_font_size_override("font_size", 22)
	vs_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	vs_label.add_theme_color_override("font_outline_color", Color.BLACK)
	vs_label.add_theme_constant_override("outline_size", 3)
	center_col.add_child(vs_label)

	var pips_hbox := HBoxContainer.new()
	pips_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pips_hbox.add_theme_constant_override("separation", 5)
	center_col.add_child(pips_hbox)
	for i in range(WIN_PIPS):
		var pip := _make_pip()
		_p1_pips.append(pip)
		pips_hbox.add_child(pip)
	var pip_spacer := Control.new()
	pip_spacer.custom_minimum_size = Vector2(10, 0)
	pips_hbox.add_child(pip_spacer)
	for i in range(WIN_PIPS):
		var pip := _make_pip()
		_p2_pips.append(pip)
		pips_hbox.add_child(pip)

	var p2_wrap := _make_bar_wrap(BAR_SKEW)
	main_hbox.add_child(p2_wrap)
	var p2_root := Control.new()
	p2_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p2_wrap.add_child(p2_root)

	_p2_base_rect = _make_layer_rect(COLOR_BAR, 0.0, 1.0)
	p2_root.add_child(_p2_base_rect)
	_p2_trail_rect = _make_layer_rect(COLOR_TRAIL, 0.0, 1.0)
	p2_root.add_child(_p2_trail_rect)
	_p2_fill_rect = _make_layer_rect(COLOR_FILL, 0.0, 1.0)
	p2_root.add_child(_p2_fill_rect)

	_p2_name_label = Label.new()
	_p2_name_label.text = "P2"
	_p2_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_p2_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_p2_name_label.add_theme_font_override("font", _font_title)
	_p2_name_label.add_theme_font_size_override("font_size", 16)
	_p2_name_label.add_theme_color_override("font_color", Color(0.894, 0.839, 1.0, 0.784))
	_p2_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_p2_name_label.add_theme_constant_override("outline_size", 3)
	p2_wrap.add_child(_p2_name_label)

	# ─── Mensajes pegados al letterbox top ────────────────────────────────────
	_msg_container = Control.new()
	_msg_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_msg_container.offset_top = letterbox_height_top + 10.0
	_msg_container.offset_bottom = letterbox_height_top + 110.0
	_msg_container.offset_left = -200.0
	_msg_container.offset_right = 200.0
	add_child(_msg_container)

	_combo_label = Label.new()
	_combo_label.text = ""
	_combo_label.visible = false
	_combo_label.anchor_left = 0.0
	_combo_label.anchor_top = 0.0
	_combo_label.anchor_right = 1.0
	_combo_label.anchor_bottom = 1.0
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combo_label.z_index = 10
	_combo_label.add_theme_font_override("font", _font_title)
	_combo_label.add_theme_font_size_override("font_size", 48)
	_combo_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	_combo_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_combo_label.add_theme_constant_override("outline_size", 5)
	_msg_container.add_child(_combo_label)

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

func _setup_3d_combo_counter() -> void:
	var root_3d := get_tree().current_scene as Node3D
	if not root_3d:
		root_3d = get_node_or_null("/root/Pelea") as Node3D
	if not root_3d: return

	_combo_counter_3d = Label3D.new()
	_combo_counter_3d.text = ""
	_combo_counter_3d.visible = false
	_combo_counter_3d.pixel_size = combo_3d_pixel_size
	_combo_counter_3d.font_size = 90
	_combo_counter_3d.font = _font_title
	_combo_counter_3d.modulate = COLOR_NEUTRAL
	_combo_counter_3d.outline_size = 10
	_combo_counter_3d.set("outline_color", Color.BLACK)
	_combo_counter_3d.no_depth_test = true
	_combo_counter_3d.render_priority = -1
	root_3d.add_child(_combo_counter_3d)

func _make_bar_wrap(skew: float) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BORDER
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	style.skew = Vector2(skew, 0.0)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel

func _make_layer_rect(color: Color, a_left: float, a_right: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.anchor_left = a_left
	r.anchor_right = a_right
	r.anchor_top = 0.0
	r.anchor_bottom = 1.0
	r.offset_left = 0.0
	r.offset_right = 0.0
	r.offset_top = 0.0
	r.offset_bottom = 0.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _make_pip() -> Panel:
	var pip := Panel.new()
	pip.custom_minimum_size = Vector2(10, 10)
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_NEUTRAL
	s.border_color = Color(0, 0, 0, 1)
	s.set_border_width_all(2)
	s.set_corner_radius_all(5)
	pip.add_theme_stylebox_override("panel", s)
	pip.modulate = Color(0.25, 0.2, 0.35, 1.0)
	return pip

func _init_letterbox_anim() -> void:
	var w: float = get_viewport().get_visible_rect().size.x
	_letterbox_top.position.x = -w
	_letterbox_bottom.position.x = w
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

func show_headline(text: String, side: int, force: bool = true) -> void:
	if not _combo_label:
		return
	if _headline_tween and _headline_tween.is_valid() and _headline_tween.is_running() and not force:
		_combo_label.text = text
		return

	if _headline_tween and _headline_tween.is_valid():
		_headline_tween.kill()

	_combo_label.text = text
	_combo_label.visible = true
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

func update_combo(count: int) -> void:
	if not is_instance_valid(_combo_counter_3d):
		return
	_current_combo_count = count
	if count < 2:
		_combo_counter_3d.visible = false
		return

	_combo_counter_3d.text = str(count) + " HITS"
	_combo_counter_3d.visible = true

func _resolve_players() -> void:
	if not p1_body:
		p1_body = _find_fighter(1)
	if not p2_body:
		p2_body = _find_fighter(2)

	if p1_body:
		if p1_body.has_signal("health_changed") and not p1_body.health_changed.is_connected(_on_p1_health_changed):
			p1_body.health_changed.connect(_on_p1_health_changed)
		_p1_target_hp = float(p1_body.stats.get("current_health", 100))
		_p1_display_hp = _p1_target_hp
		_p1_trail_hp = _p1_target_hp
		_update_p1_name()
		_update_rounds()
	if p2_body:
		if p2_body.has_signal("health_changed") and not p2_body.health_changed.is_connected(_on_p2_health_changed):
			p2_body.health_changed.connect(_on_p2_health_changed)
		_p2_target_hp = float(p2_body.stats.get("current_health", 100))
		_p2_display_hp = _p2_target_hp
		_p2_trail_hp = _p2_target_hp
		_update_p2_name()
		_update_rounds()

func _find_fighter(slot: int) -> FighterBody:
	# 1) NodePath exportado en inspector (si está puesto, manda)
	var np: NodePath = player1 if slot == 1 else player2
	if not np.is_empty() and has_node(np):
		var via_path := get_node(np) as FighterBody
		if via_path:
			return via_path
	# 2) Nombres relativos legacy
	var rel := get_node_or_null("../Player1" if slot == 1 else "../AI") as FighterBody
	if rel:
		return rel
	# 3) Escaneo por fighter_slot: inmune a renames de nodo
	var root := get_tree().current_scene
	if root == null:
		return null
	var fallback: FighterBody = null
	for n: Node in root.find_children("*", "FighterBody", true, false):
		var fb := n as FighterBody
		if not fb:
			continue
		if fb.fighter_slot == slot:
			return fb
		if fallback == null:
			if slot == 2 and fb.is_ai and fb != p1_body:
				fallback = fb
			elif slot == 1 and not fb.is_ai:
				fallback = fb
	return fallback

func _update_p1_name() -> void:
	if not _p1_name_label or not p1_body:
		return
	var src: String = p1_body.character_name if p1_body.character_name != "" else String(p1_body.name)
	var desired: String = src.to_upper()
	if desired != _p1_name_label.text:
		_p1_name_label.text = desired

func _update_p2_name() -> void:
	if not _p2_name_label or not p2_body:
		return
	var src: String = p2_body.character_name if p2_body.character_name != "" else String(p2_body.name)
	var desired: String = src.to_upper()
	if desired != _p2_name_label.text:
		_p2_name_label.text = desired

func _on_p1_health_changed(cur_hp: int, _max_hp: int) -> void:
	_p1_target_hp = float(cur_hp)
	_p1_flash = 1.0

func _on_p2_health_changed(cur_hp: int, _max_hp: int) -> void:
	_p2_target_hp = float(cur_hp)
	_p2_flash = 1.0

func _update_rounds() -> void:
	if _gm_cache == null:
		_gm_cache = get_node_or_null("/root/GameManager")
	if _gm_cache == null:
		return
	var w1: int = clampi(int(_gm_cache.get("p1_wins")), 0, WIN_PIPS)
	var w2: int = clampi(int(_gm_cache.get("p2_wins")), 0, WIN_PIPS)
	if w1 == _last_w1 and w2 == _last_w2:
		return
	_last_w1 = w1
	_last_w2 = w2
	for i in range(_p1_pips.size()):
		(_p1_pips[i] as Panel).modulate = Color.WHITE if w1 > i else Color(0.25, 0.2, 0.35, 1.0)
	for i in range(_p2_pips.size()):
		(_p2_pips[i] as Panel).modulate = Color.WHITE if w2 > i else Color(0.25, 0.2, 0.35, 1.0)

func _process(delta: float) -> void:
	if not p1_body or not p2_body:
		_resolve_players()
	_update_p1_name()
	_update_p2_name()
	_update_health_bars(delta)
	_update_rounds()
	_update_input_history()
	_check_letterbox_out()

func _update_health_bars(delta: float) -> void:
	if p1_body and p1_body.stats:
		var maxHp1 := float(p1_body.stats.get("max_health", 100))
		_p1_target_hp = float(p1_body.stats.get("current_health", 100))
		_p1_display_hp = lerp(_p1_display_hp, _p1_target_hp, 14.0 * delta)
		_p1_trail_hp = maxf(lerp(_p1_trail_hp, _p1_target_hp, 1.5 * delta), _p1_display_hp)
		_p1_flash = max(0.0, _p1_flash - 6.0 * delta)
		var r1: float = clampf(_p1_display_hp / maxHp1, 0.0, 1.0)
		var t1: float = clampf(_p1_trail_hp / maxHp1, 0.0, 1.0)
		_p1_fill_rect.anchor_left = 0.0
		_p1_fill_rect.anchor_right = r1
		_p1_trail_rect.anchor_left = 0.0
		_p1_trail_rect.anchor_right = t1
	if p2_body and p2_body.stats:
		var maxHp2 := float(p2_body.stats.get("max_health", 100))
		_p2_target_hp = float(p2_body.stats.get("current_health", 100))
		_p2_display_hp = lerp(_p2_display_hp, _p2_target_hp, 14.0 * delta)
		_p2_trail_hp = maxf(lerp(_p2_trail_hp, _p2_target_hp, 1.5 * delta), _p2_display_hp)
		_p2_flash = max(0.0, _p2_flash - 6.0 * delta)
		var r2: float = clampf(_p2_display_hp / maxHp2, 0.0, 1.0)
		var t2: float = clampf(_p2_trail_hp / maxHp2, 0.0, 1.0)
		_p2_fill_rect.anchor_left = 1.0 - r2
		_p2_fill_rect.anchor_right = 1.0
		_p2_trail_rect.anchor_left = 1.0 - t2
		_p2_trail_rect.anchor_right = 1.0

func _update_3d_combo_position() -> void:
	if not is_instance_valid(_combo_counter_3d) or not _combo_counter_3d.visible:
		return

	var cam := get_viewport().get_camera_3d()
	if not cam:
		return

	var vp_size := get_viewport().get_visible_rect().size
	var screen_pos := Vector2(vp_size.x * 0.82, vp_size.y * 0.45)
	var world_pos := cam.project_position(screen_pos, combo_3d_depth)
	_combo_counter_3d.global_position = world_pos

	var cam_up := cam.global_transform.basis.y
	_combo_counter_3d.look_at(cam.global_position, cam_up)

func _update_input_history() -> void:
	if not _input_history_label or not p1_body or not p1_body.player_input:
		return
	var buffer: Array = p1_body.player_input._input_buffer
	var active_frames: Array = []
	for i in range(mini(buffer.size(), 10)):
		var state: Dictionary = buffer[i]
		var active_keys: Array[String] = []
		if float(state.get("dir_x", 0.0)) < -0.1:
			active_keys.append("[color=yellow]◀[/color]")
		if float(state.get("dir_x", 0.0)) > 0.1:
			active_keys.append("[color=yellow]▶[/color]")
		if bool(state.get("crouch", false)):
			active_keys.append("[color=cyan]▼[/color]")
		if bool(state.get("jump", false)):
			active_keys.append("[color=lime]▲[/color]")
		if bool(state.get("heavy_punch", false)):
			active_keys.append("[color=red]HP[/color]")
		if bool(state.get("light_punch", false)):
			active_keys.append("[color=orange]LP[/color]")
		if bool(state.get("heavy_kick", false)):
			active_keys.append("[color=blue]HK[/color]")
		if bool(state.get("light_kick", false)):
			active_keys.append("[color=cyan]LK[/color]")
		if bool(state.get("guard", false)):
			active_keys.append("[color=white]GD[/color]")
		if active_keys.size() > 0:
			active_frames.append(str(i) + "f: " + " ".join(active_keys))
		if active_frames.size() >= 6:
			break
	var new_text: String = "\n".join(active_frames)
	if new_text != _last_input_text:
		_last_input_text = new_text
		_input_history_label.text = new_text
