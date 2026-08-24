extends Node
class_name KungLaoAI

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

# ─── Temporizadores ───────────────────────────────────────────────────────────
var _decision_timer := 0.0
var _hold_timer := 0.0
var _knockdown_timer := 0.0
var _aa_cooldown := 0.0
var _tornado_cooldown := 0.0
var _hat_cooldown := 0.0

# ─── Configuración ──────────────────────────────────────────────────────────
@export var reaction_time := 0.10
@export var decision_interval := 0.07
@export var aggression := 0.85
@export var sidestep_tendency := 0.35
@export var pressure_rate := 0.80
@export var whiff_punish_rate := 0.60
@export var fakeout_rate := 0.30

@export var close_range := 1.6
@export var mid_range := 2.8
@export var far_range := 4.5

@export var memory_decay := 0.15 # Velocidad de "olvido" de los patrones del rival
@export var jump_in_weight := 0.9 # afinidad base por el salto cruzado en mixup
@export var reposition_weight := 0.8 # afinidad base por rodear con sidestep

# ─── Memoria del rival ──────────────────────────────────────────────────────
# Tres lecturas en [0, 1] que suben con el patrón y decaen solas; sesgan las decisiones.
var _read_projectile := 0.0 # el rival zonea con proyectiles
var _read_aggression := 0.0 # el rival presiona/ataca de cerca seguido
var _read_whiffs := 0.0 # el rival deja huecos punishables

# ─── Deriva de estilo ─────────────────────────────────────────────────────────
var _style_bias := {"pressure": 0.5, "zoning": 0.5, "mixup": 0.5}
var _style_target := {"pressure": 0.5, "zoning": 0.5, "mixup": 0.5}
var _style_timer := 0.0
const STYLE_DRIFT_INTERVAL := 1.5

func _ready() -> void:
	fighter = get_parent() as FighterBody
	_reset_state()

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
	_tornado_cooldown -= delta
	_hat_cooldown -= delta
	_knockdown_timer = _knockdown_timer + delta if sm and sm.is_knocked_down else 0.0

	# Las lecturas decaen solas si el rival deja el patrón
	_read_projectile = maxf(0.0, _read_projectile - delta * memory_decay)
	_read_aggression = maxf(0.0, _read_aggression - delta * memory_decay)
	_read_whiffs = maxf(0.0, _read_whiffs - delta * memory_decay)

	# El estilo deriva hacia un objetivo aleatorio, no salta entre modos fijos.
	_style_timer += delta
	if _style_timer >= STYLE_DRIFT_INTERVAL:
		_style_timer = 0.0
		_style_target = {"pressure": randf(), "zoning": randf(), "mixup": randf()}
	for k in _style_bias.keys():
		_style_bias[k] = lerpf(_style_bias[k], _style_target[k], delta * 1.2)

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

# ─── Contrato ─────────────────────────────────────────────────────────────
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

# ─── Movimientos ─────────────────────────────────────────────────────────
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

func _hat_motion() -> Array:
	var f := float(fighter.facing_sign) if fighter else 1.0
	return [[ {"dir_x": - 1.0 * f}, 4], [ {"dir_x": 1.0 * f}, 4], [ {"dir_x": 1.0 * f, "light_punch": true}, 1]]

func _tornado_motion() -> Array:
	var f := float(fighter.facing_sign) if fighter else 1.0
	return [[ {"dir_x": - 1.0 * f}, 3], [ {"dir_x": - 1.0 * f, "crouch": true}, 3], [ {"dir_x": 1.0 * f}, 3], [ {"dir_x": 1.0 * f, "heavy_punch": true}, 1]]

func _uppercut_motion() -> Array:
	return [[ {"crouch": true}, 2], [ {"crouch": true, "heavy_punch": true}, 1]]

func _low_poke() -> Array:
	return [[ {"crouch": true}, 1], [ {"crouch": true, "light_kick": true}, 1]]

func _string_beatup() -> Array:
	return [[ {"light_punch": true}, 1], [ {}, 6], [ {"light_punch": true}, 1], [ {}, 18], [ {"light_kick": true}, 1], [ {}, 24], [ {"heavy_punch": true}, 1]]

func _fwd_tap() -> String:
	return "double_tap_right" if fighter.facing_sign > 0 else "double_tap_left"

func _back_tap() -> String:
	return "double_tap_left" if fighter.facing_sign > 0 else "double_tap_right"

func _sidestep_taps(side: float) -> void:
	_current_state["double_tap_up"] = side > 0
	_current_state["double_tap_down"] = side < 0

# ─── Ayudantes ────────────────────────────────────────────────────────────
func _get_distance() -> float:
	if not rival or not sm or not fighter:
		return 999.0
	var fight_axis: Vector3 = fighter.get_fight_axis()
	return abs(fight_axis.dot(rival.global_position - fighter.global_position))

