extends CanvasLayer
class_name CSHUD
static var instance: CSHUD = null

var killfeed_container: VBoxContainer
var chat_container: VBoxContainer
var match_status_label: RichTextLabel
var match_status_panel: PanelContainer
const FONT_SIZE: int = 9
var _cue_player: AudioStreamPlayer = null
const CUE_BOMBPL: AudioStream = preload("res://Audio/Ciudad/Counter/bombpl.wav")
const CUE_BOMBDEF: AudioStream = preload("res://Audio/Ciudad/Counter/bombdef.wav")
const CUE_CTWIN: AudioStream = preload("res://Audio/Ciudad/Counter/ctwin.wav")
const CUE_TERWIN: AudioStream = preload("res://Audio/Ciudad/Counter/terwin.wav")

# ── Manager de audio ──────────────────────────────────────────────────────
static func play_bomb_cue(cue: String) -> void:
	var hud := get_or_create(Engine.get_main_loop() as SceneTree)
	if hud == null:
		return
	hud._play_cue(cue)

func _play_cue(cue: String) -> void:
	var stream: AudioStream = null
	match cue:
		"bombpl": stream = CUE_BOMBPL
		"bombdef": stream = CUE_BOMBDEF
		"ctwin": stream = CUE_CTWIN
		"terwin": stream = CUE_TERWIN
		_: push_warning("CSHUD: cue desconocida: %s" % cue)
	if stream == null:
		return
	if _cue_player == null:
		_cue_player = AudioStreamPlayer.new()
		add_child(_cue_player)
	_cue_player.stream = stream
	_cue_player.play()
	
# ── HUD ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	instance = self
	layer = 100
	_setup_killfeed_ui()
	_setup_chat_ui()
	_setup_match_status_ui()
	_cue_player = AudioStreamPlayer.new()
	add_child(_cue_player)

static func get_or_create(tree: SceneTree) -> CSHUD:
	if instance != null and is_instance_valid(instance):
		return instance
	var hud := CSHUD.new()
	tree.current_scene.add_child(hud)
	return hud

func _setup_killfeed_ui() -> void:
	killfeed_container = VBoxContainer.new()
	killfeed_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	killfeed_container.offset_left = -210
	killfeed_container.offset_right = -6
	killfeed_container.offset_top = 6
	killfeed_container.offset_bottom = 180
	killfeed_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	killfeed_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	killfeed_container.add_theme_constant_override("separation", 2)
	add_child(killfeed_container)

func _setup_chat_ui() -> void:
	chat_container = VBoxContainer.new()
	chat_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat_container.offset_left = 6
	chat_container.offset_right = 230
	chat_container.offset_top = -140
	chat_container.offset_bottom = -6
	chat_container.alignment = BoxContainer.ALIGNMENT_END
	chat_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_container.add_theme_constant_override("separation", 2)
	add_child(chat_container)

func _setup_match_status_ui() -> void:
	match_status_panel = PanelContainer.new()
	match_status_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	match_status_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	
	match_status_panel.offset_top = 8
	match_status_panel.offset_left = -160
	match_status_panel.offset_right = 160
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.06, 0.8)
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	match_status_panel.add_theme_stylebox_override("panel", style)
	
	match_status_label = RichTextLabel.new()
	match_status_label.fit_content = true
	match_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	match_status_label.bbcode_enabled = true
	match_status_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	match_status_label.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	match_status_label.text = "[center]Cargando estado...[/center]"
	
	match_status_panel.add_child(match_status_label)
	add_child(match_status_panel)

static func update_match_status(round_time_str: String, site_a_status: String, site_b_status: String, state_a: int, state_b: int) -> void:
	var hud: CSHUD = get_or_create(Engine.get_main_loop() as SceneTree)
	if hud == null or hud.match_status_label == null: return
	
	# Formatear Site A
	var color_a := "#aaaaaa"
	if state_a == 1: color_a = "#f39c12" # PLANTING
	elif state_a in [2, 4]: color_a = "#e74c3c" # PLANTED / EXPLODED
	elif state_a in [3, 5]: color_a = "#2ecc71" # DEFUSING / DEFUSED
	
	# Formatear Site B
	var color_b := "#aaaaaa"
	if state_b == 1: color_b = "#f39c12"
	elif state_b in [2, 4]: color_b = "#e74c3c"
	elif state_b in [3, 5]: color_b = "#2ecc71"
	
	hud.match_status_label.text = "[center][color=%s]A: %s[/color]   [b][color=#f1c40f]%s[/color][/b]   [color=%s]B: %s[/color][/center]" % [
		color_a, site_a_status, round_time_str, color_b, site_b_status
	]

# ── Killfeed ──────────────────────────────────────────────────────────────
static func post_kill(killer_name: String, victim_name: String, weapon_emoji: String, killer_is_ct: bool) -> void:
	var hud: CSHUD = get_or_create(Engine.get_main_loop() as SceneTree)
	if hud == null or hud.killfeed_container == null: return
	
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.75)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	
	var lbl := RichTextLabel.new()
	lbl.fit_content = true
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.bbcode_enabled = true
	lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	lbl.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	
	var killer_color := "#5dade2" if killer_is_ct else "#f5b041"
	var victim_color := "#f5b041" if killer_is_ct else "#5dade2"
	
	lbl.text = "[color=%s][b]%s[/b][/color] %s [color=%s][b]%s[/b][/color]" % [
		killer_color, killer_name, weapon_emoji, victim_color, victim_name
	]
	
	panel.add_child(lbl)
	hud.killfeed_container.add_child(panel)
	
	while hud.killfeed_container.get_child_count() > 5:
		var oldest = hud.killfeed_container.get_child(0)
		hud.killfeed_container.remove_child(oldest)
		oldest.queue_free()
		
	var tw := panel.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(panel.queue_free)

# ── Chat ──────────────────────────────────────────────────────────────────
static func post_chat(author_name: String, message: String, is_ct: bool) -> void:
	var hud: CSHUD = get_or_create(Engine.get_main_loop() as SceneTree)
	if hud == null or hud.chat_container == null: return
	
	var lbl := RichTextLabel.new()
	lbl.fit_content = true
	lbl.bbcode_enabled = true
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	lbl.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	
	var tag_color := "#5dade2" if is_ct else "#f5b041"
	var team_tag := "CT" if is_ct else "T"
	
	lbl.text = "[color=%s](%s) %s:[/color] %s" % [tag_color, team_tag, author_name, message]
	
	hud.chat_container.add_child(lbl)
	
	while hud.chat_container.get_child_count() > 5:
		var oldest = hud.chat_container.get_child(0)
		hud.chat_container.remove_child(oldest)
		oldest.queue_free()
		
	var tw := lbl.create_tween()
	tw.tween_interval(4.0) # Reducido a 4s
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)
