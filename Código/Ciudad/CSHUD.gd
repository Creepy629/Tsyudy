extends CanvasLayer
class_name CSHUD

static var instance: CSHUD = null
const FONT_SIZE: int = 9
const BASE_RES: Vector2 = Vector2(640.0, 480.0)
const MINIMAP_W: int = 150
const MINIMAP_H: int = 120
const KILLFEED_MAX: int = 6
# ── Paleta de Color ─────────────────────────────────────────────────────────
const COL_BG: Color = Color("#3A2A4D")
const COL_TEXT: Color = Color("#E9E3F2")
const COL_RED: Color = Color("#E30103")
const COL_ACCION: Color = Color("#FED347")
const COL_CT: Color = Color("#5AA7DE")
const COL_TT: Color = Color("#F2A33C")
const COL_ALIEN: Color = Color("#8CC63E")
var chat_container: VBoxContainer = null
var notif_container: VBoxContainer = null
var minimap_panel: Panel = null
var minimap_container: SubViewportContainer = null
var minimap_viewport: SubViewport = null
var minimap_cam: Camera3D = null
var _playerRef: Node3D = null
var _playerSearchTimer: float = 0.0
var latest_time_str: String = "--:--"
var latest_status_a: String = "LIBRE"
var latest_status_b: String = "LIBRE"
var latest_state_a: int = 0
var latest_state_b: int = 0
var killfeed_entries: Array[Dictionary] = []
var killfeed_version: int = 0
var _cuePlayer: AudioStreamPlayer = null

const CUE_BOMBPL: AudioStream = preload("res://Audio/Ciudad/Counter/bombpl.wav")
const CUE_BOMBDEF: AudioStream = preload("res://Audio/Ciudad/Counter/bombdef.wav")
const CUE_CTWIN: AudioStream = preload("res://Audio/Ciudad/Counter/ctwin.wav")
const CUE_TERWIN: AudioStream = preload("res://Audio/Ciudad/Counter/terwin.wav")

# ── Layout y Escala ─────────────────────────────────────────────────────────
func _refresh_scale() -> void:
	var win: Vector2 = Vector2(get_window().size)
	scale = Vector2(BASE_RES.x / win.x, BASE_RES.y / win.y)
	_relayout(win)

func _relayout(win: Vector2) -> void:
	if chat_container != null:
		chat_container.position = Vector2(6.0, win.y - 286.0)
		chat_container.size = Vector2(234.0, 140.0)

	if notif_container != null:
		notif_container.position = Vector2(win.x - 216.0, 6.0)
		notif_container.size = Vector2(210.0, 214.0)

	if minimap_panel != null:
		minimap_panel.position = Vector2(6.0, win.y - MINIMAP_H - 14.0)
		minimap_panel.size = Vector2(MINIMAP_W + 8.0, MINIMAP_H + 8.0)

# ── Inicialización ──────────────────────────────────────────────────────────
func _ready() -> void:
	instance = self
	layer = 100

	_setup_minimap_ui()
	_setup_chat_ui()
	_setup_notif_ui()

	_cuePlayer = AudioStreamPlayer.new()
	add_child(_cuePlayer)

	_refresh_scale()
	get_window().size_changed.connect(_refresh_scale)

func _process(delta: float) -> void:
	_playerSearchTimer += delta

	if _playerRef == null or not is_instance_valid(_playerRef):
		if _playerSearchTimer >= 1.0:
			_playerSearchTimer = 0.0
			var found: Node = get_tree().current_scene.find_child("Jugador", true, false)
			if found is Node3D:
				_playerRef = found as Node3D
	else:
		if minimap_cam != null:
			minimap_cam.global_position = Vector3(
				_playerRef.global_position.x,
				_playerRef.global_position.y + 30.0,
				_playerRef.global_position.z
			)

static func get_or_create(tree: SceneTree) -> CSHUD:
	if instance != null and is_instance_valid(instance):
		return instance
	var hud := CSHUD.new()
	tree.current_scene.add_child(hud)
	return hud

