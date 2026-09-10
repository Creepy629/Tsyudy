extends CharacterBody3D
class_name FighterBody

const GRAVITY := -15.0
const HIT_FLARE_SHADER: Shader = preload("res://Shaders/hit_flash.gdshader")
const HIT_SPHERE_SHADER: Shader = preload("res://Shaders/hit_sphere.gdshader")
const HIT_SPARK_TRAIL_SHADER: Shader = preload("res://Shaders/hit_spark_trail.gdshader")
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
var _hurtbox_base_size := Vector3.ZERO
var _hurtbox_base_offset := Vector3.ZERO
var is_crouching := false
var hurtbox_scale: Vector3 = Vector3.ONE # perfil por personaje (lo setea SpecialMoves)
var hurtbox_offset: Vector3 = Vector3.ZERO
var _hurtbox_col: CollisionShape3D = null
var is_guarding := false
var is_crouch_guarding := false
var _hit_sound_stream: AudioStream = null

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
	elif not crouch and is_crouching:
		is_crouching = false
		shape.size = _hurtbox_base_size
		_hurtbox_col.position = _hurtbox_base_offset

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
	_resolve_character_name()
	
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
	
	if ResourceLoader.exists("res://Audio/Pelea/Punch.mp3"):
		_hit_sound_stream = ResourceLoader.load("res://Audio/Pelea/Punch.mp3") as AudioStream
	
	set_collision_layer_value(1, false)
	set_collision_layer_value(fighter_physics_layer_bit, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(fighter_physics_layer_bit, false)
	
	state_machine = FighterStateMachine.new(self)
	
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
			var s := (_hurtbox_col.shape as BoxShape3D).size
			s = Vector3(s.x * hurtbox_scale.x, s.y * hurtbox_scale.y, s.z * hurtbox_scale.z)
			(_hurtbox_col.shape as BoxShape3D).size = s
			_hurtbox_col.position += hurtbox_offset
			_hurtbox_base_size = s
			_hurtbox_base_offset = _hurtbox_col.position
			# Sincronizar la caché de la Hurtbox, o reset_hurtbox_size() desharía el perfil al instante.
			var hurtbox_node := hb as Hurtbox
			if hurtbox_node:
				hurtbox_node._default_hurtbox_size = s
				hurtbox_node._default_hurtbox_offset = _hurtbox_col.position

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
	var from_gm: String = ""
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		from_gm = str(gm.p2_character) if fighter_slot == 2 else str(gm.p1_character)
	# Si nadie eligió personajes (corrida directa de Pelea.tscn), los defaults por slot salvan el día.
	character_name = from_gm if from_gm != "" else ("Scorpion" if fighter_slot == 2 else "Kung Lao")

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
			# El rival ataca: él es el pivote, el FightPlane lo sigue a él
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
	
	if special_moves and special_moves.has_method("check_special_moves"):
		special_moves.check_special_moves(input_state, state_machine)
	
	last_input_state = input_state
	state_machine.process_machine(delta, input_state)
	
	# Bloqueo suave: mantiene al personaje cerca del FightPlane sin robar movimiento
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
	
	_spawn_hit_flash(hitbox, guarded)
	_play_hit_sound(guarded)


func _spawn_hit_flash(hitbox: Node, guarded: bool) -> void:
	var parent_scene := get_parent()
	if parent_scene == null:
		return

	var spark_pos := global_position + Vector3(0.0, 1.0, 0.0)
	var flare_scale := 0.6
	if hitbox != null and hitbox is Node3D:
		spark_pos = (global_position + (hitbox as Node3D).global_position) * 0.5
		spark_pos.y += 0.2
		var col := (hitbox as Node3D).get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col and col.shape is BoxShape3D:
			var sz: Vector3 = (col.shape as BoxShape3D).size
			flare_scale = clampf(maxf(sz.x, maxf(sz.y, sz.z)) * 0.5, 0.4, 0.9)

	var tint: Color = Color(0.2, 0.65, 1.0, 1.0) if guarded else Color(1.0, 0.12, 0.12, 1.0)

	# ── Destello: quad orientado UNA vez hacia la cámara (sin billboard) ──
	var flare := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	flare.mesh = quad
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = HIT_FLARE_SHADER
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("seed", randf() * 100.0)
	flare.material_override = mat
	parent_scene.add_child(flare)
	flare.global_position = spark_pos
	flare.scale = Vector3.ONE * flare_scale

	# Orientación analítica inmediata hacia la cámara activa o eje visual del plano
	var cam := flare.get_viewport().get_camera_3d()
	if cam != null and spark_pos.distance_squared_to(cam.global_position) > 0.001:
		flare.look_at(cam.global_position, Vector3.UP)
	elif fight_plane != null and fight_plane.cam_dir.length_squared() > 0.001:
		flare.look_at(spark_pos + fight_plane.cam_dir, Vector3.UP)

	# ── Chispas: esferitas aditivas con estela sólida (sin billboard) ──
	var parts := GPUParticles3D.new()
	parts.amount = 7 # Cantidad reducida de chispas (entre 6 y 8)
	parts.one_shot = true
	parts.explosiveness = 0.95
	parts.lifetime = 0.52
	parts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.03
	pm.direction = Vector3(0.0, 1.0, 0.0) # Cono superior suave
	pm.spread = 65.0
	pm.initial_velocity_min = 1.0 # Salen con fuerza ligera
	pm.initial_velocity_max = 2.3
	pm.gravity = Vector3(0.0, -10.0, 0.0) # Gravedad para caer visiblemente al suelo
	pm.damping_min = 0.5
	pm.damping_max = 1.2
	parts.process_material = pm

	# Material de la estela: Shader con cabeza blanca incandescente y cola de color saturado
	var trail_mat := ShaderMaterial.new()
	trail_mat.shader = HIT_SPARK_TRAIL_SHADER
	trail_mat.set_shader_parameter("tint", tint)
	trail_mat.set_shader_parameter("brightness", 4.0)

	# ── Esfera de brillo Shader en el impacto ──
	var sphere_inst := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.16 * flare_scale
	sphere_mesh.height = 0.32 * flare_scale
	sphere_mesh.radial_segments = 16
	sphere_mesh.rings = 8
	sphere_inst.mesh = sphere_mesh
	sphere_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sphere_mat := ShaderMaterial.new()
	sphere_mat.shader = HIT_SPHERE_SHADER
	sphere_mat.set_shader_parameter("tint", tint)
	sphere_mat.set_shader_parameter("fade", 1.0)
	sphere_inst.material_override = sphere_mat
	parent_scene.add_child(sphere_inst)
	sphere_inst.global_position = spark_pos

	# Estela real (RibbonTrailMesh afilada que sigue a cada chispa de forma individual)
	var ribbon := RibbonTrailMesh.new()
	ribbon.size = 0.024 # Grosor visible
	ribbon.sections = 6
	ribbon.section_length = 0.02
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0)) # Cola (tail) afilada en 0.0
	curve.add_point(Vector2(1.0, 1.0)) # Cabeza (cabeza de chispa) gruesa en 1.0
	ribbon.curve = curve
	ribbon.material = trail_mat

	parts.trail_enabled = true
	parts.trail_lifetime = 0.14
	parts.draw_passes = 1
	parts.draw_pass_1 = ribbon

	parent_scene.add_child(parts)
	parts.global_position = spark_pos
	parts.emitting = true

	# ── Pop suave + fade del destello y la esfera de impacto ──
	var tw := flare.create_tween()
	tw.set_parallel(true)
	tw.tween_property(flare, "scale", Vector3.ONE * (flare_scale * 1.3), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(sphere_inst, "scale", Vector3.ONE * 1.35, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var fade_fn := func(v: float):
		if is_instance_valid(mat):
			mat.set_shader_parameter("fade", v)
		if is_instance_valid(sphere_mat):
			sphere_mat.set_shader_parameter("fade", v)
	tw.tween_method(fade_fn, 1.0, 0.0, 0.16)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(flare):
			flare.queue_free()
		if is_instance_valid(sphere_inst):
			sphere_inst.queue_free()
	)

	# Las partículas tienen su propio temporizador para caer al suelo antes de ser liberadas
	var part_timer := parts.get_tree().create_timer(parts.lifetime + 0.08)
	part_timer.timeout.connect(func() -> void:
		if is_instance_valid(parts):
			parts.queue_free()
	)

func _play_hit_sound(guarded: bool) -> void:
	if _hit_sound_stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = _hit_sound_stream
	player.volume_db = -4.0 if guarded else 0.0
	var parent_scene := get_parent()
	if parent_scene:
		parent_scene.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)

