class_name FighterStateMachine
extends Node

enum MoveState {GROUND, AIR, DASH, BACKDASH, SIDESTEP, RUN}
enum ActionState {IDLE, ATTACK, HIT, GUARD}

var current_move: MoveState = MoveState.GROUND
var current_action: ActionState = ActionState.IDLE
var current_attack_name: String = ""
var is_knocked_down := false
var _was_launched := false
var _kd_timer := 0.0
var fighter: FighterBody
var wants_up
var is_blocking := false
var _combo_received := 0

# --- Tiempos ---
var action_timer := 0.0
var move_timer := 0.0

# --- Parámetros de Acción ---
var action_duration := 0.0
var advance_speed := 0.0
var current_hitbox: Node
var attached_hitbox: Node = null

# --- Parámetros de Movimiento ---
var _locked_vel_x := 0.0
var _locked_vel_z := 0.0
var _sidestep_dir_locked := 0.0
var _attack_timeline: Array = []
var _timeline_idx: int = -1
var _frame_accumulator: float = 0.0
var _attack_advance_speed: float = 0.0
var _base_advance_speed: float = 0.0
var _global_hitstop: float = 0.0
var _hitbox_velocity: Vector3 = Vector3.ZERO
var max_fighter_distance: float = 8.0

const DASH_DURATION := 0.22
const BACKDASH_DURATION := 0.20
const CROUCH_SPEED_MULT := 0.5
const SIDESTEP_STEP_DURATION := 0.25
const SIDESTEP_HOLD_SPEED_MULT := 0.6
const SS_BURST_SPEED := 9.0
const SS_BURST_DECAY_TIME := 0.12
const SS_WALK_SPEED := 3.0

func _init(f: FighterBody):
	fighter = f

func process_machine(delta: float, input: Dictionary) -> void:
	# Actualizar temporizadores
	if current_action != ActionState.IDLE:
		action_timer += delta
		
	# Lógica de Acciones
	_process_action_state(delta, input)
	
	# Lógica de Movimiento
	_process_move_state(delta, input)

	_update_hurtbox_shape(input)

	if fighter.rival:
		var fight_dir_lim: Vector3 = fighter.get_fight_axis()
		var to_rival: float = fight_dir_lim.dot(fighter.rival.global_position - fighter.global_position)
		var dist: float = abs(to_rival)
		if dist > max_fighter_distance:
			var excess: float = dist - max_fighter_distance
			var vel_along: float = fight_dir_lim.dot(fighter.velocity)
			# Determinar si YO soy quien se está alejando del rival
			var i_am_moving_away: bool = sign(vel_along) != sign(to_rival) and abs(vel_along) > 0.05
			if i_am_moving_away:
				# Yo me alejé: cancelo mi velocidad en ese eje y me devuelvo al límite
				fighter.velocity.x -= fight_dir_lim.x * vel_along
				fighter.velocity.z -= fight_dir_lim.z * vel_along
				fighter.global_position += fight_dir_lim * sign(to_rival) * excess
			# Si nadie se está moviendo (ej: lanzados por hitbox), corrección suave sin tocar al rival
			elif abs(vel_along) <= 0.05:
				fighter.global_position += fight_dir_lim * sign(to_rival) * excess * 0.5

	fighter.move_and_slide()

