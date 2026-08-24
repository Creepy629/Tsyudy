extends RefCounted

var fighter: FighterBody

# ─── Animaciones universales (identificadores sin barra baja) ────────────
func get_universal_animations() -> Dictionary:
	return {
		"idle": ["A1", "A2", "A3", "A4", "A5", "A6"],
		"walk_forward": ["B1", "B2", "B3", "B4", "B5", "B6", "B7"],
		"walk_backward": ["B7", "B6", "B5", "B4", "B3", "B2", "B1"],
		"run": ["C1", "C3", "C4", "C5", "C6"],
		"victory": ["D1", "D1", "D2", "D2", "D3", "D3", "D7", "D8", "D9", "D10"],
		"crouch": ["E1"],
		"jump_up": ["F3", "F4", "F5"],
		"jump_fall": ["F7"],
		"hit_ground": ["J1", "J1", "J2", "J2"],
		"hit_air": ["K9", "K10", "K10", "K12", "K14"],
		"dash": ["C1"],
		"knockdown": ["J9"],
		"guard_stand": ["J2"],
		"guard_crouch": ["J4"]
	}

# ─── Combos de input ─────────────────────────────────────────────────────
var spear_combo: Array = [
	{"dir_x": -1.0},
	{"dir_x": 1.0},
	{"light_punch": true}
]

var teleport_combo: Array = [
	{"dir_x": -1.0},
	{"dir_x": 1.0},
	{"heavy_kick": true}
]

var double_kick_combo: Array = [
	{"dir_x": 1.0},
	{"dir_x": 1.0},
	{"heavy_kick": true}
]

var crouch_uppercut_combo: Array = [
	{"crouch": true},
	{"heavy_punch": true}
]

var crouch_lowkick_combo: Array = [
	{"crouch": true},
	{"light_kick": true}
]

var crouch_heavykick_combo: Array = [
	{"crouch": true},
	{"heavy_kick": true}
]

# ─── Init ────────────────────────────────────────────────────────────────
func _init_special_moves(f: FighterBody) -> void:
	fighter = f
	fighter.stats.jump_velocity = 5.5
	fighter.stats.dash_speed = 4.2
	fighter.stats.backdash_speed = 4.5
	print("Scorpion inicializado. Get over here!")

