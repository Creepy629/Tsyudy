extends CharacterBody3D
class_name FighterBody

const GRAVITY := -15.0
@export var sidestep_angular_speed: float = 3.5 # rad/s
@export var sidestep_translate_speed: float = 3.0 # m/s
@export var pushbox_correction_speed: float = 6.0
@export var fighter_physics_layer_bit: int = 2
@export var player_input_path: NodePath
@export var rival_path: NodePath
@export var fight_plane_path: NodePath
@export var character_name: String = ""
@export var is_ai: bool = false
@export var fighter_slot: int = 1
@export var plane_reattach_speed: float = 16.0

var state_machine: FighterStateMachine
var player_input
var rival: FighterBody
var fight_plane: FightPlane
var sidestep_dir: float = 0.0
var facing_sign: int = 1
var stats: Dictionary = {
	"walk_speed": 2.5,
	"jump_velocity": 5.0,
	"dash_speed": 4.0,
	"backdash_speed": 2.5,
	"max_health": 100,
	"current_health": 100
}
var special_moves: RefCounted
var is_detached_from_plane: bool = false
var attack_direction: Vector3 = Vector3.ZERO
var _pending_plane_reattach: bool = false
var last_input_state: Dictionary = {}
var match_frozen := false
var input_state: Dictionary
var _crouched := false
var _hurtbox_base_size := Vector3.ZERO
var _hurtbox_base_offset := Vector3.ZERO
var is_crouching := false
var _hurtbox_col: CollisionShape3D = null
var is_guarding := false
var is_crouch_guarding := false

func _set_crouched_hurtbox(crouch: bool) -> void:
	if _hurtbox_col == null or not (_hurtbox_col.shape is BoxShape3D):
		return
	var shape := _hurtbox_col.shape as BoxShape3D
	if crouch and not is_crouching:
		is_crouching = true
		var s := _hurtbox_base_size
		s.y *= 0.5
		shape.size = s
		_hurtbox_col.position = _hurtbox_base_offset + Vector3(0.0, -_hurtbox_base_size.y * 0.25, 0.0)
		print("[", character_name, "] hurtbox AGACHADO (mitad de altura)")
	elif not crouch and is_crouching:
		is_crouching = false
		shape.size = _hurtbox_base_size
		_hurtbox_col.position = _hurtbox_base_offset
		print("[", character_name, "] hurtbox de pie")

func get_fight_axis() -> Vector3:
	var fight_dir := Vector3.RIGHT
	if fight_plane:
		fight_dir = fight_plane.fight_dir
		fight_dir.y = 0.0
		if fight_dir.length() > 0.001:
			fight_dir = fight_dir.normalized()
	return fight_dir

func get_attack_direction() -> Vector3:
	if is_detached_from_plane and attack_direction.length_squared() > 0.0001:
		var locked_dir := attack_direction
		locked_dir.y = 0.0
		
		if locked_dir.length_squared() > 0.0001:
			return locked_dir.normalized()
	
	var fallback_dir := get_fight_axis() * float(facing_sign)
	fallback_dir.y = 0.0
	
	if fallback_dir.length_squared() > 0.0001:
		return fallback_dir.normalized()
	
	return Vector3.RIGHT

func enter_attack_mode() -> void:
	if is_detached_from_plane:
		return
	
	is_detached_from_plane = true
	_pending_plane_reattach = false
	
	var dir := get_fight_axis() * float(facing_sign)
	
	if dir.length_squared() < 0.0001:
		dir = - global_transform.basis.z
	
	dir.y = 0.0
	
	if dir.length_squared() > 0.0001:
		attack_direction = dir.normalized()
	else:
		attack_direction = Vector3.RIGHT

func exit_attack_mode() -> void:
	if not is_detached_from_plane:
		return
	
	is_detached_from_plane = false
	attack_direction = Vector3.ZERO
	
	if is_on_floor():
		_snap_to_fight_plane()
	else:
		_pending_plane_reattach = true

func _snap_to_fight_plane() -> void:
	if fight_plane:
		global_position = fight_plane.get_projected_position(global_position)

