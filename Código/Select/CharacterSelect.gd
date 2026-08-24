extends Node3D
class_name CharacterSelect

const PreviewScript: GDScript = preload("res://Código/Select/CharacterPreview.gd")

@export var stage_center: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var stage_width: float = 12.0
@export var portrait_height: float = 1.1
@export var pixels_per_meter: float = 170.0
@export var battle_scene_path: String = "res://Escenas/Pelea/VSScreen.tscn"
@export var sky_texture_path: String = "res://Texturas/Pelea/de_dust2.png"
@export var fog_enabled: bool = true
@export var fog_density: float = 0.03
@export var camera_sway_amp: float = 0.25
@export var camera_sway_speed: float = 0.35
@export var show_wall_logo: bool = true
@export_range(0.0, 1.0, 0.05) var fog_sky_affect: float = 0.0
@export var tonemap_mode: int = 1  # 0=Linear 1=Reinhardt 2=Filmic 3=ACES 4=AgX

var characters: Array = []
var portraits: Array = []
var _cols: int = 1
var _rows: int = 1
var cursor_index: int = 0
var selecting_player: int = 1
var p1_pick: String = ""
var p2_pick: String = ""
var _p1_locked_index: int = -1
var _preview_p1: Sprite3D = null
var _preview_p2: Sprite3D = null
var _label: Label = null
var _cam: Camera3D = null
var _cam_base: Vector3 = Vector3.ZERO
var _sway_t: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	characters = _scan_characters()
	_build_layout()
	_setup_environment()
	_spawn_lights()
	_spawn_geometry()
	_spawn_portraits()
	_spawn_previews()
	_setup_ui()
	_update_highlights()
	_update_label()
	_setup_camera()

func _process(delta: float) -> void:
	if _cam == null or camera_sway_amp <= 0.0:
		return
	_sway_t += delta
	_cam.position.x = _cam_base.x + sin(_sway_t * camera_sway_speed) * camera_sway_amp
	_cam.look_at(Vector3(0.0, -0.8, 0.0), Vector3.UP)

func _scan_characters() -> Array:
	var result: Array = []
	var dir := DirAccess.open("res://Personajes/")
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			var class_str: String = entry.replace(" ", "")
			var sm_path: String = "res://Personajes/%s/%sSpecialMoves.gd" % [entry, class_str]
			if FileAccess.file_exists(sm_path) or ResourceLoader.exists(sm_path):
				result.append(entry)
		entry = dir.get_next()
	result.sort()
	return result

func _build_layout() -> void:
	var n: int = maxi(characters.size(), 1)
	_cols = ceili(sqrt(float(n)))
	_rows = ceili(float(n) / float(_cols))

func _setup_environment() -> void:
	var env := Environment.new()
	env.tonemap_mode = tonemap_mode as Environment.ToneMapper
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.22, 0.32)
	env.ambient_light_energy = 0.5

	var sky_tex: Texture2D = null
	if ResourceLoader.exists(sky_texture_path):
		var res: Resource = load(sky_texture_path)
		if res is Texture2D:
			sky_tex = res

	if sky_tex != null:
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = sky_tex
		var sky := Sky.new()
		sky.sky_material = pano
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.03, 0.02, 0.05)

	if fog_enabled:
		env.fog_enabled = true
		env.fog_light_color = Color(0.05, 0.03, 0.07)
		env.fog_density = fog_density
		_apply_fog_sky_affect(env)

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _spawn_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.75, 0.5)
	sun.light_energy = 0.8
	sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(25.0), 0.0)
	sun.shadow_enabled = true
	add_child(sun)

	var l_p1 := OmniLight3D.new()
	l_p1.light_color = Color(1.0, 0.25, 0.2)
	l_p1.light_energy = 2.0
	l_p1.omni_range = 10.0
	l_p1.position = Vector3(-3.0, 2.2, -1.2)
	add_child(l_p1)

	var l_p2 := OmniLight3D.new()
	l_p2.light_color = Color(0.2, 0.7, 1.0)
	l_p2.light_energy = 2.0
	l_p2.omni_range = 10.0
	l_p2.position = Vector3(3.0, 2.2, -1.2)
	add_child(l_p2)