func _process_action_state(delta: float, input: Dictionary) -> void:
	match current_action:
		ActionState.IDLE:
			pass
			
		ActionState.ATTACK:
			if _attack_timeline.is_empty():
				_end_action()
				return

			# --- AVANCE DE FRAMES (Asumiendo 60 FPS) ---
			_frame_accumulator += delta * 60.0
			var current_step = _attack_timeline[_timeline_idx]
			var step_frames = current_step.get("frames", 1)

			# Si ya pasamos los frames de este paso, avanzamos al siguiente
			if _frame_accumulator >= step_frames:
				_frame_accumulator -= step_frames # Restamos para no perder frames residuales
				_advance_to_next_step()

			# --- Lógica de avance de hitbox por velocidad ---
			if _hitbox_velocity != Vector3.ZERO:
				var hitbox: Hitbox = null
				for child in fighter.get_children():
					if child is Hitbox:
						hitbox = child
						break
				if hitbox and hitbox.visible:
					var hitbox_move_dir: Vector3 = fighter.get_attack_direction()
					hitbox.global_position += hitbox_move_dir * _hitbox_velocity.z * delta
					hitbox.global_position.y += _hitbox_velocity.y * delta
			
			if _attack_advance_speed != 0.0:
				var advance_dir := fighter.get_attack_direction()
				fighter.velocity.x = advance_dir.x * _attack_advance_speed
				fighter.velocity.z = advance_dir.z * _attack_advance_speed
			elif current_move == MoveState.GROUND:
				fighter.velocity.x = lerp(fighter.velocity.x, 0.0, 10.0 * delta)
				fighter.velocity.z = lerp(fighter.velocity.z, 0.0, 10.0 * delta)
		
		ActionState.HIT:
			# --- KNOCKDOWN: tirado en el suelo ---
			if is_knocked_down:
				_kd_timer += delta
				fighter.velocity.x = 0.0
				fighter.velocity.z = 0.0
				if not fighter.match_frozen:
					var wants_up := false
					if fighter.is_ai:
						wants_up = _kd_timer >= 1.0
					else:
						wants_up = (abs(input.get("dir_x", 0.0)) > 0.1
							or abs(input.get("dir_z", 0.0)) > 0.1
							or input.get("jump", false)
							or input.get("light_punch", false)
							or input.get("heavy_punch", false)
							or input.get("light_kick", false)
							or input.get("heavy_kick", false))
					if wants_up or _kd_timer > 2.5:
						is_knocked_down = false
						_was_launched = false
						_end_action()
				return

			# --- ATTACH: pegado a la hitbox (el gancho lo arrastra) ---
			if attached_hitbox != null and is_instance_valid(attached_hitbox) and attached_hitbox.visible:
				var to_target: Vector3 = attached_hitbox.global_position - fighter.global_position
				to_target.y = 0.0
				var d := to_target.length()
				if d > 0.2:
					var follow_speed := clampf(d * 18.0, 0.0, 14.0)
					fighter.velocity.x = (to_target / d).x * follow_speed
					fighter.velocity.z = (to_target / d).z * follow_speed
				else:
					fighter.velocity.x = 0.0
					fighter.velocity.z = 0.0
				fighter.velocity.y = 0.0
			else:
				attached_hitbox = null
				# Fricción para que no resbale eternamente
				fighter.velocity.x = lerp(fighter.velocity.x, 0.0, 6.0 * delta)
				fighter.velocity.z = lerp(fighter.velocity.z, 0.0, 6.0 * delta)
				
			# --- BLINDAJE AÉREO: si fue lanzado, el hitstun NO expira en el aire.
			# Se queda en HIT hasta aterrizar; ahí el landing lo manda a knockdown.
			if _was_launched and current_move == MoveState.AIR:
				return
				
			if state_timer_expired():
				attached_hitbox = null
				_end_action()

func state_timer_expired() -> bool:
	return action_timer >= action_duration

func _end_action() -> void:
	current_action = ActionState.IDLE
	attached_hitbox = null
	if current_hitbox and current_hitbox.has_method("disable_hitbox"):
		current_hitbox.disable_hitbox()
	is_knocked_down = false
	_was_launched = false
	is_blocking = false
	_combo_received = 0
	current_attack_name = ""
	_attack_timeline.clear()
	_timeline_idx = -1
	_attack_advance_speed = 0.0 # FIX: Reseteamos la velocidad de avance para no deslizarnos
	current_hitbox = null
	fighter.exit_attack_mode()

# Retorna cuántos frames (aprox 60fps) le quedan al ataque actual en ejecución
func get_remaining_attack_frames() -> float:
	if current_action != ActionState.ATTACK or _attack_timeline.is_empty() or _timeline_idx < 0:
		return 0.0
	
	var current_step = _attack_timeline[_timeline_idx]
	var step_frames = current_step.get("frames", 1)
	var remaining: float = max(0.0, float(step_frames) - _frame_accumulator)
	
	for i in range(_timeline_idx + 1, _attack_timeline.size()):
		remaining += _attack_timeline[i].get("frames", 1)
		
	return remaining