# ── Minimapa ────────────────────────────────────────────────────────────────
func _setup_minimap_ui() -> void:
	minimap_panel = Panel.new()
	minimap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panelStyle := StyleBoxFlat.new()
	panelStyle.bg_color = Color(0.04, 0.03, 0.06, 0.55)
	panelStyle.border_color = Color(COL_RED.r, COL_RED.g, COL_RED.b, 0.6)
	panelStyle.set_border_width_all(2)
	panelStyle.set_corner_radius_all(10)
	minimap_panel.add_theme_stylebox_override("panel", panelStyle)
	add_child(minimap_panel)

	minimap_container = SubViewportContainer.new()
	minimap_container.position = Vector2(4, 4)
	minimap_container.size = Vector2(MINIMAP_W, MINIMAP_H)
	minimap_container.stretch = true
	minimap_container.self_modulate = Color(1.0, 1.0, 1.0, 0.75)
	minimap_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_panel.add_child(minimap_container)

	minimap_viewport = SubViewport.new()
	minimap_viewport.size = Vector2i(MINIMAP_W, MINIMAP_H)
	minimap_viewport.transparent_bg = true
	minimap_viewport.debug_draw = SubViewport.DEBUG_DRAW_UNSHADED
	minimap_container.add_child(minimap_viewport)

	minimap_cam = Camera3D.new()
	minimap_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	minimap_cam.size = 70.0
	minimap_cam.near = 1.0
	minimap_cam.far = 400.0
	minimap_cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	minimap_cam.current = true
	minimap_viewport.add_child(minimap_cam)

	var dot := ColorRect.new()
	dot.size = Vector2(4, 4)
	dot.position = Vector2(4 + MINIMAP_W * 0.5 - 2.0, 4 + MINIMAP_H * 0.5 - 2.0)
	dot.color = COL_ACCION
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_panel.add_child(dot)

# ── Interfaz de Chat ────────────────────────────────────────────────────────
func _setup_chat_ui() -> void:
	chat_container = VBoxContainer.new()
	chat_container.alignment = BoxContainer.ALIGNMENT_END
	chat_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_container.add_theme_constant_override("separation", 2)
	add_child(chat_container)

# ── Notificaciones de Partida ───────────────────────────────────────────────
func _setup_notif_ui() -> void:
	notif_container = VBoxContainer.new()
	notif_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	notif_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notif_container.add_theme_constant_override("separation", 4)
	add_child(notif_container)

func post_notification(text: String, accent: Color) -> void:
	if notif_container == null:
		return

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COL_BG.r, COL_BG.g, COL_BG.b, 0.92)
	style.border_color = accent
	style.border_width_left = 3
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)

	var lbl := RichTextLabel.new()
	lbl.fit_content = true
	lbl.bbcode_enabled = true
	lbl.scroll_active = false
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	lbl.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	lbl.text = "[color=%s]%s[/color]" % [COL_TEXT.to_html(false), text]
	panel.add_child(lbl)

	notif_container.add_child(panel)

	while notif_container.get_child_count() > 3:
		var oldest: Node = notif_container.get_child(0)
		notif_container.remove_child(oldest)
		oldest.queue_free()

	var tw := panel.create_tween()
	tw.bind_node(panel)
	tw.tween_interval(4.0)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(panel.queue_free)

# ── Notificaciones de Audio por Eventos ─────────────────────────────────────
static func play_bomb_cue(cue: String) -> void:
	var hud := get_or_create(Engine.get_main_loop() as SceneTree)
	if hud == null:
		return
	hud._play_cue(cue)

