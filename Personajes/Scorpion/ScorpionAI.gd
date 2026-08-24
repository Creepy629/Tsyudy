extends Node
class_name ScorpionAI

# ─── Referencias ─────────────────────────────────────────────────────────────
var fighter: FighterBody
var rival: FighterBody
var sm: FighterStateMachine

# ─── Buffer de inputs ─────────────────────────────────────────────────────────
var _input_buffer: Array = []
const BUFFER_SIZE := 45

# ─── Estado actual de input ───────────────────────────────────────────────────
var _current_state: Dictionary = {}
var _held: Dictionary = {"dir_x": 0.0, "guard": false, "crouch": false}
var _intent_queue: Array = []

# ─── Temporizadores ──────────────────────────────────────────────────────────
var _decision_timer := 0.0
var _hold_timer := 0.0
var _knockdown_timer := 0.0
var _aa_cooldown := 0.0
var _spear_cooldown := 0.0
var _teleport_cooldown := 0.0
var _tick_timer := 0.0
var _current_tick := 0

# ─── Configuración ───────────────────────────────────────────────────────────
@export var reaction_time := 0.12
@export var decision_interval := 0.08
@export var aggression := 0.75
@export var sidestep_tendency := 0.45
@export var pressure_rate := 0.70
@export var whiff_punish_rate := 0.55
@export var fakeout_rate := 0.25

@export var close_range := 1.5
@export var mid_range := 3.5
@export var far_range := 6.0

# ─── Ticks de comportamiento ─────────────────────────────────────────────────
# Cada tick cambia el "modo" de la IA para no ser predecible.
const TICK_DURATION := 0.6
const TICK_MODES: PackedStringArray = ["pressure", "zoning", "whiff_punish", "mixup"]

func _ready() -> void:
	fighter = get_parent() as FighterBody
	_reset_state()
	_current_tick = randi() % TICK_MODES.size()

func _physics_process(delta: float) -> void:
	if not fighter:
		return
	if not rival and fighter.rival:
		rival = fighter.rival
	if not sm and fighter.state_machine:
		sm = fighter.state_machine

	# Respetar congelamiento de match
	if fighter.match_frozen:
		_reset_state()
		_intent_queue.clear()
		_held = {"dir_x": 0.0, "guard": false, "crouch": false}
		return

	# Timers
	_hold_timer -= delta
	_aa_cooldown -= delta
	_spear_cooldown -= delta
	_teleport_cooldown -= delta
	_knockdown_timer = _knockdown_timer + delta if sm and sm.is_knocked_down else 0.0
	_tick_timer += delta

	# Cambiar tick periódicamente para variar comportamiento
	if _tick_timer >= TICK_DURATION:
		_tick_timer = 0.0
		_current_tick = (_current_tick + 1 + randi() % (TICK_MODES.size() - 1)) % TICK_MODES.size()

	_reset_state()

	# Procesar cola de intenciones (secuencias de comandos)
	if _intent_queue.size() > 0:
		var head: Array = _intent_queue[0]
		for k in head[0]:
			_current_state[k] = head[0][k]
		head[1] -= 1
		if head[1] <= 0:
			_intent_queue.pop_front()
	else:
		# Inputs sostenidos (caminar/guardia) persisten entre decisiones
		_current_state["dir_x"] = _held["dir_x"]
		_current_state["guard"] = _held["guard"]
		_current_state["crouch"] = _held["crouch"]
		if _hold_timer <= 0.0:
			_decision_timer += delta
			if _decision_timer >= decision_interval:
				_decision_timer = 0.0
				_evaluate_tactics()

	# Buffer interno
	_input_buffer.push_front(_current_state.duplicate())
	if _input_buffer.size() > BUFFER_SIZE:
		_input_buffer.pop_back()

	# Limpiar gatillos de un solo frame
	_current_state["double_tap_left"] = false
	_current_state["double_tap_right"] = false
	_current_state["double_tap_up"] = false
	_current_state["double_tap_down"] = false
	_current_state["jump_just_pressed"] = false

