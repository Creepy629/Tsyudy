extends Control
class_name VSScreen

@export var battle_scene_path: String = "res://Escenas/Pelea/Pelea.tscn"
@export var min_display_time: float = 2.0
@export var portrait_size: float = 80.0
@export var portrait_margin: float = 20.0
@export var preload_fighter_sprites: bool = true

var _packed: PackedScene = null
var _elapsed: float = 0.0
var _switching: bool = false
var _load_failed: bool = false
var _scene_done: bool = false
var _scene_progress: float = 0.0
var _tex_queue: Array = []
var _tex_total: int = 0
var _tex_done: int = 0
var _fade: ColorRect
var _bar_fill: ColorRect
var _pct_label: Label
var _status_label: Label
var _vs_label: Label
var _left: TextureRect
var _right: TextureRect
var _font_title: Font
var _font_ui: Font

func _ready() -> void:
	_load_fonts()
	_build_ui()

	var gm: Node = get_node_or_null("/root/GameManager")
	var p1_name: String = "Kung Lao"
	var p2_name: String = "Scorpion"
	if gm != null:
		p1_name = str(gm.get("p1_character"))
		p2_name = str(gm.get("p2_character"))

	_left.texture = _load_portrait(p1_name)
	_right.texture = _load_portrait(p2_name)
	($NameLeft as Label).text = p1_name.to_upper()
	($NameRight as Label).text = p2_name.to_upper()

	ResourceLoader.load_threaded_request(battle_scene_path)
	if preload_fighter_sprites:
		_queue_character_textures(p1_name)
		_queue_character_textures(p2_name)
	_tex_total = _tex_queue.size()

func _load_fonts() -> void:
	_font_title = _load_font("res://Fuentes/DirtyBrush.ttf")
	_font_ui = _load_font("res://Fuentes/sing_14l.ttf")

func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Font:
			return res
	return ThemeDB.fallback_font

func _load_portrait(char_name: String) -> Texture2D:
	var base: String = "res://Personajes/%s/%sSpr/" % [char_name, char_name.replace(" ", "")]
	var path: String = base + "O2.png"
	if FileAccess.file_exists(path) or ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res
	return null

func _queue_character_textures(char_name: String) -> void:
	var base: String = "res://Personajes/%s/%sSpr/" % [char_name, char_name.replace(" ", "")]
	var dir := DirAccess.open(base)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			var clean_entry = entry.trim_suffix(".remap").trim_suffix(".import")
			if clean_entry.ends_with(".png") or clean_entry.ends_with(".jpg"):
				var path: String = base + clean_entry
				if not _tex_queue.has(path):
					ResourceLoader.load_threaded_request(path)
					_tex_queue.append(path)
		entry = dir.get_next()

