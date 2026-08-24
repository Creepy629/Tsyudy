extends Node

@export var player1_path: NodePath
@export var player2_path: NodePath
@export var rounds_to_win: int = 2
@export var announcer_folder := "res://Audio/Pelea/Comentarista/"
@export var music_folder := "res://Audio/Pelea/Concierto/"
@export var start_distance := 5.0
@export var show_debug_boxes := false
@export var return_to_city: bool = false
@export var city_scene_path: String = "res://Escenas/Mapas/de_dust2.tscn"

var p1: FighterBody
var p2: FighterBody
var _phase := "INTRO"
var _phase_timer := 0.0
var _ko_ms := 0
var _audio: AudioStreamPlayer
var _music: AudioStreamPlayer
var _label_center: Label
var _label_sub: Label
var _center_elapsed := 999.0
var _combo := {1: 0, 2: 0}
var _winner: FighterBody = null
var p1_start: Vector3
var p2_start: Vector3
var match_frozen := false
var counter_active := false
var _uppercut_count := {1: 0, 2: 0}
var _bgm_player: AudioStreamPlayer = null
var _flash_overlay: ColorRect
var _vignette: ColorRect
var _font_announcer: Font
var _font_title: Font

func _ready() -> void:
	_load_fonts()
	p1 = get_node(player1_path)
	p2 = get_node(player2_path)
	p1_start = p1.global_position
	p2_start = p2.global_position
	p1.health_changed.connect(_on_health_changed.bind(p1))
	p2.health_changed.connect(_on_health_changed.bind(p2))
	for f in [p1, p2]:
		_set_debug_boxes_recursive(f, show_debug_boxes)
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	if p1 and p1.has_signal("uppercut_landed"):
		p1.uppercut_landed.connect(_on_uppercut_landed.bind(1))
	if p2 and p2.has_signal("uppercut_landed"):
		p2.uppercut_landed.connect(_on_uppercut_landed.bind(2))
	_apply_start_positions()
	_setup_ui()
	_start_music()
	p1.match_frozen = true
	p2.match_frozen = true
	_begin_round_intro()

func _load_fonts() -> void:
	var base := "res://Fuentes/"
	if FileAccess.file_exists(base + "Mom«t___.ttf") or ResourceLoader.exists(base + "Mom«t___.ttf"):
		_font_announcer = load(base + "Mom«t___.ttf")
	if not _font_announcer:
		_font_announcer = ThemeDB.fallback_font
	if FileAccess.file_exists(base + "DirtyBrush.ttf") or ResourceLoader.exists(base + "DirtyBrush.ttf"):
		_font_title = load(base + "DirtyBrush.ttf")
	if not _font_title:
		_font_title = ThemeDB.fallback_font

func _set_debug_boxes_recursive(node: Node, visible: bool) -> void:
	if node.has_method("set_debug_visible"):
		node.set_debug_visible(visible)
	for child in node.get_children():
		_set_debug_boxes_recursive(child, visible)

func _apply_start_positions() -> void:
	var fd := p1.get_fight_axis()
	var mid := (p1_start + p2_start) * 0.5
	mid.y = 0.0
	p1.global_position = Vector3(mid.x, p1_start.y, mid.z) - fd * (start_distance * 0.5)
	p2.global_position = Vector3(mid.x, p2_start.y, mid.z) + fd * (start_distance * 0.5)