func _ready() -> void:
	_resolve_character_name() # ← SIEMPRE primero, antes de cargar nada
	
	if not player_input_path.is_empty() and has_node(player_input_path):
		player_input = get_node(player_input_path) as PlayerInput
	else:
		for child in get_children():
			if child is PlayerInput:
				player_input = child
				break
		if not player_input:
			player_input = PlayerInput.new()
			add_child(player_input)

	if not rival_path.is_empty() and has_node(rival_path):
		rival = get_node(rival_path) as FighterBody

	if not fight_plane_path.is_empty() and has_node(fight_plane_path):
		fight_plane = get_node(fight_plane_path) as FightPlane
	
	if character_name == "":
		var gm := get_node_or_null("/root/GameManager")
		if gm:
			character_name = gm.p2_character if is_ai else gm.p1_character
	
	_load_special_moves()
	
	set_collision_layer_value(1, false)
	set_collision_layer_value(fighter_physics_layer_bit, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(fighter_physics_layer_bit, false)
	
	# Inicializamos la máquina de estados
	state_machine = FighterStateMachine.new(self)
	
	# IA: carga la IA específica del personaje si existe, de lo contrario no hace nada
	if is_ai:
		var char_n := character_name.replace(" ", "")
		var ai_path := "res://Personajes/" + character_name + "/" + char_n + "AI.gd"
		if FileAccess.file_exists(ai_path) or ResourceLoader.exists(ai_path):
			var ai = load(ai_path).new()
			ai.name = char_n + "AI"
			add_child(ai)
			player_input = ai
	
	# Referencia a la hurtbox + forma DUPLICADA (el SubResource es compartido
	# entre ambos fighters en la escena; sin duplicar, mutar uno muta a los dos)
	var hb := get_node_or_null("Hurtbox") as Area3D
	if hb:
		_hurtbox_col = hb.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if _hurtbox_col and _hurtbox_col.shape is BoxShape3D:
			_hurtbox_col.shape = (_hurtbox_col.shape as BoxShape3D).duplicate()
			_hurtbox_base_size = (_hurtbox_col.shape as BoxShape3D).size
			_hurtbox_base_offset = _hurtbox_col.position

func reset_round() -> void:
	if state_machine:
		state_machine._end_action() # deshabilita hitbox y limpia timeline
	for child in get_children():
		if child is Hitbox and child.has_method("disable_hitbox"):
			child.disable_hitbox()
		if child is Hitbox and child.has_method("clear_projectile_sprite"):
			child.clear_projectile_sprite()
	
	stats.current_health = stats.max_health
	health_changed.emit(stats.current_health, stats.max_health)
	velocity = Vector3.ZERO
	if state_machine:
		state_machine.current_action = state_machine.ActionState.IDLE
		state_machine.current_move = state_machine.MoveState.GROUND
		state_machine.current_attack_name = ""
		state_machine._attack_timeline.clear()
		state_machine._timeline_idx = -1
	is_detached_from_plane = false
	attack_direction = Vector3.ZERO
	_pending_plane_reattach = false

func _resolve_character_name() -> void:
	if character_name != "":
		return # La escena fijó nombre a mano: ese manda.
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		character_name = str(gm.p2_character) if fighter_slot == 2 else str(gm.p1_character)
	else:
		character_name = "Scorpion" if fighter_slot == 2 else "Kung Lao"

func _load_special_moves() -> void:
	if character_name == "": return
	
	var class_name_str = character_name.replace(" ", "")
	var path = "res://Personajes/" + character_name + "/" + class_name_str + "SpecialMoves.gd"
	
	if FileAccess.file_exists(path) or ResourceLoader.exists(path):
		var script = load(path)
		if script:
			special_moves = script.new()
			if special_moves.has_method("_init_special_moves"):
				special_moves._init_special_moves(self)

func _physics_process(delta: float) -> void:
	sidestep_dir = 0.0
	if fight_plane and rival:
		if is_detached_from_plane and rival.is_detached_from_plane:
			var mid := (global_position + rival.global_position) * 0.5
			fight_plane.global_position = Vector3(mid.x, 0.0, mid.z)
		
		elif is_detached_from_plane:
			# YO SOY EL PIVOTE PETER PARKER(???)
			pass
		
		elif rival.is_detached_from_plane:
			# El rival es el pivote, está atacando pues
			fight_plane.global_position = Vector3(rival.global_position.x, 0.0, rival.global_position.z)
		
		else:
			var mid := (global_position + rival.global_position) * 0.5
			fight_plane.global_position = Vector3(mid.x, 0.0, mid.z)
	
	if fight_plane and not is_detached_from_plane:
		var side := fight_plane.fight_dir.dot(global_position - fight_plane.global_position)
		facing_sign = 1 if side <= 0.0 else -1
	
	var want_crouch: bool = (input_state.get("crouch", false)
		and is_on_floor()
		and state_machine.current_action == state_machine.ActionState.IDLE
		and state_machine.current_move == state_machine.MoveState.GROUND)
	_set_crouched_hurtbox(want_crouch)

	if rival and not is_detached_from_plane:
		var target_pos := Vector3(rival.global_position.x, global_position.y, rival.global_position.z)
		if target_pos.distance_to(global_position) > 0.01:
			look_at(target_pos, Vector3.UP)
	
	var input_state: Dictionary
	if match_frozen:
		input_state = _neutral_input_state()
	else:
		player_input.poll_double_tap()
		input_state = player_input.get_movement_state()
		sidestep_dir = input_state.get("dir_z", 0.0)
	
	var on_ground_idle := is_on_floor() and state_machine != null \
		and state_machine.current_action == state_machine.ActionState.IDLE \
		and state_machine.current_move == state_machine.MoveState.GROUND
	is_guarding = on_ground_idle and bool(input_state.get("guard", false))
	is_crouch_guarding = is_guarding and bool(input_state.get("crouch", false))
	
	# Revisar si hay un ataque especial o normal entrante
	if special_moves and special_moves.has_method("check_special_moves"):
		special_moves.check_special_moves(input_state, state_machine)
	
	last_input_state = input_state

	# Procesar toda la física, gravedad, movimiento y acciones en la máquina
	# (el sidestep con Shift+doble-toque también se resuelve adentro, como
	# un MoveState más, así que ya no lo llamamos aparte acá)
	state_machine.process_machine(delta, input_state)
	
	# Bloqueo suave: Mantiene al personaje cerca del FightPlane sin robar movimiento.
	if fight_plane:
		if is_detached_from_plane:
			pass
		elif _pending_plane_reattach:
			var target: Vector3 = fight_plane.get_projected_position(global_position)
			var weight: float = clampf(plane_reattach_speed * delta, 0.0, 1.0)
			global_position = global_position.lerp(target, weight)
			
			if global_position.distance_to(target) < 0.02:
				global_position = target
				_pending_plane_reattach = false
		else:
			# Lerp suave en lugar de snap instantáneo
			var target: Vector3 = fight_plane.get_projected_position(global_position)
			var weight: float = clampf(plane_reattach_speed * delta, 0.0, 1.0)
			global_position = global_position.lerp(target, weight)

func _neutral_input_state() -> Dictionary:
	return {
		"dir_x": 0.0, "dir_z": 0.0,
		"jump": false, "jump_just_pressed": false,
		"crouch": false, "guard": false,
		"double_tap_left": false, "double_tap_right": false,
		"double_tap_up": false, "double_tap_down": false,
		"heavy_punch": false, "light_punch": false,
		"heavy_kick": false, "light_kick": false
	}

signal health_changed(current_health: int, max_health: int)
signal uppercut_landed(attacker: FighterBody)

func receive_hit(hitbox: Node) -> void:
	var is_low_hit: bool = hitbox.is_low if "is_low" in hitbox else false
	var guarded: bool = is_guarding and not (is_low_hit and not is_crouch_guarding)
	var damage_amount: int = hitbox.damage if "damage" in hitbox else 10
	if guarded:
		damage_amount = maxi(1, int(float(damage_amount) * 0.15)) # chip damage
	stats.current_health = max(0, int(stats.get("current_health", 100)) - damage_amount)
	var max_hp: int = int(stats.get("max_health", 100))
	health_changed.emit(stats.current_health, max_hp)
	Hitstop.trigger(hitbox.hitstop_duration if "hitstop_duration" in hitbox else 0.15)
	var knockback_dir := -get_fight_axis() * facing_sign
	state_machine.take_hit(hitbox, knockback_dir, guarded)
	var launch_v: float = hitbox.launch_velocity if "launch_velocity" in hitbox else 0.0
	var launch_ang: float = hitbox.launch_angle_degrees if "launch_angle_degrees" in hitbox else 90.0
	if launch_v >= 7.0 and launch_ang >= 80.0 and rival:
		uppercut_landed.emit(rival)
	
	_spawn_hit_spark(hitbox, guarded)
	_play_hit_sound(guarded)

func _spawn_hit_spark(hitbox: Node, guarded: bool) -> void:
	var spark_path := "res://Texturas/Pelea/HitSpark.png"
	if not FileAccess.file_exists(spark_path) and not ResourceLoader.exists(spark_path):
		return
	var tex = load(spark_path)
	if tex == null:
		return
	
	var spark := Sprite3D.new()
	spark.texture = tex
	spark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spark.pixel_size = 1.0 / 170.0
	
	var spark_scale := 0.4
	if hitbox != null and hitbox is Node3D:
		var col := (hitbox as Node3D).get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col and col.shape is BoxShape3D:
			var sz: Vector3 = (col.shape as BoxShape3D).size
			spark_scale = maxf(sz.x, maxf(sz.y, sz.z)) * 0.35
	spark.scale = Vector3.ONE * clampf(spark_scale, 0.2, 0.5)
	
	if guarded:
		spark.modulate = Color(0.4, 0.8, 1.0, 0.9)
	else:
		spark.modulate = Color(1.0, 0.9, 0.4, 1.0)
	
	var parent_scene := get_parent()
	if parent_scene:
		parent_scene.add_child(spark)
		var spark_pos := global_position
		if hitbox != null and hitbox is Node3D:
			spark_pos = (global_position + (hitbox as Node3D).global_position) * 0.5
			spark_pos.y += 0.3
		spark.global_position = spark_pos
		
		var timer := get_tree().create_timer(0.12)
		timer.timeout.connect(spark.queue_free)

func _play_hit_sound(guarded: bool) -> void:
	var sound_path := "res://Audio/Pelea/Punch.mp3"
	if FileAccess.file_exists(sound_path) or ResourceLoader.exists(sound_path):
		var stream = load(sound_path)
		if stream:
			var player := AudioStreamPlayer.new()
			player.stream = stream
			player.volume_db = -4.0 if guarded else 0.0
			var parent_scene := get_parent()
			if parent_scene:
				parent_scene.add_child(player)
				player.play()
				player.finished.connect(player.queue_free)

func apply_sidestep_motion(dir_z: float, delta: float, speed_mult: float = 1.0) -> void:
	var my_dir := dir_z
	var rival_dir := rival.sidestep_dir

	if rival_dir == 0.0:
		# El rival está quieto: Orbitamos alrededor de él (La cámara rota)
		_orbital_sidestep(my_dir, delta, rival.global_position, speed_mult)
	elif sign(my_dir) == sign(rival_dir):
		# Ambos se mueven en la misma dirección: Traslación lateral (La cámara no rota, se desplaza)
		var cam := fight_plane.cam_dir
		cam.y = 0.0
		if cam.length() > 0.001:
			cam = cam.normalized()

		var move_speed := sidestep_translate_speed * speed_mult

		velocity.x = cam.x * my_dir * move_speed
		velocity.z = cam.z * my_dir * move_speed
		velocity.y = 0.0

		if not rival.is_detached_from_plane:
			rival.velocity.x = cam.x * my_dir * move_speed
			rival.velocity.z = cam.z * my_dir * move_speed
	else:
		# Se mueven en direcciones opuestas: Orbitamos alrededor del punto medio
		var mid := (global_position + rival.global_position) * 0.5
		_orbital_sidestep(my_dir, delta, Vector3(mid.x, 0.0, mid.z), speed_mult)

func _orbital_sidestep(dir_z: float, delta: float, pivot: Vector3, speed_mult: float = 1.0) -> void:
	# Rotamos el FightPlane (la cámara gira)
	var angle := dir_z * facing_sign * sidestep_angular_speed * speed_mult * delta
	fight_plane.global_position = Vector3(pivot.x, 0.0, pivot.z)
	fight_plane.apply_sidestep(angle)

	# Rotación ANALÍTICA de posiciones alrededor del pivote.
	# Reemplaza la velocidad tangencial: el clamp radial ya no puede
	# comerse el movimiento ni espiralar hacia el centro.
	_rotate_around_pivot(pivot, angle)
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = 0.0

	# El rival solo rota si no está atacando/despegado de la base
	if not rival.is_detached_from_plane:
		rival._rotate_around_pivot(pivot, angle)
		rival.velocity.x = 0.0
		rival.velocity.z = 0.0

func _rotate_around_pivot(pivot: Vector3, angle: float) -> void:
	var off := global_position - pivot
	var cos_a := cos(angle)
	var sin_a := sin(angle)
	var rx := off.x * cos_a + off.z * sin_a
	var rz := -off.x * sin_a + off.z * cos_a
	global_position = Vector3(pivot.x + rx, global_position.y, pivot.z + rz)
