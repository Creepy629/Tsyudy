extends RefCounted
var fighter: FighterBody

# ─── Combos de input ──────────────────────────────────────
var tornado_combo: Array = [
	{"dir_x": - 1.0},
	{"crouch": true},
	{"dir_x": 1.0},
	{"heavy_punch": true}
]

var uppercut_combo: Array = [
	{"crouch": true},
	{"heavy_punch": true}
]

var lowkirk: Array = [
	{"crouch": true},
	{"light_kick": true}
]

var heavykirk: Array = [
	{"crouch": true},
	{"heavy_kick": true}
]

var hat_trick: Array = [
	{"dir_x": - 1.0},
	{"dir_x": 1.0},
	{"light_punch": true}
]

var beatup_kirk: Array = [
	{"light_kick": true},
	{"heavy_kick": true}
]

# ─── Animaciones universales ────────────────────────────────────────────────
func get_universal_animations() -> Dictionary:
	return {
		"idle": ["A1", "A2", "A3", "A4", "A5", "A6", "A7"],
		"walk_forward": ["B1", "B2", "B3", "B4", "B5", "B6", "B7"],
		"walk_backward": ["B7", "B6", "B5", "B4", "B3", "B2", "B1"],
		"run": ["C1", "C2", "C4", "C5", "C6"],
		"victory": ["D1", "D2", "D3", "D4", "D5", "D5", "D7", "D8", "D9", "D10", "D12", "D12", "D13", "D14", "D15", "D16"],
		"crouch": ["E2"],
		"jump_up": ["F4", "F5", "F6"],
		"jump_fall": ["F7", "F9", "F10"],
		"hit_ground": ["K1", "K1", "K2", "K2"],
		"hit_air": ["K3", "K4"],
		"dash": ["C1", "C2"],
		"knockdown": ["K15"],
		"guard_stand": ["J1"],
		"guard_crouch": ["J4"]
	}

# ─── Init ───────────────────────────────────────────────────────────────────
func _init_special_moves(f: FighterBody) -> void:
	fighter = f
	fighter.stats.walk_speed = 2.6
	fighter.stats.jump_velocity = 5.5
	fighter.stats.dash_speed = 4.5
	fighter.stats.backdash_speed = 5.0
	print("Kung Lao inicializado con sus stats únicos.")