func _process(delta: float) -> void:
	_elapsed += delta

	if not _scene_done and not _load_failed:
		var progress: Array = []
		var status: int = ResourceLoader.load_threaded_get_status(battle_scene_path, progress)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if progress.size() > 0:
				_scene_progress = float(progress[0])
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			_packed = ResourceLoader.load_threaded_get(battle_scene_path)
			_scene_progress = 1.0
			_scene_done = true
		else:
			_load_failed = true
			_scene_progress = 1.0

	for i in range(_tex_queue.size() - 1, -1, -1):
		var st: int = ResourceLoader.load_threaded_get_status(_tex_queue[i])
		if st == ResourceLoader.THREAD_LOAD_LOADED or st == ResourceLoader.THREAD_LOAD_FAILED:
			_tex_queue.remove_at(i)
			_tex_done += 1

	var tex_p: float = 1.0
	if _tex_total > 0:
		tex_p = float(_tex_done) / float(_tex_total)
	var overall: float = (_scene_progress + tex_p) * 0.5
	if _tex_total == 0:
		overall = _scene_progress

	if _bar_fill != null:
		_bar_fill.offset_right = -250.0 + 500.0 * overall
	if _pct_label != null:
		_pct_label.text = "%d%%" % int(overall * 100.0)
	if _status_label != null:
		if _load_failed:
			_status_label.text = "ERROR DE CARGA"
		elif _scene_done and _tex_queue.is_empty():
			_status_label.text = "LISTO"
		else:
			var dots: String = ""
			for i in range(int(_elapsed * 3.0) % 4):
				dots += "."
			_status_label.text = "CARGANDO" + dots

	var can_switch: bool = _scene_done and _tex_queue.is_empty()
	if can_switch and _elapsed >= min_display_time and not _switching:
		_switching = true
		var tw := create_tween()
		tw.tween_property(_fade, "color", Color(0, 0, 0, 1), 0.4)
		if _packed != null:
			tw.tween_callback(func() -> void: get_tree().change_scene_to_packed(_packed))
		else:
			tw.tween_callback(func() -> void: get_tree().change_scene_to_file(battle_scene_path))

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var slash_l := ColorRect.new()
	slash_l.color = Color(0.8, 0.1, 0.1, 0.16)
	slash_l.anchor_top = 0.5
	slash_l.anchor_bottom = 0.5
	slash_l.offset_left = -120.0
	slash_l.offset_right = 320.0
	slash_l.offset_top = -450.0
	slash_l.offset_bottom = 450.0
	slash_l.pivot_offset = Vector2(220.0, 450.0)
	slash_l.rotation = 0.3
	add_child(slash_l)

	var slash_r := ColorRect.new()
	slash_r.color = Color(0.1, 0.6, 0.9, 0.16)
	slash_r.anchor_left = 1.0
	slash_r.anchor_right = 1.0
	slash_r.anchor_top = 0.5
	slash_r.anchor_bottom = 0.5
	slash_r.offset_left = -320.0
	slash_r.offset_right = 120.0
	slash_r.offset_top = -450.0
	slash_r.offset_bottom = 450.0
	slash_r.pivot_offset = Vector2(220.0, 450.0)
	slash_r.rotation = -0.3
	add_child(slash_r)

	_left = _make_portrait()
	_left.anchor_top = 0.5
	_left.anchor_bottom = 0.5
	_left.offset_left = portrait_margin
	_left.offset_right = portrait_margin + portrait_size * 1.5
	_left.offset_top = -portrait_size
	_left.offset_bottom = portrait_size * 0.5
	_left.rotation = -0.06
	add_child(_left)

	_right = _make_portrait()
	_right.anchor_left = 1.0
	_right.anchor_right = 1.0
	_right.anchor_top = 0.5
	_right.anchor_bottom = 0.5
	_right.offset_left = -(portrait_margin + portrait_size * 1.5)
	_right.offset_right = -portrait_margin
	_right.offset_top = -portrait_size
	_right.offset_bottom = portrait_size * 0.5
	_right.rotation = 0.06
	_right.flip_h = true
	add_child(_right)

	_vs_label = Label.new()
	_vs_label.name = "VSLabel"
	_vs_label.text = "VS"
	_vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vs_label.anchor_left = 0.5
	_vs_label.anchor_right = 0.5
	_vs_label.anchor_top = 0.5
	_vs_label.anchor_bottom = 0.5
	_vs_label.offset_left = -80
	_vs_label.offset_top = -50
	_vs_label.offset_right = 80
	_vs_label.offset_bottom = 50
	_vs_label.pivot_offset = Vector2(80.0, 50.0)
	_vs_label.add_theme_font_override("font", _font_title)
	_vs_label.add_theme_font_size_override("font_size", 60)
	_vs_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.0))
	_vs_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_vs_label.add_theme_constant_override("outline_size", 4)
	add_child(_vs_label)

	var pulse := create_tween()
	pulse.set_loops()
	pulse.tween_property(_vs_label, "scale", Vector2(1.08, 1.08), 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_vs_label, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)

	var nl := Label.new()
	nl.name = "NameLeft"
	nl.anchor_top = 0.5
	nl.anchor_bottom = 0.5
	nl.offset_left = 10
	nl.offset_top = 160
	nl.offset_right = 200
	nl.offset_bottom = 200
	nl.add_theme_font_override("font", _font_ui)
	nl.add_theme_font_size_override("font_size", 22)
	nl.add_theme_color_override("font_color", Color.WHITE)
	nl.add_theme_color_override("font_outline_color", Color.BLACK)
	nl.add_theme_constant_override("outline_size", 2)
	add_child(nl)

	var nr := Label.new()
	nr.name = "NameRight"
	nr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nr.anchor_left = 1.0
	nr.anchor_right = 1.0
	nr.anchor_top = 0.5
	nr.anchor_bottom = 0.5
	nr.offset_left = -200
	nr.offset_top = 160
	nr.offset_right = -10
	nr.offset_bottom = 200
	nr.add_theme_font_override("font", _font_ui)
	nr.add_theme_font_size_override("font_size", 22)
	nr.add_theme_color_override("font_color", Color.WHITE)
	nr.add_theme_color_override("font_outline_color", Color.BLACK)
	nr.add_theme_constant_override("outline_size", 2)
	add_child(nr)

	var bar_frame := ColorRect.new()
	bar_frame.color = Color(0.3, 0.22, 0.12)
	bar_frame.anchor_left = 0.5
	bar_frame.anchor_right = 0.5
	bar_frame.anchor_top = 1.0
	bar_frame.anchor_bottom = 1.0
	bar_frame.offset_left = -254
	bar_frame.offset_right = 254
	bar_frame.offset_top = -44
	bar_frame.offset_bottom = -20
	add_child(bar_frame)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.12, 0.09, 0.05)
	bar_bg.anchor_left = 0.5
	bar_bg.anchor_right = 0.5
	bar_bg.anchor_top = 1.0
	bar_bg.anchor_bottom = 1.0
	bar_bg.offset_left = -250
	bar_bg.offset_right = 250
	bar_bg.offset_top = -40
	bar_bg.offset_bottom = -24
	add_child(bar_bg)

	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.85, 0.6, 0.1)
	_bar_fill.anchor_left = 0.5
	_bar_fill.anchor_right = 0.5
	_bar_fill.anchor_top = 1.0
	_bar_fill.anchor_bottom = 1.0
	_bar_fill.offset_left = -250
	_bar_fill.offset_right = -250
	_bar_fill.offset_top = -40
	_bar_fill.offset_bottom = -24
	add_child(_bar_fill)

	_pct_label = Label.new()
	_pct_label.anchor_left = 0.5
	_pct_label.anchor_right = 0.5
	_pct_label.anchor_top = 1.0
	_pct_label.anchor_bottom = 1.0
	_pct_label.offset_left = 260
	_pct_label.offset_right = 340
	_pct_label.offset_top = -44
	_pct_label.offset_bottom = -20
	_pct_label.add_theme_font_override("font", _font_ui)
	_pct_label.add_theme_font_size_override("font_size", 16)
	_pct_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.1))
	add_child(_pct_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.anchor_left = 0.5
	_status_label.anchor_right = 0.5
	_status_label.anchor_top = 1.0
	_status_label.anchor_bottom = 1.0
	_status_label.offset_left = -200
	_status_label.offset_right = 200
	_status_label.offset_top = -66
	_status_label.offset_bottom = -48
	_status_label.add_theme_font_override("font", _font_ui)
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	add_child(_status_label)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

func _make_portrait() -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return t