# Verifica si el personaje está en estado IDLE o a pocos frames de terminar su ataque (ventana de cancelación/input buffer)
func is_in_cancel_window(buffer_frames: float = 10.0) -> bool:
	if current_action == ActionState.IDLE:
		return true
	if current_action == ActionState.ATTACK:
		return get_remaining_attack_frames() <= buffer_frames
	return false

# ── Lógica de Movimiento ──────────────────────────────────────────────────────
func _process_move_state(delta: float, input: Dictionary) -> void:
	if not fighter.is_on_floor():
		if current_move != MoveState.SIDESTEP:
			fighter.velocity.y += FighterBody.GRAVITY * delta
			if current_move == MoveState.GROUND:
				current_move = MoveState.AIR
				_lock_air_velocity()
	else:
		# Solo reseteamos Y si estamos cayendo y tocamos el suelo
		if fighter.velocity.y <= 0.0:
			fighter.velocity.y = 0.0
			if current_move == MoveState.AIR:
				if current_action == ActionState.HIT and _was_launched:
					_enter_knockdown()
				else:
					current_move = MoveState.GROUND

	var fight_dir := fighter.get_fight_axis()

	# Máquina de Movimiento ---
	match current_move:
		MoveState.GROUND:
			# Bloquear movimiento si estamos en Hitstun
			if current_action == ActionState.HIT:
				return

			if current_action == ActionState.ATTACK:
				return

			# facing_sign  1 = personaje a la IZQUIERDA (D = adelante)
			# facing_sign -1 = personaje a la DERECHA (A = adelante)
			if input.double_tap_right:
				var is_forward: bool = fighter.facing_sign > 0 # D es adelante para facing 1
				_start_dash_or_backdash(1.0 * fighter.facing_sign, fight_dir, is_forward)
				return
			elif input.double_tap_left:
				var is_forward: bool = fighter.facing_sign < 0 # A es adelante para facing -1
				_start_dash_or_backdash(-1.0 * fighter.facing_sign, fight_dir, is_forward)
				return

			# Sidestep
			if input.double_tap_up:
				_start_sidestep(-1.0)
				return
			elif input.double_tap_down:
				_start_sidestep(1.0)
				return

			# Salto
			if input.jump_just_pressed:
				_start_jump()
				return

			if abs(input.dir_x) > 0.1 and not input.get("crouch", false):
				var walk_speed: float = fighter.stats.get("walk_speed", 2.5)
				var move_dir: Vector3 = fight_dir * input.dir_x
				fighter.velocity.x = move_dir.x * walk_speed
				fighter.velocity.z = move_dir.z * walk_speed
			else:
				# Frenado / Fricción en el suelo
				fighter.velocity.x = lerp(fighter.velocity.x, 0.0, 12.0 * delta)
				fighter.velocity.z = lerp(fighter.velocity.z, 0.0, 12.0 * delta)

		MoveState.AIR:
			# Si estamos atacando con velocidad de avance, el ataque gobierna la trayectoria horizontal
			if current_action == ActionState.ATTACK and _attack_advance_speed != 0.0:
				pass
			else:
				# Mantener la inercia del salto intacta
				fighter.velocity.x = _locked_vel_x
				fighter.velocity.z = _locked_vel_z

		MoveState.DASH:
			if input.jump_just_pressed:
				_start_jump()
				return

			# Si terminó el dash Y el jugador sigue apretando adelante → transicionar a RUN
			if move_timer >= DASH_DURATION:
				var is_forward_held: bool = (input.dir_x * fighter.facing_sign) > 0.5
				if is_forward_held:
					current_move = MoveState.RUN
				else:
					current_move = MoveState.GROUND
			else:
				move_timer += delta

		MoveState.RUN:
			# Correr: el personaje mantiene la velocidad del dash mientras siga empujando
			if input.jump_just_pressed:
				_start_jump()
				return
			var is_forward_held: bool = (input.dir_x * fighter.facing_sign) > 0.5
			if is_forward_held:
				var run_speed: float = fighter.stats.get("dash_speed", 8.0)
				fighter.velocity.x = fight_dir.x * fighter.facing_sign * run_speed
				fighter.velocity.z = fight_dir.z * fighter.facing_sign * run_speed
			else:
				# Soltó → volver al suelo con frenado suave
				fighter.velocity.x = lerp(fighter.velocity.x, 0.0, 12.0 * delta)
				fighter.velocity.z = lerp(fighter.velocity.z, 0.0, 12.0 * delta)
				if abs(fighter.velocity.x) < 0.1 and abs(fighter.velocity.z) < 0.1:
					current_move = MoveState.GROUND

		MoveState.BACKDASH:
			if move_timer >= BACKDASH_DURATION:
				current_move = MoveState.GROUND
			else:
				move_timer += delta

		MoveState.SIDESTEP:
			if move_timer < SIDESTEP_STEP_DURATION:
				# FASE 1: El paso inicial (Doble tap).
				# Usamos una curva suave (seno) para que acelere y desacelere naturalmente.
				var t = move_timer / SIDESTEP_STEP_DURATION
				var speed_mult = sin(t * PI) # Crea un arco suave: empieza lento, acelera, y frena un poco al final

				fighter.apply_sidestep_motion(_sidestep_dir_locked, delta, speed_mult)
				move_timer += delta

			elif input.dir_z == _sidestep_dir_locked:
				# FASE 2: Manteniendo presionado (Caminata lateral continua y lenta)
				fighter.apply_sidestep_motion(_sidestep_dir_locked, delta, SIDESTEP_HOLD_SPEED_MULT)

			else:
				# FASE 3: Soltaron el botón. FRENADO SUAVE (Lerp) en lugar de corte abrupto.
				# Interpolamos la velocidad a 0 para que el personaje se deslice hasta detenerse.
				fighter.velocity.x = lerp(fighter.velocity.x, 0.0, 10.0 * delta)
				fighter.velocity.z = lerp(fighter.velocity.z, 0.0, 10.0 * delta)

				# Cuando la velocidad es casi nula, regresamos al estado normal limpiamente
				if abs(fighter.velocity.x) < 0.1 and abs(fighter.velocity.z) < 0.1:
					fighter.velocity.x = 0.0
					fighter.velocity.z = 0.0
					current_move = MoveState.GROUND