func _is_rival_in_recovery() -> bool:
	if not rival or not rival.state_machine:
		return false
	var rsm := rival.state_machine
	return rsm.current_action == rsm.ActionState.ATTACK and rsm.get_remaining_attack_frames() > 0 and rsm._timeline_idx >= rsm._attack_timeline.size() - 2

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
	if rsm.current_action != rsm.ActionState.ATTACK:
		return false
	if rsm.get_remaining_attack_frames() <= 0:
		return false
	if rival.facing_sign != fighter.facing_sign:
		return false
	return true

# La lectura del rival ajusta estas probabilidades en tiempo real
func _effective_sidestep_tendency() -> float:
	return clampf(sidestep_tendency + _read_projectile * 0.3 + _read_aggression * 0.3, 0.0, 0.95)

func _effective_whiff_punish_rate() -> float:
	return clampf(whiff_punish_rate + _read_whiffs * 0.25, 0.0, 0.95)

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
	var rival_desperate := float(rival.stats.get("current_health", 100)) < 25.0
	var aggr := clampf(aggression + (0.2 if desperate else 0.0) + (0.25 if rival_desperate else 0.0), 0.0, 1.0)
	var f_sign: float = float(fighter.facing_sign)

	# Actualizar lecturas del rival con lo que se observa este ciclo
	if projectile_threat:
		_read_projectile = clampf(_read_projectile + 0.5, 0.0, 1.0)
	if rival_attacking and dist <= close_range + 0.5:
		_read_aggression = clampf(_read_aggression + 0.35, 0.0, 1.0)
	if _can_whiff_punish():
		_read_whiffs = clampf(_read_whiffs + 0.3, 0.0, 1.0)

	# Reflejos: hay que reaccionar ya, no elegir con calma

	# 0) Despierte de knockdown
	if sm.is_knocked_down:
		if _knockdown_timer > 0.5:
			if dist > 2.0 and _tornado_cooldown <= 0.0:
				_queue_intent(_tornado_motion())
				_tornado_cooldown = 1.8
			else:
				_current_state["light_punch"] = true
		return

	# 1) Proyectil entrante → sidestep, y perseguir el castigo si esquiva
	if projectile_threat and dist > 2.0:
		if randf() < _effective_sidestep_tendency():
			_sidestep_taps(1.0 if randf() > 0.5 else -1.0)
			_hold_timer = 0.3
			if randf() < 0.55:
				_queue_intent([[ {"dir_x": 1.0 * f_sign}, 6], [ {"dir_x": 1.0 * f_sign, "light_punch": true}, 1]])
			return

	# 2) Castigar un whiff visible
	if _can_whiff_punish() and randf() < _effective_whiff_punish_rate():
		if dist <= close_range + 0.3:
			_current_state["light_punch" if randf() < 0.5 else "heavy_punch"] = true
			_held["dir_x"] = 1.0 * f_sign
			_hold_timer = 0.15
			return
		elif dist <= mid_range and _tornado_cooldown <= 0.0:
			_queue_intent(_tornado_motion())
			_tornado_cooldown = 1.2
			_hold_timer = 0.4
			return

	# 3) Rival atacando de cerca → defensa (bloqueo, back-dash o sidestep+castigo)
	if _is_rival_attacking_close():
		var roll := randf()
		var sidestep_chance := _effective_sidestep_tendency()
		if roll < 0.40 * (1.0 - sidestep_chance * 0.4):
			_held["guard"] = true
			_held["dir_x"] = -1.0 * f_sign
			if randf() < 0.35:
				_held["crouch"] = true
		elif roll < 0.55:
			_current_state[_back_tap()] = true
		else:
			_sidestep_taps(1.0 if randf() > 0.5 else -1.0)
			if randf() < 0.55:
				_queue_intent([[ {}, 4], [ {"dir_x": 1.0 * f_sign}, 4], [ {"dir_x": 1.0 * f_sign, "heavy_punch": true}, 1]])
		_hold_timer = 0.25
		return

	# 4) Anti-aéreo
	if rival_in_air and dist <= 2.0 and _aa_cooldown <= 0.0:
		if randf() < 0.45:
			_queue_intent(_uppercut_motion())
			_aa_cooldown = 0.9
			_hold_timer = 0.5
			return

	# Sin urgencias: se arma una lista de candidatos y se elige por puntaje

	var candidates: Array = []

	if sm.is_in_cancel_window(10):
		var s_offense := _score_close_offense(dist, aggr)
		if s_offense > 0.0:
			candidates.append({"id": "close_offense", "score": s_offense})

		var s_hat := _score_hat_zone(dist)
		if s_hat > 0.0:
			candidates.append({"id": "hat_zone", "score": s_hat})

		var s_jump := _score_jump_in(dist, rival_in_air, aggr)
		if s_jump > 0.0:
			candidates.append({"id": "jump_in", "score": s_jump})

	var s_reposition := _score_reposition(dist)
	if s_reposition > 0.0:
		candidates.append({"id": "reposition", "score": s_reposition})

	var s_advance := _score_advance(dist)
	if s_advance > 0.0:
		candidates.append({"id": "advance", "score": s_advance})

	var s_retreat := _score_retreat(dist)
	if s_retreat > 0.0:
		candidates.append({"id": "retreat", "score": s_retreat})

	var s_fakeout := _score_fakeout(dist)
	if s_fakeout > 0.0:
		candidates.append({"id": "fakeout", "score": s_fakeout})

	if candidates.is_empty():
		return

	var choice := _weighted_pick(candidates)
	_execute(choice.get("id", ""), rival_crouching, aggr, f_sign)