# ─── Lógica principal ───────────────────────────────────────────────────────
func check_special_moves(input_state: Dictionary, sm: FighterStateMachine) -> void:
	if not sm.is_in_cancel_window(15):
		return
		
	var input_buf = fighter.player_input
	var hp = input_buf.was_attack_pressed("heavy_punch", 20)
	var lp = input_buf.was_attack_pressed("light_punch", 20)
	var hk = input_buf.was_attack_pressed("heavy_kick", 20)
	var lk = input_buf.was_attack_pressed("light_kick", 20)
	
	# Usamos input_state directo (get_movement_state() aquí contaminaría el buffer)
	var is_back = (input_state.get("dir_x", 0.0) * fighter.facing_sign) < -0.1
	
	# ══ 1. Ramas de string ══
	if sm.current_action == sm.ActionState.ATTACK:
		# LP → LP (arranca el string)
		if sm.current_attack_name == "lp_ground" and lp:
			print("Kung Lao: Inicio de partir madres (Beatup 1)")
			var putazo = [
				{"active": false, "frames": 4, "anim": "G1"},
				{"active": false, "frames": 4, "anim": "G2"},
				{"active": true, "frames": 8, "dmg": 3, "size": Vector3(0.8, 0.6, 0.8), "offset": Vector3(0.0, 0.8, -0.8), "anim": "G3"},
				{"active": false, "frames": 4, "anim": "G4"},
				{"active": false, "frames": 4, "anim": "G5"},
				{"active": true, "frames": 8, "dmg": 4, "size": Vector3(0.8, 0.6, 0.8), "offset": Vector3(0.0, 0.8, -0.8), "anim": "G6"},
				{"active": false, "frames": 8, "anim": "G7"}
			]
			input_buf.consume_attack_input("light_punch")
			sm.start_attack(putazo, 0.0, 0.05, "beatup_1")
			return

		# LP → LP → LK (continúa el string)
		if sm.current_attack_name == "beatup_1" and lk:
			print("Kung Lao: Patadón (Beatup 2)")
			var putazo2 = [
				{"active": false, "frames": 4, "anim": "I2"},
				{"active": false, "frames": 4, "anim": "I4"},
				{"active": true, "frames": 8, "dmg": 3, "size": Vector3(0.8, 0.6, 0.8), "anim": "I5"},
				{"active": false, "frames": 4, "anim": "I7"},
				{"active": false, "frames": 4, "anim": "I8"},
				{"active": false, "frames": 4, "anim": "I9"},
				{"active": true, "frames": 8, "dmg": 4, "size": Vector3(0.8, 0.6, 0.8), "anim": "I11"},
				{"active": false, "frames": 8, "anim": "I14"}
			]
			input_buf.consume_attack_input("light_kick")
			sm.start_attack(putazo2, 0.0, 0.05, "beatup_2")
			return

		# LP → LP → LK → HK (remate final)
		if sm.current_attack_name == "beatup_2" and hp:
			print("Kung Lao: REMATE (Beatup 3)")
			var remate = [
				{"active": false, "frames": 4, "anim": "E6"},
				{"active": false, "frames": 4, "anim": "E7"},
				{"active": true, "frames": 4, "dmg": 6, "knockback": 2, "launch": 5.5, "angle": 85.0, "size": Vector3(0.8, 1.0, 0.8), "offset": Vector3(0.0, 0.5, -0.4), "anim": "E8"},
				{"active": true, "frames": 4, "dmg": 6, "knockback": 2, "launch": 5.5, "angle": 85.0, "size": Vector3(0.8, 1.0, 0.8), "offset": Vector3(0.0, 1.0, -0.6), "anim": "E9"},
				{"active": false}
			]
			input_buf.consume_attack_input("heavy_punch")
			sm.start_attack(remate, 0.0, 0.15, "beatup_3")
			return

	# ══ 2. Especiales ══

	if input_buf.check_combo(tornado_combo, fighter.facing_sign) and sm.current_move == sm.MoveState.GROUND:
		print("KUNG LAO: TALADRAZO")
		var tornado = [
			{"active": false, "frames": 4, "anim": "L10"},
			{"active": true, "frames": 4, "dmg": 3, "knockback": 3.0, "launch": 3.5, "angle": 90.0, "size": Vector3(1.0, 1.5, 1.0), "offset": Vector3(0.0, 0.0, -0.3), "anim": "L7"},
			{"active": false, "frames": 4, "anim": "L8"},
			{"active": true, "frames": 4, "dmg": 3, "knockback": 3.0, "launch": 3.5, "angle": 90.0, "size": Vector3(1.0, 1.5, 1.0), "offset": Vector3(0.0, 0.0, -0.3), "anim": "L9"},
			{"active": false, "frames": 3, "anim": "L10"},
			{"active": true, "frames": 4, "dmg": 3, "knockback": 3.0, "launch": 3.5, "angle": 90.0, "size": Vector3(1.0, 1.5, 1.0), "offset": Vector3(0.0, 0.0, -0.3), "anim": "L7"},
			{"active": false, "frames": 3, "anim": "L8"},
			{"active": true, "frames": 5, "dmg": 6, "knockback": 2.5, "launch": 5.5, "angle": 75.0, "size": Vector3(1.2, 1.8, 1.2), "offset": Vector3(0.0, 0.0, -0.3), "anim": "L9"},
			{"active": false, "frames": 4, "anim": "L11"}
		]
		input_buf.clear_input_buffer()
		sm.start_attack(tornado, 3.5)
		return

	if input_buf.check_combo(uppercut_combo, fighter.facing_sign) and sm.current_move == sm.MoveState.GROUND:
		print("KUNG LAO: UPPERCUT")
		var uppercut = [
			{"active": false, "frames": 4, "anim": "E6"},
			{"active": false, "frames": 4, "anim": "E7"},
			{"active": true, "frames": 4, "self_launch": 4.5, "dmg": 6, "knockback": 1, "launch": 7.5, "angle": 85.0, "size": Vector3(0.8, 1.0, 0.8), "offset": Vector3(0.0, 0.5, -0.4), "anim": "E8"},
			{"active": true, "frames": 4, "dmg": 6, "knockback": 2, "launch": 8.5, "angle": 85.0, "size": Vector3(0.8, 1.0, 0.8), "offset": Vector3(0.0, 1.0, -0.6), "anim": "E9"},
			{"active": false}
		]
		input_buf.clear_input_buffer()
		sm.start_attack(uppercut, 0.0)
		return

	if (input_buf.check_combo(hat_trick, fighter.facing_sign) or (is_back and lp)) and sm.current_move == sm.MoveState.GROUND:
		print("KUNG LAO: SOMBRERAZO")
		var hat_throw = [
			{"active": false, "frames": 4, "anim": "L1"},
			{"active": false, "frames": 4, "anim": "L2"},
			{"active": false, "frames": 4, "anim": "L4"},
			{"active": true, "frames": 5, "dmg": 4, "velocity": Vector3(0, 0, 9.0), "knockback": 2, "sprite": "N4", "anim": "L5"},
			{"active": true, "frames": 5, "dmg": 4, "velocity": Vector3(0, 0, 9.0), "knockback": 2, "sprite": "N5", "anim": "L6"},
			{"active": true, "frames": 5, "dmg": 4, "velocity": Vector3(0, 0, 9.0), "knockback": 2, "sprite": "N6", "anim": "L6"},
			{"active": false}
		]
		input_buf.consume_attack_input("light_punch")
		input_buf.clear_input_buffer()
		sm.start_attack(hat_throw)
		return

	# ══ 3. Ataques base ══

	# LP en suelo
	if lp and sm.current_move == sm.MoveState.GROUND:
		print("Kung Lao: Puño Débil")
		var putazo = [
			{"active": false, "frames": 4, "anim": "H2"},
			{"active": true, "frames": 4, "dmg": 2, "size": Vector3(0.6, 0.6, 1.0), "anim": "H3"},
			{"active": false, "frames": 1, "anim": "H5"}
		]
		input_buf.consume_attack_input("light_punch")
		sm.start_attack(putazo, 0.0, 0.15, "lp_ground")
		return

	# LP en aire
	elif lp and sm.current_move == sm.MoveState.AIR:
		print("Kung Lao: Puño Débil Aéreo")
		var putazo = [
			{"active": true, "frames": 16, "dmg": 2, "size": Vector3(0.6, 0.6, 1.0), "offset": Vector3(0.0, -0.6, -0.8), "anim": "F11"},
			{"active": false, "frames": 4}
		]
		input_buf.consume_attack_input("light_punch")
		sm.start_attack(putazo, 0.0, 0.15, "lp_air")
		return

	# HP en suelo
	if hp and sm.current_move == sm.MoveState.GROUND:
		print("Kung Lao: Puño Fuerte")
		var putazo = [
			{"active": false, "frames": 4, "anim": "G1"},
			{"active": false, "frames": 4, "anim": "G2"},
			{"active": true, "frames": 8, "dmg": 3, "size": Vector3(0.8, 0.6, 0.8), "offset": Vector3(0.0, 0.8, -0.8), "anim": "G3"},
			{"active": false, "frames": 4, "anim": "G4"},
			{"active": false, "frames": 4, "anim": "G5"},
			{"active": true, "frames": 8, "dmg": 4, "knockback": 4.5, "size": Vector3(0.8, 0.6, 0.8), "offset": Vector3(0.0, 0.8, -0.8), "anim": "G6"},
			{"active": false, "frames": 4, "anim": "G5"}
		]
		input_buf.consume_attack_input("heavy_punch")
		sm.start_attack(putazo, 0.0, 0.15, "hp_ground")
		return

	# HP en aire
	elif hp and sm.current_move == sm.MoveState.AIR:
		print("Kung Lao: Puño Fuerte Aéreo")
		var putazo = [
			{"active": true, "frames": 16, "dmg": 4, "knockback": 4.5, "size": Vector3(0.8, 0.6, 0.8), "offset": Vector3(0.0, -0.6, -0.8), "anim": "F11"},
			{"active": false, "frames": 4}
		]
		input_buf.consume_attack_input("heavy_punch")
		sm.start_attack(putazo, 0.0, 0.15, "hp_air")
		return

	# HK con crouch (heavykirk)
	if input_buf.check_combo(heavykirk, fighter.facing_sign) and sm.current_move == sm.MoveState.GROUND:
		print("Kung Lao: Patada Fuerte (Agachado)")
		var patadon = [
			{"active": false, "frames": 4, "anim": "E10"},
			{"active": false, "frames": 4, "anim": "E11"},
			{"active": true, "frames": 16, "dmg": 5, "knockback": 5.0, "launch": 3.0, "angle": 45.0, "size": Vector3(1.0, 1.0, 1.5), "anim": "E12", "low": true},
			{"active": false, "frames": 4, "anim": "E11"}
		]
		input_buf.consume_attack_input("heavy_kick")
		sm.start_attack(patadon, 0.0, 0.15, "hk_low")
		return

	# HK en suelo
	if hk and sm.current_move == sm.MoveState.GROUND:
		print("Kung Lao: Patada Fuerte")
		var patadon = [
			{"active": false, "frames": 4, "anim": "I19"},
			{"active": false, "frames": 4, "anim": "I20"},
			{"active": true, "frames": 16, "dmg": 5, "knockback": 5.0, "launch": 3.0, "angle": 45.0, "size": Vector3(1.0, 1.0, 1.5), "anim": "I21"},
			{"active": false, "frames": 4, "anim": "I14"}
		]
		input_buf.consume_attack_input("heavy_kick")
		sm.start_attack(patadon, 0.0, 0.15, "hk_ground")
		return

	elif hk and (sm.current_move == sm.MoveState.DASH or sm.current_move == sm.MoveState.RUN):
		print("Kung Lao: Patada Dash")
		var patadon = [
			{"active": false, "frames": 4, "anim": "E13"},
			{"active": true, "frames": 16, "dmg": 5, "knockback": 1.0, "launch": 6.0, "angle": 90.0, "size": Vector3(0.8, 0.6, 0.8), "offset": Vector3(0.0, -0.8, -0.8), "anim": "E14"},
			{"active": false, "frames": 8, "anim": "E13"}
		]
		input_buf.consume_attack_input("heavy_kick")
		sm.start_attack(patadon, 0.0, 0.15, "hk_dash")
		return

	elif hk and sm.current_move == sm.MoveState.AIR:
		print("Kung Lao: Patada Fuerte Aérea")
		var patadon = [
			{"active": true, "frames": 16, "dmg": 5, "knockback": 5.0, "launch": 3.0, "angle": 45.0, "size": Vector3(0.8, 0.6, 0.8), "offset": Vector3(0.0, -0.8, -0.8), "anim": "F13"},
			{"active": false, "frames": 4},
		]
		input_buf.consume_attack_input("heavy_kick")
		sm.start_attack(patadon, 0.0, 0.15, "hk_air")
		return

	# LK con crouch (lowkirk)
	if input_buf.check_combo(lowkirk, fighter.facing_sign) and sm.current_move == sm.MoveState.GROUND:
		print("Kung Lao: Patada Débil (Agachado)")
		var patadon = [
			{"active": false, "frames": 4, "anim": "E10"},
			{"active": false, "frames": 4, "anim": "E13"},
			{"active": true, "frames": 6, "dmg": 2, "knockback": 1.5, "size": Vector3(0.8, 0.8, 1.2), "anim": "E14", "low": true},
			{"active": false, "frames": 6, "anim": "E13"}
		]
		input_buf.consume_attack_input("light_kick")
		sm.start_attack(patadon, 0.0, 0.15, "lk_low")
		return

	# LK en suelo
	if lk and sm.current_move == sm.MoveState.GROUND:
		print("Kung Lao: Patada Débil")
		var patadon = [
			{"active": false, "frames": 4, "anim": "I1"},
			{"active": false, "frames": 4, "anim": "I2"},
			{"active": true, "frames": 6, "dmg": 2, "knockback": 1.5, "size": Vector3(0.8, 0.8, 1.2), "anim": "I7"},
			{"active": false, "frames": 2, "anim": "I1"}
		]
		input_buf.consume_attack_input("light_kick")
		sm.start_attack(patadon, 0.0, 0.15, "lk_ground")
		return

	elif lk and sm.current_move == sm.MoveState.AIR:
		print("Kung Lao: Patada Débil Aérea")
		var patadon = [
			{"active": true, "frames": 16, "dmg": 2, "knockback": 1.5, "size": Vector3(0.8, 0.6, 0.8), "offset": Vector3(0.0, -0.8, -0.8), "anim": "F12"},
			{"active": false, "frames": 4},
		]
		input_buf.consume_attack_input("light_kick")
		sm.start_attack(patadon, 0.0, 0.15, "lk_air")
		return