# ── Triggers ──────────────────────────────────────────────────────────────
func _start_jump() -> void:
	fighter.velocity.y = fighter.stats.get("jump_velocity", 6.0)
	current_move = MoveState.AIR
	_lock_air_velocity()

func _lock_air_velocity() -> void:
	_locked_vel_x = fighter.velocity.x
	_locked_vel_z = fighter.velocity.z

func _start_sidestep(dir_z: float) -> void:
	current_move = MoveState.SIDESTEP
	move_timer = 0.0
	_sidestep_dir_locked = dir_z
	
	# 1. Blindaje físico: Anulamos Y para que el motor de físicas sepa que estamos pegados al suelo.
	fighter.velocity.y = 0.0
	
	# 2. Aplicamos el "Burst" (el paso rápido inicial) usando el eje de profundidad (cam_dir)
	var depth_dir := fighter.fight_plane.cam_dir
	fighter.velocity.x = depth_dir.x * dir_z * SS_BURST_SPEED
	fighter.velocity.z = depth_dir.z * dir_z * SS_BURST_SPEED

func _start_dash_or_backdash(_dir_input: float, fight_dir: Vector3, is_forward: bool) -> void:
	move_timer = 0.0
	if is_forward:
		current_move = MoveState.DASH
		var speed: float = fighter.stats.get("dash_speed", 8.0)
		fighter.velocity.x = fight_dir.x * fighter.facing_sign * speed
		fighter.velocity.z = fight_dir.z * fighter.facing_sign * speed
	else:
		current_move = MoveState.BACKDASH
		var speed: float = fighter.stats.get("backdash_speed", 8.0)
		fighter.velocity.x = - fight_dir.x * fighter.facing_sign * speed
		fighter.velocity.z = - fight_dir.z * fighter.facing_sign * speed

# Recibe un Array de pasos (Timeline), velocidad de avance, hitstop global y opcionalmente el nombre del ataque
func start_attack(timeline: Array, advance: float = 0.0, hitstop: float = 0.15, attack_name: String = "") -> void:
	current_action = ActionState.ATTACK
	current_attack_name = attack_name
	_attack_timeline = timeline
	_timeline_idx = -1 # Se incrementará a 0 en el primer _advance_to_next_step
	_frame_accumulator = 0.0
	_attack_advance_speed = advance
	_base_advance_speed = advance
	_global_hitstop = hitstop
	
	fighter.enter_attack_mode()
	
	# Iniciar el primer paso inmediatamente
	_advance_to_next_step()