func _setup_ui() -> void:
	# Overlay de flash
	_flash_overlay = ColorRect.new()
	_flash_overlay.color = Color(0, 0, 0, 0)
	_flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_overlay)

	# Viñeta cinematográfica
	_vignette = ColorRect.new()
	_vignette.color = Color(0, 0, 0, 0.3)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_shader := Shader.new()
	vignette_shader.code = """
	shader_type canvas_item;
	void fragment() {
		vec2 uv = SCREEN_UV;
		float dist = distance(uv, vec2(0.5));
		float vignette = smoothstep(0.8, 0.2, dist);
		COLOR.a = 0.35 * (1.0 - vignette);
	}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = vignette_shader
	_vignette.material = mat
	add_child(_vignette)

	# Labels de centro (anuncios)
	var cl := CanvasLayer.new()
	add_child(cl)
	_label_center = Label.new()
	_label_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_center.anchor_right = 1.0
	_label_center.offset_top = 140
	_label_center.offset_bottom = 260
	_label_center.add_theme_font_override("font", _font_announcer)
	_label_center.add_theme_font_size_override("font_size", 48)
	_label_center.add_theme_color_override("font_color", Color.WHITE)
	_label_center.add_theme_color_override("font_outline_color", Color.BLACK)
	_label_center.add_theme_constant_override("outline_size", 6)
	_label_center.add_theme_color_override("font_shadow_color", Color(1, 0.45, 0, 0.8))
	_label_center.add_theme_constant_override("shadow_offset_x", 2)
	_label_center.add_theme_constant_override("shadow_offset_y", 2)
	cl.add_child(_label_center)
	_label_sub = Label.new()
	_label_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_sub.anchor_right = 1.0
	_label_sub.anchor_top = 1.0
	_label_sub.anchor_bottom = 1.0
	_label_sub.offset_top = -140
	_label_sub.offset_bottom = -80
	_label_sub.add_theme_font_override("font", _font_title)
	_label_sub.add_theme_font_size_override("font_size", 28)
	cl.add_child(_label_sub)

func _set_center(text: String, color: Color, size: int) -> void:
	if _label_center:
		_label_center.text = text
		_label_center.add_theme_font_size_override("font_size", size)
		_label_center.add_theme_color_override("font_color", color)
		_label_center.visible = true
		_center_elapsed = 0.0

func _play_announcer(file: String) -> void:
	var path := announcer_folder + file
	if FileAccess.file_exists(path) or ResourceLoader.exists(path):
		_audio.stream = load(path)
		_audio.play()

func _side_of(f) -> int:
	return 1 if f == p1 else 2

func _headline(text: String, side: int, force: bool = true) -> void:
	var ui = get_node_or_null("../BattleUI")
	if ui and ui.has_method("show_headline"):
		ui.show_headline(text, side, force)

func _on_uppercut_landed(_attacker: FighterBody, side: int) -> void:
	_uppercut_count[side] = int(_uppercut_count.get(side, 0)) + 1
	if int(_uppercut_count[side]) >= 3:
		_headline("TOASTY!", side, true)
		_play_announcer("Toasty.wav")

func _start_music() -> void:
	var dir := DirAccess.open(music_folder)
	if dir == null:
		return
	var mp3_ogg_tracks: Array = []
	dir.list_dir_begin()
	var e := dir.get_next()
	while e != "":
		if not dir.current_is_dir():
			var clean_e = e.trim_suffix(".remap").trim_suffix(".import")
			if clean_e.ends_with(".mp3") or clean_e.ends_with(".ogg"):
				var full_path = music_folder + clean_e
				if not mp3_ogg_tracks.has(full_path):
					mp3_ogg_tracks.append(full_path)
		e = dir.get_next()
	
	if mp3_ogg_tracks.is_empty():
		return

	var chosen_path: String = mp3_ogg_tracks[randi() % mp3_ogg_tracks.size()]
	if FileAccess.file_exists(chosen_path) or ResourceLoader.exists(chosen_path):
		var stream = load(chosen_path)
		if stream:
			_music.stream = stream
			_music.play()

# ─── Flow de fases ───────────────────────────────────────────────────────────
func _begin_round_intro() -> void:
	_phase = "INTRO"
	_phase_timer = 0.0
	var rn := 1
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and "round_number" in gm:
		rn = int(gm.round_number)
	_set_center("ROUND %d" % rn, Color.WHITE, 72)
	_play_announcer("Round%d.wav" % clampi(rn, 1, 5))
	_flash(Color.WHITE, 0.0)

func _process(delta: float) -> void:
	_hl_wire()
	_bgm_wire()
	
	_phase_timer += delta
	_center_elapsed += delta
	match _phase:
		"INTRO":
			if _phase_timer >= 1.2:
				_phase = "FIGHT"
				_phase_timer = 0.0
				_set_center("FIGHT!", Color.ORANGE_RED, 80)
				_play_announcer("Fight.wav")
				p1.match_frozen = false
				p2.match_frozen = false
		"FIGHT":
			if _center_elapsed > 0.9:
				_label_center.visible = false
			_update_combos()
		"KO":
			if Engine.time_scale < 1.0 and Time.get_ticks_msec() - _ko_ms > 700:
				Engine.time_scale = 1.0
			if Time.get_ticks_msec() - _ko_ms > 2200:
				_after_ko()
		"ROUND_END":
			if _phase_timer >= 2.8:
				_decide_next()
		"MATCH_END":
			if _phase_timer >= 3.0:
				var gm := get_node_or_null("/root/GameManager")
				if gm:
					gm.reset_match()
				if return_to_city:
					get_tree().change_scene_to_file(city_scene_path)
				else:
					get_tree().change_scene_to_file("res://Escenas/Pelea/CharacterSelect.tscn")

# ─── Detección de golpes ─────────────────────────────────────────────────────
func _on_health_changed(current: int, _max_hp: int, victim: FighterBody) -> void:
	if _phase != "FIGHT":
		return
	var attacker_id := 2 if victim == p1 else 1
	# Counter (solo audio, el texto lo maneja BattleUI)
	if victim.state_machine.current_action == victim.state_machine.ActionState.ATTACK:
		counter_active = true
		_play_announcer("Counter.wav")
	else:
		counter_active = false
	# Combo: contador para BattleUI y para determinar winner
	if victim.state_machine.current_action == victim.state_machine.ActionState.HIT:
		_combo[attacker_id] += 1
	else:
		_combo[attacker_id] = 1
	if current <= 0:
		_trigger_ko(p2 if victim == p1 else p1, victim)

func _update_combos() -> void:
	for id in [1, 2]:
		var victim := p2 if id == 1 else p1
		if _combo[id] > 0 and victim.state_machine.current_action != victim.state_machine.ActionState.HIT:
			_combo[id] = 0
			counter_active = false

func _trigger_ko(winner: FighterBody, loser: FighterBody) -> void:
	_phase = "KO"
	_winner = winner
	loser.state_machine.is_knocked_down = true
	loser.state_machine.action_duration = 9999.0
	p1.match_frozen = true
	p2.match_frozen = true
	_set_center("K.O.", Color.RED, 120)
	_play_announcer("KO.wav")
	Engine.time_scale = 0.3
	_ko_ms = Time.get_ticks_msec()

func _after_ko() -> void:
	Engine.time_scale = 1.0
	_phase = "ROUND_END"
	_phase_timer = 0.0
	var gm := get_node_or_null("/root/GameManager")
	var atk_name := _winner.state_machine.current_attack_name
	if atk_name in ["spear", "hat_throw", "uppercut", "axe_kick"]:
		_set_center("TOASTY!", Color.ORANGE, 72)
		_play_announcer("Toasty.wav")
		_flash(Color.ORANGE, 0.5)
	elif _winner.stats.current_health >= _winner.stats.max_health:
		_set_center("PERFECT!", Color.YELLOW, 72)
		_play_announcer("Perfect.wav")
		_flash(Color.YELLOW, 0.5)
	var sprite := _winner.get_node_or_null("Sprite3D")
	if sprite and "forced_anim" in sprite:
		sprite.forced_anim = "victory"
	_play_announcer("Wins.wav")
	if gm:
		if _winner == p1:
			gm.p1_wins += 1
		else:
			gm.p2_wins += 1
	_label_sub.text = "%s WINS" % _winner.character_name.to_upper()
	_label_sub.visible = true

func _decide_next() -> void:
	var p1w := 0
	var p2w := 0
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		p1w = int(gm.p1_wins)
		p2w = int(gm.p2_wins)
	if p1w >= rounds_to_win or p2w >= rounds_to_win:
		_phase = "MATCH_END"
		_phase_timer = 0.0
		var winner_name := _winner.character_name.to_upper() if _winner else "???"
		_label_sub.text = "%s WINS THE MATCH!" % winner_name
	else:
		if gm != null and "round_number" in gm:
			gm.round_number += 1
		_reset_round()

func _reset_round() -> void:
	for f in [p1, p2]:
		f.reset_round()
		var spr: Node = f.get_node_or_null("Sprite3D")
		if spr and "forced_anim" in spr:
			spr.forced_anim = ""
	_apply_start_positions()
	_combo = {1: 0, 2: 0}
	_label_sub.visible = false
	_begin_round_intro()

# ─── Efecto de flash ─────────────────────────────────────────────────────────
func _flash(color: Color, intensity: float) -> void:
	if _flash_overlay:
		_flash_overlay.color = Color(color.r, color.g, color.b, intensity)

# ── Titulares deslizantes molones ─────────────────────────────────────────
var _hl_wired := false
var _hl_combo := {1: 0, 2: 0}
var _hl_uppercuts := {1: 0, 2: 0}
var _hl_p1: FighterBody = null
var _hl_p2: FighterBody = null

func _hl_wire() -> void:
	if _hl_wired:
		return
	if not _hl_p1:
		_hl_p1 = get_node_or_null("../Player1")
	if not _hl_p2:
		_hl_p2 = get_node_or_null("../AI")
	if not _hl_p1 or not _hl_p2:
		return
	_hl_wired = true
	_hl_p1.health_changed.connect(_hl_on_hit.bind(1))
	_hl_p2.health_changed.connect(_hl_on_hit.bind(2))
	if _hl_p1.has_signal("uppercut_landed"):
		_hl_p1.uppercut_landed.connect(_hl_on_uppercut.bind(1))
	if _hl_p2.has_signal("uppercut_landed"):
		_hl_p2.uppercut_landed.connect(_hl_on_uppercut.bind(2))

func _hl_on_hit(current_hp: int, _max_hp: int, side: int) -> void:
	var victim := _hl_p1 if side == 1 else _hl_p2
	var attacker_side := 2 if side == 1 else 1
	if not victim or not victim.state_machine:
		return
	var v_action = victim.state_machine.current_action
	# COUNTER: la víctima estaba en pleno ataque al recibir
	if v_action == victim.state_machine.ActionState.ATTACK:
		_headline("COUNTER!", attacker_side, true)
	# HITS: la víctima ya estaba en hitstun → el combo continúa
	if v_action == victim.state_machine.ActionState.HIT:
		_hl_combo[attacker_side] = int(_hl_combo[attacker_side]) + 1
	else:
		_hl_combo[attacker_side] = 1
	if int(_hl_combo[attacker_side]) >= 2:
		_headline("%d HITS!" % int(_hl_combo[attacker_side]), attacker_side, false)
	# PERFECT: KO con la vida llena
	if current_hp <= 0:
		var winner := _hl_p1 if attacker_side == 1 else _hl_p2
		if winner and int(winner.stats.get("current_health", 0)) >= int(winner.stats.get("max_health", 100)):
			_headline("PERFECT!", attacker_side, true)
		_hl_combo = {1: 0, 2: 0}

func _hl_on_uppercut(_attacker: FighterBody, side: int) -> void:
	_hl_uppercuts[side] = int(_hl_uppercuts.get(side, 0)) + 1
	if int(_hl_uppercuts[side]) >= 3:
		_headline("TOASTY!", side, true)
		if has_method("_play_announcer"):
			_play_announcer("Toasty.wav")

# ── Música ────────────────────────────────────────────────────────────────
func _bgm_wire() -> void:
	if _bgm_player and is_instance_valid(_bgm_player):
		return
	for child in get_children():
		if child is AudioStreamPlayer and child.stream and child.stream.get_length() > 20.0:
			_bgm_player = child
			break
	if _bgm_player:
		_force_loop(_bgm_player.stream)
		if not _bgm_player.finished.is_connected(_bgm_restart):
			_bgm_player.finished.connect(_bgm_restart)

func _force_loop(stream: Resource) -> void:
	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

func _bgm_restart() -> void:
	if _bgm_player and is_instance_valid(_bgm_player):
		_bgm_player.play()