func _spawn_geometry() -> void:
	var w: float = stage_width + 2.0

	var platform := CSGBox3D.new()
	platform.size = Vector3(w, 1.0, 6.0)
	platform.position = stage_center + Vector3(0.0, -0.5, -0.5)
	var mat_p := StandardMaterial3D.new()
	mat_p.albedo_color = Color(0.09, 0.08, 0.1)
	mat_p.metallic = 0.3
	mat_p.roughness = 0.5
	platform.material = mat_p
	add_child(platform)

	var trim_p1 := CSGBox3D.new()
	trim_p1.size = Vector3(w * 0.5, 0.08, 0.08)
	trim_p1.position = Vector3(-w * 0.25, 0.04, -3.46)
	var mt1 := StandardMaterial3D.new()
	mt1.albedo_color = Color(0.2, 0.0, 0.0)
	mt1.emission_enabled = true
	mt1.emission = Color(1.0, 0.15, 0.1)
	mt1.emission_energy = 2.5
	trim_p1.material = mt1
	add_child(trim_p1)

	var trim_p2 := CSGBox3D.new()
	trim_p2.size = Vector3(w * 0.5, 0.08, 0.08)
	trim_p2.position = Vector3(w * 0.25, 0.04, -3.46)
	var mt2 := StandardMaterial3D.new()
	mt2.albedo_color = Color(0.0, 0.1, 0.15)
	mt2.emission_enabled = true
	mt2.emission = Color(0.1, 0.6, 1.0)
	mt2.emission_energy = 2.5
	trim_p2.material = mt2
	add_child(trim_p2)

	var wall := CSGBox3D.new()
	wall.size = Vector3(w, 4.5, 0.5)
	wall.position = Vector3(0.0, -3.25, 2.5)
	var mat_w := StandardMaterial3D.new()
	mat_w.albedo_color = Color(0.1, 0.07, 0.08)
	mat_w.roughness = 0.9
	wall.material = mat_w
	add_child(wall)

	if show_wall_logo:
		var logo := Label3D.new()
		logo.text = "MORTAL TEKKEN TECHNIC"
		logo.rotation.y = PI
		logo.position = Vector3(0.0, -1.0, 2.2)
		logo.modulate = Color(0.85, 0.12, 0.1)
		if ResourceLoader.exists("res://Fuentes/DirtyBrush.ttf"):
			var fr: Resource = load("res://Fuentes/DirtyBrush.ttf")
			if fr is Font:
				logo.font = fr
		logo.font_size = 44
		logo.pixel_size = 0.015
		add_child(logo)

func _spawn_portraits() -> void:
	var spacing_x: float = stage_width / float(_cols)
	for i in range(characters.size()):
		var tex: Texture2D = _load_portrait(characters[i])
		if tex == null:
			portraits.append(null)
			continue
		var portrait := Sprite3D.new()
		portrait.texture = tex
		portrait.pixel_size = portrait_height / float(tex.get_height())
		var col: int = i % _cols
		var row: int = floori(float(i) / float(_cols))
		var x: float = (float(col) - (_cols - 1) * 0.5) * spacing_x
		portrait.position = Vector3(x, -1.4 - row * 1.5, 2.8)
		add_child(portrait)
		portraits.append(portrait)

func _load_portrait(char_name: String) -> Texture2D:
	var base: String = "res://Personajes/%s/%sSpr/" % [char_name, char_name.replace(" ", "")]
	var path: String = base + "O1.png"
	if FileAccess.file_exists(path) or ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res
	return null

func _spawn_previews() -> void:
	_preview_p1 = _make_preview()
	_preview_p1.position = Vector3(-2.0, 0.0, -0.5)
	_preview_p2 = _make_preview()
	_preview_p2.position = Vector3(2.0, 0.0, -0.5)
	_preview_p2.visible = false
	if characters.size() > 0:
		_preview_p1.set_character(characters[0])

func _make_preview() -> Sprite3D:
	var p := Sprite3D.new()
	p.set_script(PreviewScript)
	p.pixels_per_meter = pixels_per_meter
	p.preview_scale = 2.2
	add_child(p)
	return p

func _active_preview() -> Sprite3D:
	return _preview_p1 if selecting_player == 1 else _preview_p2

func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Font:
			return res
	return ThemeDB.fallback_font