func _advance_to_next_step() -> void:
	_timeline_idx += 1
	
	# Si ya no hay más pasos en la timeline, el ataque terminó
	if _timeline_idx >= _attack_timeline.size():
		_end_action()
		return

	var step = _attack_timeline[_timeline_idx]
	var is_active = step.get("active", false)
	
	# Auto-lanzamiento
	if step.has("self_launch"):
		var self_launch_v = step["self_launch"]
		var max_jump = fighter.stats.get("jump_velocity", 6.0)
		# Lo limitamos para que no salga volando al espacio
		fighter.velocity.y = clamp(self_launch_v, 0.0, max_jump + 1.5)
		current_move = MoveState.AIR
		_lock_air_velocity()
	elif step.has("advance_y"):
		fighter.velocity.y = float(step["advance_y"])
	elif step.has("vertical_advance"):
		fighter.velocity.y = float(step["vertical_advance"])
	
	# Teleport atrás del rival
	if step.has("teleport_behind"):
		var r := fighter.rival
		if r:
			var dir_to_rival := fighter.get_fight_axis() * float(fighter.facing_sign)
			var dist_behind: float = float(step["teleport_behind"])
			var new_pos := r.global_position + dir_to_rival * dist_behind
			new_pos.y = fighter.global_position.y
			fighter.global_position = new_pos
			fighter.velocity.x = 0.0
			fighter.velocity.z = 0.0
	
	# Forzar mirar al rival
	if step.has("face_rival") and step["face_rival"]:
		var r := fighter.rival
		if r:
			var target_pos := Vector3(r.global_position.x, fighter.global_position.y, r.global_position.z)
			if target_pos.distance_to(fighter.global_position) > 0.01:
				fighter.look_at(target_pos, Vector3.UP)
				# Recalcular facing_sign inmediatamente
				var side := fighter.fight_plane.fight_dir.dot(fighter.global_position - fighter.fight_plane.global_position)
				fighter.facing_sign = 1 if side <= 0.0 else -1
				# Actualizar la dirección del ataque
				fighter.attack_direction = fighter.get_fight_axis() * float(fighter.facing_sign)

	# Avance por frame data
	_attack_advance_speed = float(step.get("advance", _base_advance_speed))
	
	# Buscamos la Hitbox del fighter
	var hitbox = null
	for child in fighter.get_children():
		if child is Hitbox:
			hitbox = child
			break
			
	if hitbox:
		if is_active:
			# FASE ACTIVA (Hitbox ON)
			hitbox.damage = step.get("dmg", 5)
			
			# Leemos la física directamente del paso de la timeline
			hitbox.knockback = step.get("knockback", 0.0)
			hitbox.launch_velocity = step.get("launch", 0.0)
			hitbox.launch_angle_degrees = step.get("angle", 90.0)
			hitbox.hitstop_duration = _global_hitstop
			
			# Hitstun (cuántos frames se queda quieto el rival). 
			# Si no lo pones en el diccionario, usa el valor por defecto de la Hitbox.
			hitbox.hitstun_frames = step.get("hitstun", hitbox.hitstun_frames)
			hitbox.attach = step.get("attach", false)
			
			hitbox.is_low = step.get("low", false)
			
			# Tamaño y posición de hitbox dinámico
			if step.has("size"):
				hitbox.resize_hitbox(step["size"])
			
			if step.has("offset"):
				hitbox.reposition_hitbox(step["offset"])
			
			# Hitbox velocity
			if step.has("velocity"):
				_hitbox_velocity = step["velocity"]
			else:
				_hitbox_velocity = Vector3.ZERO
			
			# Sprite de proyectil (ej. Sombrero de Kung Lao)
			if step.has("sprite") or step.has("projectile_sprite"):
				var proj_sprite: String = step.get("sprite", step.get("projectile_sprite", ""))
				hitbox.set_projectile_sprite(proj_sprite, fighter.facing_sign)
			else:
				hitbox.clear_projectile_sprite()

			hitbox.enable_hitbox()
		else:
			# FASE INACTIVA (Startup / Recovery / Pausa)
			_hitbox_velocity = Vector3.ZERO
			hitbox.disable_hitbox()