# ─── Lógica principal ────────────────────────────────────────────────────
func check_special_moves(input_state: Dictionary, sm: FighterStateMachine) -> void:
	if not sm.is_in_cancel_window(15):
		return

	var input_buf = fighter.player_input
	var hp = input_buf.was_attack_pressed("heavy_punch", 20)
	var lp = input_buf.was_attack_pressed("light_punch", 20)
	var hk = input_buf.was_attack_pressed("heavy_kick", 20)
	var lk = input_buf.was_attack_pressed("light_kick", 20)
	var is_back = (input_state.get("dir_x", 0.0) * fighter.facing_sign) < -0.1

	# ══ 1. Ramas de string ══
	if sm.current_action == sm.ActionState.ATTACK:
		# LP → LP
		if sm.current_attack_name == "lp_ground" and lp:
			var lp2 = [
				{"active": false, "frames": 4, "anim": "G8"},
				{"active": true, "frames": 5, "dmg": 2, "size": Vector3(0.6, 0.6, 1.0), "offset": Vector3(0.0, 0.8, -0.8), "anim": "G10"},
				{"active": false, "frames": 4, "anim": "G11"},
				{"active": false, "frames": 4, "anim": "G12"},
				{"active": true, "frames": 5, "dmg": 4, "size": Vector3(0.6, 0.6, 1.0), "offset": Vector3(0.0, 0.8, -0.8), "anim": "G12"},
				{"active": false, "frames": 4, "anim": "G8"}
			]
			input_buf.consume_attack_input("light_punch")
			sm.start_attack(lp2, 0.0, 0.05, "lp2_ground")
			return
		# LP → LP → HK (Doble patada, launcher)
		if sm.current_attack_name == "lp2_ground" and hk:
			_start_double_kick(input_buf, sm, 1.5)
			return
		# LP → HP (Empuje, ender con avance)
		if sm.current_attack_name == "lp_ground" and hp:
			var elbow = [
				{"active": false, "frames": 4, "anim": "K9"},
				{"active": true, "frames": 6, "dmg": 4, "knockback": 4.0, "size": Vector3(0.8, 0.6, 0.8), "offset": Vector3(0.0, 0.8, -0.8), "anim": "K10"},
				{"active": false, "frames": 6, "anim": "K10"}
			]
			input_buf.consume_attack_input("heavy_punch")
			sm.start_attack(elbow, 3.0, 0.1, "elbow_ender")
			return

	# ══ 2. Especiales ══
	# --- Spear / gancho: ida con attach, regreso con velocity negativa ---
	if input_buf.check_combo(spear_combo, fighter.facing_sign) and sm.current_move == sm.MoveState.GROUND:
		print("SCORPION: GET OVER HERE!")
		var spear = [
			{"active": false, "frames": 5, "anim": "K22"},
			{"active": false, "frames": 4, "anim": "K23"},
			{"active": true, "frames": 8, "dmg": 4, "hitstun": 80, "attach": true, "velocity": Vector3(0, 0, 10.0), "sprite": "M1", "anim": "K24"},
			{"active": true, "frames": 12, "dmg": 0, "hitstun": 40, "attach": true, "velocity": Vector3(0, 0, -8.0), "sprite": "M2", "anim": "K26"},
			{"active": false, "frames": 4, "anim": "K27"},
			{"active": false, "frames": 4, "anim": "K28"}
		]
		input_buf.clear_input_buffer()
		sm.start_attack(spear)
		return
	
	# --- Teleport ---
	if input_buf.check_combo(teleport_combo, fighter.facing_sign) and sm.current_move == sm.MoveState.GROUND:
		print("SCORPION: TELEPORT")
		var teleport = [
			{"active": false, "frames": 4, "self_launch": 3.0, "anim": "F8"},
			{"active": false, "frames": 4, "advance": -15.0, "anim": "F8"},
			{"active": false, "frames": 2, "teleport_behind": 2.5, "face_rival": true},
			{"active": true, "frames": 5, "dmg": 6, "knockback": 3.0, "size": Vector3(0.8, 1, 0.8), "offset": Vector3(0.0, 0.0, -0.8), "advance": 5.0,"anim": "K30"},
			{"active": true, "frames": 5, "dmg": 6, "knockback": 3.0, "size": Vector3(0.8, 1, 0.8), "offset": Vector3(0.0, 0.0, -0.8), "anim": "K30"},
			{"active": false, "frames": 8, "anim": "K30"}
		]
		input_buf.clear_input_buffer()
		sm.start_attack(teleport)
		return

	# --- Doble patada (adelante, adelante + HK) ---
	if input_buf.check_combo(double_kick_combo, fighter.facing_sign) and sm.current_move == sm.MoveState.GROUND:
		_start_double_kick(input_buf, sm, 0.0)
		return

	# --- Hacha (atrás + HP): overhead pesado ---
	if is_back and hp and sm.current_move == sm.MoveState.GROUND:
		var axe = [
			{"active": false, "frames": 5, "anim": "K1"},
			{"active": false, "frames": 4, "anim": "K3"},
			{"active": true, "frames": 6, "dmg": 7, "knockback": 2.0, "launch": 2.0, "angle": 90.0, "size": Vector3(0.9, 1.2, 0.9), "offset": Vector3(0.0, 1.2, -0.5), "anim": "K5"},
			{"active": true, "frames": 5, "dmg": 3, "knockback": 3.0, "size": Vector3(0.9, 0.8, 0.9), "offset": Vector3(0.0, 0.4, -0.5), "anim": "K7"},
			{"active": false, "frames": 6, "anim": "K8"},
			{"active": false}
		]
		input_buf.consume_attack_input("heavy_punch")
		sm.start_attack(axe, 1.0, 0.12, "axe_kick")
		return

	# --- Uppercut anti-aéreo (agachado + HP, E4-7) ---
	if input_buf.check_combo(crouch_uppercut_combo, fighter.facing_sign) and sm.current_move == sm.MoveState.GROUND:
		var uppercut = [
			{"active": false, "frames": 3, "anim": "E4"},
			{"active": true, "frames": 5, "self_launch": 4.5, "dmg": 6, "knockback": 1.0, "launch": 7.5, "angle": 85.0, "size": Vector3(0.8, 1.0, 0.8), "offset": Vector3(0.0, 0.5, -0.4), "anim": "E6"},
			{"active": true, "frames": 4, "dmg": 4, "knockback": 2.0, "launch": 8.0, "angle": 85.0, "size": Vector3(0.8, 1.0, 0.8), "offset": Vector3(0.0, 1.0, -0.6), "anim": "E7"},
			{"active": false}
		]
		input_buf.clear_input_buffer()
		sm.start_attack(uppercut)
		return

	# --- Patadas agachado ---
	if input_buf.check_combo(crouch_lowkick_combo, fighter.facing_sign) and sm.current_move == sm.MoveState.GROUND:
		var lowkick = [
			{"active": false, "frames": 3, "anim": "E11"},
			{"active": true, "frames": 6, "dmg": 2, "knockback": 1.5, "size": Vector3(0.8, 0.8, 1.2), "anim": "E12", "low": true},
			{"active": false, "frames": 5, "anim": "E11"}
		]
		input_buf.consume_attack_input("light_kick")
		sm.start_attack(lowkick, 0.0, 0.15, "lk_low")
		return

	if input_buf.check_combo(crouch_heavykick_combo, fighter.facing_sign) and sm.current_move == sm.MoveState.GROUND:
		var sweep = [
			{"active": false, "frames": 4, "anim": "E8"},
			{"active": true, "frames": 8, "dmg": 5, "knockback": 3.0, "launch": 2.0, "angle": 30.0, "size": Vector3(1.0, 0.6, 1.5), "offset": Vector3(0.0, -0.6, -0.6), "anim": "E10", "low": true},
			{"active": false, "frames": 6, "anim": "E9"}
		]
		input_buf.consume_attack_input("heavy_kick")
		sm.start_attack(sweep, 0.0, 0.15, "hk_low")
		return

	# ══ 3. Ataques base ══
	# LP suelo (G8-13)
	if lp and sm.current_move == sm.MoveState.GROUND:
		var putazo = [
			{"active": false, "frames": 3, "anim": "G8"},
			{"active": true, "frames": 4, "dmg": 2, "size": Vector3(0.6, 0.6, 1.0), "offset": Vector3(0.0, 0.8, -0.8), "anim": "G10"},
			{"active": false, "frames": 3, "anim": "G12"}
		]
		input_buf.consume_attack_input("light_punch")
		sm.start_attack(putazo, 0.0, 0.15, "lp_ground")
		return
	# HP suelo (G1-7)
	if hp and sm.current_move == sm.MoveState.GROUND:
		var putazo = [
			{"active": false, "frames": 4, "anim": "G1"},
			{"active": false, "frames": 3, "anim": "G2"},
			{"active": true, "frames": 6, "dmg": 4, "knockback": 4.0, "size": Vector3(0.8, 0.6, 0.8), "offset": Vector3(0.0, 0.8, -0.8), "anim": "G4"},
			{"active": false, "frames": 5, "anim": "G6"}
		]
		input_buf.consume_attack_input("heavy_punch")
		sm.start_attack(putazo, 0.0, 0.15, "hp_ground")
		return
	# LK suelo (H6-10)
	if lk and sm.current_move == sm.MoveState.GROUND:
		var patada = [
			{"active": false, "frames": 3, "anim": "H6"},
			{"active": true, "frames": 5, "dmg": 2, "knockback": 1.5, "size": Vector3(0.8, 0.8, 1.2), "anim": "H8"},
			{"active": false, "frames": 3, "anim": "H10"}
		]
		input_buf.consume_attack_input("light_kick")
		sm.start_attack(patada, 0.0, 0.15, "lk_ground")
		return
	# HK suelo (H1-5)
	if hk and sm.current_move == sm.MoveState.GROUND:
		var patada = [
			{"active": false, "frames": 4, "anim": "H1"},
			{"active": true, "frames": 8, "dmg": 5, "knockback": 5.0, "launch": 3.0, "angle": 45.0, "size": Vector3(1.0, 1.0, 1.5), "anim": "H3"},
			{"active": false, "frames": 5, "anim": "H5"}
		]
		input_buf.consume_attack_input("heavy_kick")
		sm.start_attack(patada, 0.0, 0.15, "hk_ground")
		return
	# HK en dash/run: patada fuerte + atrás (H11-17)
	if hk and (sm.current_move == sm.MoveState.DASH or sm.current_move == sm.MoveState.RUN):
		var dash_kick = [
			{"active": false, "frames": 3, "anim": "H11"},
			{"active": true, "frames": 8, "dmg": 5, "knockback": 4.0, "launch": 4.0, "angle": 70.0, "size": Vector3(1.0, 0.8, 1.5), "anim": "H14"},
			{"active": false, "frames": 6, "anim": "H17"}
		]
		input_buf.consume_attack_input("heavy_kick")
		sm.start_attack(dash_kick, 0.0, 0.15, "hk_dash")
		return
	# Aéreos (F8-13)
	if lp and sm.current_move == sm.MoveState.AIR:
		var air_punch = [
			{"active": true, "frames": 16, "dmg": 2, "size": Vector3(0.6, 0.6, 1.0), "offset": Vector3(0.0, -0.6, -0.8), "anim": "F9"},
			{"active": false, "frames": 4}
		]
		input_buf.consume_attack_input("light_punch")
		sm.start_attack(air_punch, 0.0, 0.15, "lp_air")
		return
	if hk and sm.current_move == sm.MoveState.AIR:
		var air_kick = [
			{"active": true, "frames": 16, "dmg": 5, "knockback": 4.0, "launch": 3.0, "angle": 45.0, "size": Vector3(0.8, 0.6, 0.8), "offset": Vector3(0.0, -0.8, -0.8), "anim": "F13"},
			{"active": false, "frames": 4}
		]
		input_buf.consume_attack_input("heavy_kick")
		sm.start_attack(air_kick, 0.0, 0.15, "hk_air")
		return

# ─── Helper: doble patada launcher ───────────────────────────────────────
func _start_double_kick(input_buf, sm: FighterStateMachine, advance: float) -> void:
	var double_kick = [
		{"active": false, "frames": 4, "anim": "K12"},
		{"active": false, "frames": 4, "anim": "K14"},
		{"active": true, "frames": 6, "dmg": 5, "knockback": 2.0, "launch": 6.0, "angle": 80.0, "size": Vector3(1.0, 1.0, 1.5), "offset": Vector3(0.0, 0.2, -0.6), "anim": "K16"},
		{"active": true, "frames": 6, "dmg": 4, "knockback": 3.0, "launch": 7.0, "angle": 80.0, "size": Vector3(1.0, 1.0, 1.5), "offset": Vector3(0.0, 0.4, -0.6), "anim": "K17"},
		{"active": false, "frames": 8, "anim": "K21"}
	]
	input_buf.consume_attack_input("heavy_kick")
	sm.start_attack(double_kick, advance, 0.1, "double_kick")