# ─── Contrato ────────────────────────────────────────────────────────────────
func get_movement_state() -> Dictionary:
	return _current_state

func poll_double_tap() -> void:
	pass

func was_attack_pressed(attack_name: String, buffer_frames: int = 10) -> bool:
	var limit: int = mini(buffer_frames, _input_buffer.size())
	for i in range(limit):
		if bool(_input_buffer[i].get(attack_name, false)):
			return true
	return false

func clear_input_buffer() -> void:
	_input_buffer.clear()

func consume_attack_input(attack_name: String) -> void:
	for entry in _input_buffer:
		entry[attack_name] = false
	_current_state[attack_name] = false

func check_combo(combo: Array, facing: int) -> bool:
	var s := 0
	for i in range(_input_buffer.size() - 1, -1, -1):
		if s < combo.size() and _step_matches(combo[s], _input_buffer[i], facing):
			s += 1
			if s >= combo.size():
				return true
	return false

func _step_matches(step: Dictionary, entry: Dictionary, facing: int) -> bool:
	for key in step:
		var want = step[key]
		if key == "dir_x":
			if float(entry.get("dir_x", 0.0)) * float(facing) != float(want):
				return false
		elif entry.get(key, false) != want:
			return false
	return true

# ─── Movimientos ─────────────────────────────────────────────────────────────
func _reset_state() -> void:
	_current_state = {
		"dir_x": 0.0, "dir_z": 0.0,
		"jump": false, "jump_just_pressed": false,
		"crouch": false, "guard": false,
		"double_tap_left": false, "double_tap_right": false,
		"double_tap_up": false, "double_tap_down": false,
		"heavy_punch": false, "light_punch": false,
		"heavy_kick": false, "light_kick": false
	}

func _queue_intent(seq: Array) -> void:
	for e in seq:
		_intent_queue.append([e[0].duplicate(), int(e[1])])

func _spear_motion() -> Array:
	var f := float(fighter.facing_sign) if fighter else 1.0
	return [[{"dir_x": -1.0 * f}, 4], [{"dir_x": 1.0 * f}, 4], [{"dir_x": 1.0 * f, "light_punch": true}, 1]]

func _teleport_motion() -> Array:
	var f := float(fighter.facing_sign) if fighter else 1.0
	return [[{"dir_x": -1.0 * f}, 4], [{"dir_x": 1.0 * f}, 4], [{"dir_x": 1.0 * f, "heavy_kick": true}, 1]]

func _uppercut_motion() -> Array:
	return [[{"crouch": true}, 2], [{"crouch": true, "heavy_punch": true}, 1]]

func _axe_motion() -> Array:
	var f := float(fighter.facing_sign) if fighter else 1.0
	return [[{"dir_x": -1.0 * f}, 3], [{"dir_x": -1.0 * f, "heavy_punch": true}, 1]]

func _string_lp_lp_hk() -> Array:
	return [[{"light_punch": true}, 1], [{}, 6], [{"light_punch": true}, 1], [{}, 6], [{"heavy_kick": true}, 1]]

func _low_poke() -> Array:
	return [[{"crouch": true}, 1], [{"crouch": true, "light_kick": true}, 1]]

func _fwd_tap() -> String:
	return "double_tap_right" if fighter.facing_sign > 0 else "double_tap_left"

func _back_tap() -> String:
	return "double_tap_left" if fighter.facing_sign > 0 else "double_tap_right"

# ─── Ayudantes de distancia y estado ─────────────────────────────────────────
func _get_distance() -> float:
	if not rival or not sm or not fighter:
		return 999.0
	var fight_axis: Vector3 = fighter.get_fight_axis()
	return abs(fight_axis.dot(rival.global_position - fighter.global_position))

func _is_rival_in_recovery() -> bool:
	if not rival or not rival.state_machine:
		return false
	var rsm := rival.state_machine
	# Si está en hitstun o en recovery de ataque
	return rsm.current_action == rsm.ActionState.HIT or (
		rsm.current_action == rsm.ActionState.ATTACK and
		rsm.get_remaining_attack_frames() > 0 and
		rsm._timeline_idx >= rsm._attack_timeline.size() - 2
	)