func _setup_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)

	var font_title: Font = _load_font("res://Fuentes/DirtyBrush.ttf")
	var font_ui: Font = _load_font("res://Fuentes/sing_14l.ttf")

	var lb_top := ColorRect.new()
	lb_top.color = Color.BLACK
	lb_top.anchor_right = 1.0
	lb_top.offset_top = 0.0
	lb_top.offset_bottom = 40.0
	cl.add_child(lb_top)

	var lb_bot := ColorRect.new()
	lb_bot.color = Color.BLACK
	lb_bot.anchor_right = 1.0
	lb_bot.anchor_top = 1.0
	lb_bot.anchor_bottom = 1.0
	lb_bot.offset_top = -34.0
	lb_bot.offset_bottom = 0.0
	cl.add_child(lb_bot)

	var title := Label.new()
	title.text = "SELECT YOUR FIGHTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_right = 1.0
	title.offset_top = 8
	title.offset_bottom = 38
	title.add_theme_font_override("font", font_title)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 3)
	cl.add_child(title)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.anchor_right = 1.0
	_label.offset_top = 45
	_label.offset_bottom = 70
	_label.add_theme_font_override("font", font_ui)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 2)
	cl.add_child(_label)

	var hint := Label.new()
	hint.text = "MOVER: FLECHAS   ·   CONFIRMAR: ENTER"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -28
	hint.offset_bottom = -6
	hint.add_theme_font_override("font", font_ui)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	cl.add_child(hint)

func _setup_camera() -> void:
	_cam = get_node_or_null("Camera3D")
	if _cam == null:
		_cam = Camera3D.new()
		_cam.name = "Camera3D"
		_cam.position = Vector3(0.0, 0.4, 7.0)
		add_child(_cam)
	_cam_base = _cam.position
	_cam.look_at(Vector3(0.0, -0.8, 0.0), Vector3.UP)

func _update_label() -> void:
	if _label == null:
		return
	if characters.is_empty():
		_label.text = "NO HAY PERSONAJES EN res://Personajes/"
	elif selecting_player == 1:
		_label.text = "P1 ELIGE: " + characters[cursor_index]
	else:
		_label.text = "P1: %s   |   P2 ELIGE: %s" % [p1_pick, characters[cursor_index]]

func _update_highlights() -> void:
	for i in range(portraits.size()):
		if portraits[i] == null:
			continue
		if i == _p1_locked_index:
			portraits[i].modulate = Color(1.0, 0.45, 0.45)
		elif i == cursor_index:
			portraits[i].modulate = Color.YELLOW if selecting_player == 1 else Color.CYAN
		else:
			portraits[i].modulate = Color.WHITE

func _unhandled_input(event: InputEvent) -> void:
	if characters.is_empty():
		return
	if event.is_action_pressed("ui_left"):
		_move_cursor(-1, 0)
	elif event.is_action_pressed("ui_right"):
		_move_cursor(1, 0)
	elif event.is_action_pressed("ui_up"):
		_move_cursor(0, -1)
	elif event.is_action_pressed("ui_down"):
		_move_cursor(0, 1)
	elif event.is_action_pressed("ui_accept"):
		_confirm()

func _move_cursor(dx: int, dy: int) -> void:
	var col: int = clampi(cursor_index % _cols + dx, 0, _cols - 1)
	var row: int = clampi(floori(float(cursor_index) / float(_cols)) + dy, 0, _rows - 1)
	var new_index: int = row * _cols + col
	if new_index >= characters.size():
		return
	cursor_index = new_index
	_active_preview().set_character(characters[cursor_index])
	_update_highlights()
	_update_label()

func _confirm() -> void:
	if selecting_player == 1:
		p1_pick = characters[cursor_index]
		_p1_locked_index = cursor_index
		selecting_player = 2
		_preview_p2.visible = true
		_preview_p2.set_character(characters[cursor_index])
		_update_highlights()
		_update_label()
	else:
		p2_pick = characters[cursor_index]
		_start_battle()

func _start_battle() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.set("p1_character", p1_pick)
		gm.set("p2_character", p2_pick)
		gm.call("reset_match")
	get_tree().change_scene_to_file(battle_scene_path)

func _apply_fog_sky_affect(env: Environment) -> void:
	if "fog_sky_affect" in env:
		env.set("fog_sky_affect", fog_sky_affect)
	elif "fog_sky_affect_enabled" in env:
		env.set("fog_sky_affect_enabled", fog_sky_affect > 0.5)