# ─── Puntajes de candidatos ──────────────────────────────────────────────────
func _score_close_offense(dist: float, aggr: float) -> float:
	if dist > close_range:
		return 0.0
	return 1.0 * pressure_rate * aggr * (0.6 + _style_bias["pressure"] * 0.8)

func _score_hat_zone(dist: float) -> float:
	if _hat_cooldown > 0.0 or dist <= close_range or dist >= far_range:
		return 0.0
	# Si el rival ya avienta proyectiles seguido, bajarle prioridad a esto
	var base: float = 0.9 * (0.6 + _style_bias["zoning"] * 0.8)
	return maxf(0.0, base - _read_projectile * 0.5)

func _score_jump_in(dist: float, rival_in_air: bool, aggr: float) -> float:
	if rival_in_air or dist <= close_range or dist > mid_range:
		return 0.0
	var base: float = jump_in_weight * aggr * (0.6 + _style_bias["mixup"] * 0.8)
	# Si el rival avanza mucho, un salto cruzado lo agarra desprevenido
	return base + _read_aggression * 0.4

func _score_reposition(dist: float) -> float:
	if dist < close_range * 0.7:
		return 0.0
	var base := reposition_weight * sidestep_tendency
	# Rodear a un rival presionador rompe su timing sin arriesgar nada
	return base + _read_aggression * 0.5

func _score_advance(dist: float) -> float:
	if dist <= close_range:
		return 0.2
	return 1.0

func _score_retreat(dist: float) -> float:
	if dist >= 1.0:
		return 0.0
	return 0.3

func _score_fakeout(dist: float) -> float:
	if dist <= mid_range or _hold_timer > 0.0:
		return 0.0
	return fakeout_rate

func _weighted_pick(candidates: Array) -> Dictionary:
	var total := 0.0
	for c in candidates:
		total += maxf(float(c["score"]), 0.0)
	if total <= 0.0:
		return {}
	var roll := randf() * total
	var acc := 0.0
	for c in candidates:
		acc += maxf(float(c["score"]), 0.0)
		if roll <= acc:
			return c
	return candidates[-1]

# ─── Ejecución de la acción elegida ───────────────────────────────────────────
func _execute(id: String, rival_crouching: bool, aggr: float, f_sign: float) -> void:
	match id:
		"close_offense":
			_handle_pressure(rival_crouching, aggr, f_sign)
		"hat_zone":
			_queue_intent(_hat_motion())
			_hat_cooldown = 1.5
			_hold_timer = 0.5
		"jump_in":
			_current_state["jump"] = true
			_current_state["jump_just_pressed"] = true
			_held["dir_x"] = 1.0 * f_sign
			_hold_timer = 0.35
		"reposition":
			_sidestep_taps(1.0 if randf() > 0.5 else -1.0)
			_hold_timer = 0.2
		"advance":
			_held["dir_x"] = 1.0 * f_sign
			_hold_timer = 0.15
			if randf() < 0.3:
				_current_state[_fwd_tap()] = true
		"retreat":
			_held["dir_x"] = -1.0 * f_sign
			_hold_timer = 0.15
		"fakeout":
			_held["dir_x"] = -1.0 * f_sign
			_hold_timer = 0.2
			var fake_hold := _held.duplicate()
			fake_hold["dir_x"] = 1.0 * f_sign
			_held = fake_hold
			_hold_timer = 0.4

# ─── Sub-rutina de presión cuerpo a cuerpo ──────────────────────────────────
func _handle_pressure(rival_crouching: bool, aggr: float, f_sign: float) -> void:
	var roll := randf()
	if rival_crouching:
		if randf() < 0.5:
			_queue_intent(_low_poke())
		else:
			_current_state["light_punch"] = true
	elif roll < 0.35 * aggr:
		_queue_intent(_string_beatup())
	elif roll < 0.55 * aggr:
		_current_state["light_punch"] = true
	elif roll < 0.75 * aggr:
		if _tornado_cooldown <= 0.0:
			_queue_intent(_tornado_motion())
			_tornado_cooldown = 1.2
	elif roll < 0.90:
		_current_state["heavy_punch"] = true
	else:
		_held["dir_x"] = -1.0 * f_sign
	_hold_timer = 0.12