func _is_rival_attacking_close() -> bool:
	if not rival or not rival.state_machine:
		return false
	var rsm := rival.state_machine
	var dist := _get_distance()
	return rsm.current_action == rsm.ActionState.ATTACK and dist <= close_range + 0.5

func _can_whiff_punish() -> bool:
	if not rival or not rival.state_machine:
		return false
	var rsm := rival.state_machine
	# Solo castigar si el rival está en recovery y no nos está viendo
	if rsm.current_action != rsm.ActionState.ATTACK:
		return false
	if rsm.get_remaining_attack_frames() <= 0:
		return false
	# Verificar si el rival nos está viendo (no está de espaldas)
	if rival.facing_sign != fighter.facing_sign:
		return false
	return true

# ─── Táctica principal ───────────────────────────────────────────────────────
func _evaluate_tactics() -> void:
	if not rival or not sm or not fighter:
		return

	_held = {"dir_x": 0.0, "guard": false, "crouch": false}
	var rsm: FighterStateMachine = rival.state_machine
	var dist := _get_distance()
	var rival_in_air := rsm.current_move == FighterStateMachine.MoveState.AIR
	var rival_crouching := bool(rival.last_input_state.get("crouch", false))
	var rival_attacking := rsm.current_action == FighterStateMachine.ActionState.ATTACK
	var projectile_threat := rival_attacking and (rsm._hitbox_velocity != Vector3.ZERO or rsm.current_attack_name in ["spear", "hat_throw"])
	var desperate := float(fighter.stats.get("current_health", 100)) < 25.0
	var aggr := clampf(aggression + (0.25 if desperate else 0.0), 0.0, 1.0)
	var f_sign: float = float(fighter.facing_sign)
	var current_tick_mode := TICK_MODES[_current_tick]

	# 0) Despierte de knockdown
	if sm.is_knocked_down:
		if _knockdown_timer > 0.5:
			# Opciones de wake-up: spear si hay espacio, sino punch
			if dist > 2.0 and _spear_cooldown <= 0.0:
				_queue_intent(_spear_motion())
				_spear_cooldown = 1.5
			else:
				_current_state["light_punch"] = true
		return

	# 1) Proyectil entrante → sidestep inteligente
	if projectile_threat and dist > 2.0:
		if randf() < sidestep_tendency:
			# Sidestep hacia el lado opuesto al proyectil (si viene recto, aleatorio)
			var side := 1.0 if randf() > 0.5 else -1.0
			_current_state["double_tap_up"] = true if side > 0 else false
			_current_state["double_tap_down"] = true if side < 0 else false
			_hold_timer = 0.3
			return

	# 2) Whiff punish (castigar cuando el rival falla)
	if _can_whiff_punish() and randf() < whiff_punish_rate:
		var punish_range := _get_distance()
		if punish_range <= close_range + 0.3:
			# Castigar con golpe rápido
			if randf() < 0.6:
				_current_state["light_punch"] = true
			else:
				_current_state["heavy_punch"] = true
			_held["dir_x"] = 1.0 * f_sign
			_hold_timer = 0.15
			return
		elif punish_range <= mid_range:
			# Spear como castigo a distancia
			if _spear_cooldown <= 0.0:
				_queue_intent(_spear_motion())
				_spear_cooldown = 1.2
				_hold_timer = 0.4
				return

	# 3) Rival atacando cerca → defensa
	if _is_rival_attacking_close():
		var roll := randf()
		if roll < 0.50:
			_held["guard"] = true
			_held["dir_x"] = -1.0 * f_sign
			if randf() < 0.30:
				_held["crouch"] = true
		elif roll < 0.75:
			# Backdash para crear espacio
			_current_state[_back_tap()] = true
		else:
			# Sidestep para contragolpe
			_current_state["double_tap_up" if randf() > 0.5 else "double_tap_down"] = true
		_hold_timer = 0.25
		return

	# 4) Anti-aéreo mejorado
	if rival_in_air and dist <= 2.2 and _aa_cooldown <= 0.0:
		if randf() < 0.45:
			_queue_intent(_uppercut_motion())
			_aa_cooldown = 0.9
			_hold_timer = 0.5
			return

	# 5) Ofensiva según tick y distancia
	if sm.is_in_cancel_window(10):
		match current_tick_mode:
			"pressure":
				# Modo presión: encadenar golpes cerca
				if dist <= close_range:
					_handle_pressure(rival_crouching, aggr, f_sign)
					return
				# Si está lejos, acercarse corriendo
				if dist > mid_range and randf() < 0.5:
					_current_state[_fwd_tap()] = true
					_held["dir_x"] = 1.0 * f_sign
					_hold_timer = 0.2
					return

			"zoning":
				# Modo control de espacio: spear a media distancia
				if dist > mid_range and dist < far_range and _spear_cooldown <= 0.0:
					_queue_intent(_spear_motion())
					_spear_cooldown = 1.5
					_hold_timer = 0.5
					return
				if dist > close_range:
					_held["dir_x"] = 1.0 * f_sign
					_hold_timer = 0.15
					return

			"whiff_punish":
				# Modo castigo: esperar y atacar en recovery
				if dist <= close_range and _is_rival_in_recovery():
					if randf() < 0.7:
						_current_state["light_punch"] = true
					else:
						_current_state["heavy_punch"] = true
					_hold_timer = 0.12
					return
				_held["dir_x"] = 1.0 * f_sign
				_hold_timer = 0.1
				return

			"mixup":
				# Modo mezcla: movimientos impredecibles
				if dist <= close_range:
					var roll := randf()
					if roll < 0.3:
						_queue_intent(_string_lp_lp_hk())
					elif roll < 0.5:
						_current_state["light_punch"] = true
					elif roll < 0.7:
						_current_state["heavy_punch"] = true
					elif roll < 0.85 and _teleport_cooldown <= 0.0:
						_queue_intent(_teleport_motion())
						_teleport_cooldown = 2.0
					else:
						_held["dir_x"] = -1.0 * f_sign
					_hold_timer = 0.12
					return
				if dist > mid_range and _spear_cooldown <= 0.0 and randf() < 0.4:
					_queue_intent(_spear_motion())
					_spear_cooldown = 1.2
					return

	# 6) Gestión espacial (si no atacamos)
	if dist > close_range:
		var approach := 1.0 * f_sign
		# A veces hacer fake-out: caminar y retroceder
		if dist > mid_range and randf() < fakeout_rate and _hold_timer <= 0.0:
			_held["dir_x"] = -1.0 * f_sign
			_hold_timer = 0.2
			# Luego acercarse
			var fake_hold = _held.duplicate()
			fake_hold["dir_x"] = approach
			_held = fake_hold
			_hold_timer = 0.4
			return
		_held["dir_x"] = approach
		# Dash si está muy lejos
		if dist > far_range * 0.7:
			_current_state[_fwd_tap()] = true
	elif dist < 1.0 and randf() < 0.25:
		_held["dir_x"] = -1.0 * f_sign

# ─── Sub-rutinas de presión ──────────────────────────────────────────────────
func _handle_pressure(rival_crouching: bool, aggr: float, f_sign: float) -> void:
	var roll := randf()
	if rival_crouching:
		# Si el rival está agachado, low poke o spear cancel
		if randf() < 0.5:
			_queue_intent(_low_poke())
		else:
			_current_state["light_punch"] = true
	elif roll < 0.35 * aggr:
		# String LP → LP → HK
		_queue_intent(_string_lp_lp_hk())
	elif roll < 0.55 * aggr:
		_current_state["light_punch"] = true
	elif roll < 0.75 * aggr:
		# Axe kick overhead
		_queue_intent(_axe_motion())
	elif roll < 0.90:
		_current_state["heavy_punch"] = true
	else:
		# Cancel hacia atrás para spacing
		_held["dir_x"] = -1.0 * f_sign
	_hold_timer = 0.12