func apply_sidestep_motion(dir_z: float, delta: float, speed_mult: float = 1.0) -> void:
	var my_dir := dir_z
	var rival_dir := rival.sidestep_dir

	# Rival quieto → orbitar alrededor de él (cámara rota)
	if rival_dir == 0.0:
		_orbital_sidestep(my_dir, delta, rival.global_position, speed_mult)
	# Mismo sentido → traslación lateral (la cámara se desplaza sin rotar)
	elif sign(my_dir) == sign(rival_dir):
		var cam := fight_plane.cam_dir
		cam.y = 0.0
		if cam.length() > 0.001:
			cam = cam.normalized()

		var moveSpeed := sidestep_translate_speed * speed_mult

		velocity.x = cam.x * my_dir * moveSpeed
		velocity.z = cam.z * my_dir * moveSpeed
		velocity.y = 0.0

		if not rival.is_detached_from_plane:
			rival.velocity.x = cam.x * my_dir * moveSpeed
			rival.velocity.z = cam.z * my_dir * moveSpeed
	# Sentidos opuestos → orbitar alrededor del punto medio
	else:
		var mid := (global_position + rival.global_position) * 0.5
		_orbital_sidestep(my_dir, delta, Vector3(mid.x, 0.0, mid.z), speed_mult)

func _orbital_sidestep(dir_z: float, delta: float, pivot: Vector3, speed_mult: float = 1.0) -> void:
	var angle := dir_z * facing_sign * sidestep_angular_speed * speed_mult * delta
	fight_plane.global_position = Vector3(pivot.x, 0.0, pivot.z)
	fight_plane.apply_sidestep(angle)

	# Rotación analítica alrededor del pivote: evita espirales y que el clamp radial
	# se coma el movimiento como pasaba con la velocidad tangencial.
	_rotate_around_pivot(pivot, angle)
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = 0.0

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