func _play_cue(cue: String) -> void:
	var stream: AudioStream = null

	match cue:
		"bombpl":
			stream = CUE_BOMBPL
			post_notification("💣 C4 PLANTADA", COL_RED)
		"bombdef":
			stream = CUE_BOMBDEF
			post_notification("🛠 C4 DESACTIVADA", COL_CT)
		"ctwin":
			stream = CUE_CTWIN
			post_notification("🛡 GANAN LOS ANTI-TERRORISTAS", COL_CT)
		"terwin":
			stream = CUE_TERWIN
			post_notification("🔥 GANAN LOS TERRORISTAS", COL_TT)
		_:
			push_warning("CSHUD: cue desconocida: %s" % cue)

	if stream == null:
		return

	if _cuePlayer == null:
		_cuePlayer = AudioStreamPlayer.new()
		add_child(_cuePlayer)

	_cuePlayer.stream = stream
	_cuePlayer.play()

# ── Snapshot y Estado de Partida ────────────────────────────────────────────
static func update_match_status(round_time_str: String, site_a_status: String, site_b_status: String, state_a: int, state_b: int) -> void:
	var hud: CSHUD = get_or_create(Engine.get_main_loop() as SceneTree)
	if hud == null:
		return
	hud.latest_time_str = round_time_str
	hud.latest_status_a = site_a_status
	hud.latest_status_b = site_b_status
	hud.latest_state_a = state_a
	hud.latest_state_b = state_b

static func get_match_snapshot() -> Dictionary:
	if instance == null or not is_instance_valid(instance):
		return {}
	return {
		"time": instance.latest_time_str,
		"a_text": instance.latest_status_a,
		"b_text": instance.latest_status_b,
		"a_state": instance.latest_state_a,
		"b_state": instance.latest_state_b,
	}

static func site_color(state: int) -> Color:
	match state:
		1: return COL_TT
		2, 4: return COL_RED
		3, 5: return COL_ALIEN
		_: return Color(0.62, 0.62, 0.66)

# ── Killfeed ────────────────────────────────────────────────────────────────
static func post_kill(killer_name: String, victim_name: String, weapon_emoji: String, killer_is_ct: bool) -> void:
	var hud: CSHUD = get_or_create(Engine.get_main_loop() as SceneTree)
	if hud == null:
		return

	var entry: Dictionary = {
		"killer": killer_name,
		"victim": victim_name,
		"weapon": weapon_emoji,
		"killer_ct": killer_is_ct,
		"victim_ct": not killer_is_ct,
	}
	hud.killfeed_entries.append(entry)

	while hud.killfeed_entries.size() > KILLFEED_MAX:
		hud.killfeed_entries.pop_front()

	hud.killfeed_version += 1

static func get_killfeed() -> Array:
	if instance == null or not is_instance_valid(instance):
		return []
	return instance.killfeed_entries.duplicate()

static func get_killfeed_version() -> int:
	if instance == null or not is_instance_valid(instance):
		return 0
	return instance.killfeed_version

# ── Chat ────────────────────────────────────────────────────────────────────
static func post_chat(author_name: String, message: String, is_ct: bool) -> void:
	var hud: CSHUD = get_or_create(Engine.get_main_loop() as SceneTree)
	if hud == null or hud.chat_container == null:
		return

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.10, 0.55)
	style.set_corner_radius_all(3)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", style)

	var lbl := RichTextLabel.new()
	lbl.fit_content = true
	lbl.bbcode_enabled = true
	lbl.scroll_active = false
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	lbl.add_theme_font_size_override("bold_font_size", FONT_SIZE)

	var tag_color: Color = COL_CT if is_ct else COL_TT
	var team_tag: String = "CT" if is_ct else "T"
	lbl.text = "[color=%s](%s) %s:[/color] [color=%s]%s[/color]" % [
		tag_color.to_html(false), team_tag, author_name,
		COL_TEXT.to_html(false), message
	]
	panel.add_child(lbl)

	hud.chat_container.add_child(panel)

	while hud.chat_container.get_child_count() > 5:
		var oldest: Node = hud.chat_container.get_child(0)
		hud.chat_container.remove_child(oldest)
		oldest.queue_free()

	var tw := panel.create_tween()
	tw.bind_node(panel)
	tw.tween_interval(4.0)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(panel.queue_free)