func _enter_knockdown() -> void:
	current_move = MoveState.GROUND
	is_knocked_down = true
	_kd_timer = 0.0
	action_duration = 9999.0 # tirado hasta despertar
	fighter.velocity.x = 0.0
	fighter.velocity.z = 0.0

func take_hit(hitbox: Node, knockback_dir: Vector3, guarded: bool = false) -> void:
	if current_action == ActionState.HIT:
		_combo_received += 1
	else:
		_combo_received = 1
	current_action = ActionState.HIT
	action_timer = 0.0
	is_blocking = guarded

	# Deshabilitar todas las hitboxes del receptor inmediatamente
	for child in fighter.get_children():
		if child is Hitbox and child.has_method("disable_hitbox"):
			child.disable_hitbox()

	# ATTACH (spear/throws)
	if ("attach" in hitbox) and hitbox.attach and not guarded:
		attached_hitbox = hitbox
		fighter.velocity.x = 0.0
		fighter.velocity.z = 0.0
		fighter.velocity.y = 0.0
		action_duration = float(hitbox.hitstun_frames) / 60.0
		return

	# Hitstun decae con el combo (rompe infinitos) y a la mitad si bloqueaste
	# El hitstun base se extiende 1/3 más (factor 4/3) para que los combos sean más sostenidos
	var stun_mult := pow(0.9, clampi(_combo_received - 1, 0, 8))
	var stun_frames := float(hitbox.hitstun_frames) * (0.5 if guarded else 1.333) * stun_mult
	action_duration = maxf(0.12, stun_frames / 60.0)

	var push_force: float = hitbox.knockback if "knockback" in hitbox else 0.0
	var launch_v: float = 0.0 if guarded else (hitbox.launch_velocity if "launch_velocity" in hitbox else 0.0)
	if push_force <= 0.0:
		push_force = 2.0 if guarded else 1.2 # empuje mínimo: los jab-loops se separan
	fighter.velocity.x = knockback_dir.x * push_force
	fighter.velocity.z = knockback_dir.z * push_force
	if launch_v > 0.0:
		_was_launched = true
		fighter.velocity.y = launch_v
		current_move = MoveState.AIR
		_lock_air_velocity()

# ── Ajuste dinámico de hurtbox ──────────────────────────────────────────
func _update_hurtbox_shape(input: Dictionary) -> void:
	var hurtbox := fighter.get_node_or_null("Hurtbox") as Hurtbox
	if not hurtbox or hurtbox._default_hurtbox_size == Vector3.ZERO:
		return

	var default_size := hurtbox._default_hurtbox_size
	var default_offset := hurtbox._default_hurtbox_offset

	# Lanzado en HIT o salto normal
	if current_move == MoveState.AIR:
		# La hitbox se recorta a la mitad del alto y se centra en la parte superior
		var air_size := Vector3(default_size.x * 0.7, default_size.y * 0.5, default_size.z * 0.7)
		var air_offset := Vector3(default_offset.x, default_offset.y + default_size.y * 0.25, default_offset.z)
		hurtbox.resize_hurtbox(air_size, air_offset)
		return

	# Solo en tierra y estado IDLE (no atacando ni recibiendo daño)
	if input.get("crouch", false) and current_move == MoveState.GROUND and current_action == ActionState.IDLE:
		var crouch_size := Vector3(default_size.x, default_size.y * 0.55, default_size.z)
		# Bajamos el offset para que la base del cuerpo siga tocando el suelo
		var crouch_offset := Vector3(default_offset.x, default_offset.y - default_size.y * 0.225, default_offset.z)
		hurtbox.resize_hurtbox(crouch_size, crouch_offset)
		return

	# Tirado en el suelo, hitbox baja y chica
	if is_knocked_down and current_move == MoveState.GROUND:
		var kd_size := Vector3(default_size.x * 0.9, default_size.y * 0.3, default_size.z * 0.9)
		var kd_offset := Vector3(default_offset.x, default_offset.y - default_size.y * 0.35, default_offset.z)
		hurtbox.resize_hurtbox(kd_size, kd_offset)
		return

	# Restaurar al tamaño original
	hurtbox.reset_hurtbox_size()
