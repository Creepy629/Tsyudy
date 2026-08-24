extends CharacterBody3D
class_name NPCTT

# ── Nodos ──────────────────────────────────────────────────────────────────
@onready var audio: AudioStreamPlayer3D = $Steps
@onready var talk: Node = $Talk
@onready var sprite_3d: Sprite3D = $Sprite3D
@onready var sombra: Sprite3D = $Sombra
@onready var collision_node: CollisionShape3D = $CollisionShape3D
@onready var ray: RayCast3D = $RayCast3D

const dialog_scene: PackedScene = preload("res://Escenas/Nodos/DialogBobbl.tscn")

# ── Exports ────────────────────────────────────────────────────────────────
@export var gametag: String = ""
@export var walk_speed: float = 4.0
@export var run_speed: float = 8.5
@export var run_chance: float = 0.6
@export var jump_velocity: float = 5.5
@export var step_height: float = 0.30
@export var max_floor_angle_deg: float = 60.0
@export var floor_snap: float = 0.25
@export var body_safe_margin: float = 0.05
@export var stuck_jump_limit: int = 2
@export var dialog_cooldown: float = 0.0
@export var detection_radius: float = 25.0
@export var shoot_cooldown: float = 0.8
@export var hit_chance: float = 0.60
@export var death_freeze_time: float = 5.0

# ── C4 / Rol ───────────────────────────────────────────────────────────────
@export var has_c4: bool = false

# ── Gametags pool ──────────────────────────────────────────────────────────
const CS_GAMETAGS: Array[String] = [
	"s1mple", "NiKo", "ZywOo", "KennyS", "device", "shox", "pashaBiceps",
	"coldzera", "FalleN", "Stewie2K", "tarik", "f0rest", "phoon",
	"screaM", "m0NESY", "donk", "ropz", "twistzz", "b1t", "karrigan", "JW"
]

var gametag_label: Label3D = null

# ── Granadas (1 por spawn con cooldown) ────────────────────────────────────
var has_he_grenade: bool = true
var has_flashbang: bool = true
var grenade_cooldown: float = 0.0
var is_blinded: bool = false
var blind_timer: float = 0.0
var combat_timer: float = 0.0
var los_lost_timer: float = 0.0

# ── Constantes de equipo ───────────────────────────────────────────────────
const TEAM: String = "TT"
const ENEMY_TEAM: String = "CT"
const SHOT_PATH := "res://Audio/Ciudad/Counter/ak47.wav"
var shot_player: AudioStreamPlayer3D = null

# ── Skin fija TT ───────────────────────────────────────────────────────────
const SKIN_TEX = preload("res://Texturas/Personajes/TTsheet.png")
const SKIN_HEIGHT: float = 2.0
const SKIN_SCALE: Vector3 = Vector3(4.836, 4.836, 4.836)
const SKIN_POS_Y: float = -0.131

# ── Estados ────────────────────────────────────────────────────────────────
enum State {WALKING, WAITING, PLANTING, COMBAT, DEFENDING, DEAD_FROZEN}
var current_state: State = State.WALKING

var nav_map_ready := false
var SPEED: float = 4.0
var agent: NavigationAgent3D
var spawn_point := Vector3.ZERO
var destination_timer := 0.0
var destination_interval := 35.0
var wait_timer := 0.0
var death_timer := 0.0
var shoot_timer := 0.0
var spawned := false
var _half_h: float = 1.0
const ARRIVE_DIST := 1.6
const PATH_CALC_GRACE := 0.3
const WAIT_TIME := 0.4

# ── Pathfinding & Bhop ─────────────────────────────────────────────────────
var _path_idx: int = 0
var _bhop_enabled: bool = false
var _was_on_floor: bool = true

# ── Anti-stuck ─────────────────────────────────────────────────────────────
var _stuck_jumps: int = 0
var last_position := Vector3.ZERO
var position_check_timer := 0.0
const POSITION_CHECK_INTERVAL := 0.5
const STUCK_DIST_THRESHOLD := 0.08

# ── Diálogo ────────────────────────────────────────────────────────────────
var speech_streams: Array[AudioStream] = []
var speech_paths: Array[String] = [
	"res://Audio/Ciudad/NPCs/Scream1.wav",
	"res://Audio/Ciudad/NPCs/Scream2.wav",
	"res://Audio/Ciudad/NPCs/Scream3.wav",
	"res://Audio/Ciudad/NPCs/live1.wav",
	"res://Audio/Ciudad/NPCs/live2.wav",
	"res://Audio/Ciudad/NPCs/live3.wav"
]
var _dialog_timer: float = 0.0

# ── Referencias ────────────────────────────────────────────────────
var _target_enemy: Node3D = null
var _target_site: BombSite = null

func _ready() -> void:
	add_to_group(TEAM)
	floor_max_angle = deg_to_rad(max_floor_angle_deg)
	floor_snap_length = floor_snap
	safe_margin = body_safe_margin
	SPEED = walk_speed
	_apply_skin()
	_setup_gametag()
	
	var cap := collision_node.shape as CapsuleShape3D
	if cap != null:
		_half_h = cap.height * 0.5
		
	for path in speech_paths:
		var stream: Resource = load(path)
		if stream is AudioStream:
			speech_streams.append(stream)
			
	var sun: Node = get_tree().root.find_child("LaLuh", true, false)
	if sun != null and sombra != null and "target_node" in sombra:
		sombra.set("target_node", sun)
		
	agent = $NavigationAgent3D
	agent.target_desired_distance = 0.8
	agent.path_desired_distance = 0.8
	agent.avoidance_enabled = false
	agent.path_height_offset = 0.0
	
	if ray != null:
		ray.enabled = true
		ray.hit_from_inside = false
	
	shot_player = AudioStreamPlayer3D.new()
	shot_player.volume_db = -6.0
	if FileAccess.file_exists(SHOT_PATH) or ResourceLoader.exists(SHOT_PATH):
		shot_player.stream = load(SHOT_PATH)
	else:
		push_warning("NPCTT: no existe %s" % SHOT_PATH)
	add_child(shot_player)
	call_deferred("setup_navigation")

func _setup_gametag() -> void:
	if gametag == "":
		gametag = CS_GAMETAGS[randi() % CS_GAMETAGS.size()]
	
	gametag_label = Label3D.new()
	gametag_label.text = gametag
	gametag_label.pixel_size = 0.006
	gametag_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gametag_label.position = Vector3(0, 1.45, 0)
	gametag_label.modulate = Color(0.96, 0.69, 0.25) # Naranja/amarillo TT
	gametag_label.outline_render_priority = 1
	gametag_label.outline_size = 3
	gametag_label.outline_modulate = Color(0.1, 0.1, 0.1, 0.8)
	add_child(gametag_label)

func setup_navigation() -> void:
	await get_tree().create_timer(0.5).timeout
	var nav_region: NavigationRegion3D = get_tree().current_scene.find_child("NavigationRegion3D", true, false)
	for _i in range(10):
		if nav_region != null and nav_region.get_navigation_map().is_valid():
			break
		await get_tree().create_timer(0.5).timeout
		nav_region = get_tree().current_scene.find_child("NavigationRegion3D", true, false)
		
	if nav_region == null or not nav_region.get_navigation_map().is_valid():
		push_warning("NPCTT %s: sin NavigationRegion3D válida." % name)
		return
		
	nav_map_ready = true
	var nav_map: RID = agent.get_navigation_map()
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, global_position)
	var off_xz: float = Vector2(closest.x - global_position.x, closest.z - global_position.z).length()
	if off_xz > 0.5:
		global_position = Vector3(closest.x, global_position.y, closest.z)
		
	spawn_point = global_position
	last_position = global_position
	
	_check_initial_c4_assignment()
	
	await get_tree().process_frame
	choose_next_objective()

func _check_initial_c4_assignment() -> void:
	if BombSite.active_planted_site != null or BombSite.dropped_c4_position != Vector3.INF:
		return
	var tts: Array = get_tree().get_nodes_in_group(TEAM)
	var someone_has_c4: bool = false
	for t in tts:
		if "has_c4" in t and t.has_c4:
			someone_has_c4 = true
			break
	if not someone_has_c4:
		has_c4 = true

func set_c4_carrier(state: bool) -> void:
	has_c4 = state

# ── Objetivos & Destinos ───────────────────────────────────────────────────
func choose_next_objective() -> void:
	if not nav_map_ready: return
	
	# Si la C4 ya está plantada, todos a defender el site
	if BombSite.active_planted_site != null and is_instance_valid(BombSite.active_planted_site):
		var defend_offset := Vector3(randf_range(-6.0, 6.0), 0, randf_range(-6.0, 6.0))
		agent.target_position = BombSite.active_planted_site.global_position + defend_offset
		current_state = State.DEFENDING
		destination_timer = 0.0
		destination_interval = randf_range(20.0, 35.0)
		_stuck_jumps = 0
		_path_idx = 0
		SPEED = run_speed
		_bhop_enabled = randf() < 0.5
		return
	
	# Si la C4 quedó tirada, ir por ella
	if not has_c4 and BombSite.dropped_c4_position != Vector3.INF:
		agent.target_position = BombSite.dropped_c4_position
		current_state = State.WALKING
		destination_timer = 0.0
		destination_interval = 30.0
		_stuck_jumps = 0
		_path_idx = 0
		SPEED = run_speed
		_bhop_enabled = randf() < 0.5
		return
	
	# Si traigo la C4, elegir site y plantar
	if has_c4:
		var sites: Array = get_tree().get_nodes_in_group("BombSite")
		if not sites.is_empty():
			if _target_site == null or not is_instance_valid(_target_site):
				_target_site = sites[randi() % sites.size()] as BombSite
			
			if _target_site != null and _target_site.current_state == BombSite.BombState.UNPLANTED:
				agent.target_position = _target_site.global_position
				current_state = State.WALKING
				destination_timer = 0.0
				destination_interval = 40.0
				_stuck_jumps = 0
				_path_idx = 0
				SPEED = run_speed
				_bhop_enabled = randf() < 0.5
				return

	# Si no la traigo, escoltar al portador
	var carrier: NPCTT = _get_c4_carrier()
	if carrier != null and carrier != self and is_instance_valid(carrier):
		if carrier._target_site != null:
			_target_site = carrier._target_site
			var escort_offset := Vector3(randf_range(-4.0, 4.0), 0, randf_range(-4.0, 4.0))
			agent.target_position = _target_site.global_position + escort_offset
		else:
			agent.target_position = carrier.global_position
		current_state = State.WALKING
		destination_timer = 0.0
		destination_interval = randf_range(20.0, 35.0)
		_stuck_jumps = 0
		_path_idx = 0
		SPEED = run_speed if randf() < 0.75 else walk_speed
		_bhop_enabled = SPEED > 6.0 and randf() < 0.5
		return

	# Si no hay portador, a patrullar
	set_random_destination()

func _get_c4_carrier() -> NPCTT:
	var tts: Array = get_tree().get_nodes_in_group(TEAM)
	for t in tts:
		if t is NPCTT and t.has_c4 and t.current_state != State.DEAD_FROZEN:
			return t
	return null

func set_random_destination() -> void:
	if not nav_map_ready: return
	var nav_map: RID = agent.get_navigation_map()
	if not nav_map.is_valid(): return
	
	var radius := 60.0
	for _attempt in range(20):
		var angle: float = randf() * TAU
		var dist: float = randf_range(10.0, radius)
		var random_pos := global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var target: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, random_pos)
		var hdist := Vector2(target.x - global_position.x, target.z - global_position.z).length()
		var vdist: float = absf(target.y - global_position.y)
		if hdist > 5.0 and vdist < 1.5:
			agent.target_position = target
			current_state = State.WALKING
			spawned = true
			destination_timer = 0.0
			destination_interval = randf_range(15.0, 30.0)
			_stuck_jumps = 0
			_path_idx = 0
			var will_run: bool = randf() < run_chance
			SPEED = run_speed if will_run else walk_speed
			_bhop_enabled = will_run and (randf() < 0.5)
			return

func start_waiting() -> void:
	choose_next_objective()

func _do_jump() -> void:
	velocity.y = jump_velocity

# ── Sistema de Disparo, Muerte e Intangibilidad ────────────────────────────
func receive_shot(shooter: Node3D) -> void:
	if current_state == State.DEAD_FROZEN:
		return
		
	if has_c4:
		has_c4 = false
		BombSite.drop_c4(global_position, get_tree())
		
	current_state = State.DEAD_FROZEN
	death_timer = 0.0
	velocity = Vector3.ZERO
	
	BombSite.log_kill(shooter, self, "🔫")
	
	if collision_node != null:
		collision_node.set_deferred("disabled", true)
	if gametag_label != null:
		gametag_label.visible = false
	
	if audio.playing:
		audio.stop()
		
	if sprite_3d != null:
		sprite_3d.modulate = Color(1.0, 0.3, 0.3, 0.7)
		sprite_3d.rotation_degrees.z = 90.0

func apply_flashbang(duration: float = 5.0) -> void:
	if current_state == State.DEAD_FROZEN: return
	is_blinded = true
	blind_timer = duration
	if sprite_3d != null:
		sprite_3d.modulate = Color(2.5, 2.5, 2.5, 1.0)

func respawn_to_base() -> void:
	if collision_node != null:
		collision_node.set_deferred("disabled", false)
	if gametag_label != null:
		gametag_label.visible = true
	has_he_grenade = true
	has_flashbang = true
	grenade_cooldown = 0.0
	is_blinded = false
	blind_timer = 0.0
	combat_timer = 0.0
	
	if sprite_3d != null:
		sprite_3d.modulate = Color(1, 1, 1, 1)
		sprite_3d.rotation_degrees.z = 0.0
	global_position = spawn_point
	last_position = spawn_point
	_stuck_jumps = 0
	_path_idx = 0
	_target_enemy = null
	_target_site = null
	current_state = State.WALKING
	choose_next_objective()

func _respawn() -> void:
	respawn_to_base()

# ── Física principal ───────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not nav_map_ready:
		return
	if dialog_cooldown > 0.0:
		_dialog_timer = maxf(0.0, _dialog_timer - delta)
	if shoot_timer > 0.0:
		shoot_timer = maxf(0.0, shoot_timer - delta)
	if grenade_cooldown > 0.0:
		grenade_cooldown = maxf(0.0, grenade_cooldown - delta)

	if is_blinded:
		blind_timer -= delta
		if blind_timer <= 0.0:
			is_blinded = false
			if sprite_3d != null and current_state != State.DEAD_FROZEN:
				sprite_3d.modulate = Color(1, 1, 1, 1)

	if current_state == State.DEAD_FROZEN:
		_process_dead(delta)
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0

	match current_state:
		State.WAITING:
			_process_waiting(delta)
			return
		State.PLANTING:
			_process_planting(delta)
			return
		State.COMBAT:
			_process_combat(delta)
			return
		State.WALKING, State.DEFENDING:
			_process_walking(delta)

	var on_floor_now: bool = is_on_floor()
	if _bhop_enabled and not _was_on_floor and on_floor_now:
		if randf() < 0.5:
			_do_jump()
	_was_on_floor = on_floor_now

	_update_audio()
	move_and_slide()

func _process_dead(delta: float) -> void:
	death_timer += delta
	velocity = Vector3.ZERO
	if not BombSite.round_ended and death_timer >= death_freeze_time:
		_respawn()

func _process_waiting(delta: float) -> void:
	wait_timer += delta
	velocity.x = 0.0
	velocity.z = 0.0
	if audio.playing:
		audio.stop()
		
	if not is_blinded and _scan_for_enemies():
		return
		
	if wait_timer >= WAIT_TIME:
		choose_next_objective()
	move_and_slide()

func _process_planting(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if audio.playing:
		audio.stop()
		
	if _target_site == null or _target_site.current_state != BombSite.BombState.PLANTING:
		has_c4 = false
		choose_next_objective()
		return
		
	if not is_blinded and _scan_for_enemies():
		return
		
	move_and_slide()

func _process_combat(delta: float) -> void:
	combat_timer += delta
	
	if _target_enemy == null or not is_instance_valid(_target_enemy) or ("current_state" in _target_enemy and _target_enemy.current_state == State.DEAD_FROZEN) or is_blinded:
		_target_enemy = null
		combat_timer = 0.0
		los_lost_timer = 0.0
		choose_next_objective()
		return
		
	# Verificar si perdimos línea de visión física (obstáculos/paredes)
	if ray != null:
		ray.target_position = to_local(_target_enemy.global_position + Vector3(0, 1.0, 0))
		ray.force_raycast_update()
		if ray.is_colliding() and ray.get_collider() != _target_enemy:
			los_lost_timer += delta
			if los_lost_timer >= 2.0: # 2 segundos sin verlo = abortar e ir a buscarlo/patrullar
				_target_enemy = null
				combat_timer = 0.0
				los_lost_timer = 0.0
				choose_next_objective()
				return
		else:
			los_lost_timer = 0.0

	var dir_to: Vector3 = (_target_enemy.global_position - global_position)
	dir_to.y = 0.0
	var dist_to_enemy: float = dir_to.length()
	
	if dir_to.length_squared() > 0.01:
		var target_rot: float = atan2(-dir_to.x, -dir_to.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 12.0)
		
	# Movimiento táctico breve
	var move_dir := Vector3.ZERO
	var right_vec := Vector3(-dir_to.z, 0, dir_to.x).normalized()
	
	if combat_timer < 1.8:
		var strafe_side: float = 1.0 if int(Time.get_ticks_msec() / 600) % 2 == 0 else -1.0
		move_dir += right_vec * strafe_side * 0.45
	
	# Si traigo la C4 y ya estoy cerca del site, plantar antes que pelear
	if has_c4 and _target_site != null and global_position.distance_to(_target_site.global_position) < 15.0:
		var site_dir := (_target_site.global_position - global_position)
		site_dir.y = 0.0
		move_dir += site_dir.normalized() * 0.8
	else:
		if dist_to_enemy > 10.0:
			move_dir += dir_to.normalized() * 0.6
		elif dist_to_enemy < 4.0:
			move_dir -= dir_to.normalized() * 0.5
		
	var sep := _get_separation_vector()
	if sep.length_squared() > 0.001:
		move_dir += Vector3(sep.x, 0, sep.y) * 0.6
		
	if move_dir.length_squared() > 0.01:
		move_dir = move_dir.normalized()
		velocity.x = move_dir.x * (SPEED * 0.8)
		velocity.z = move_dir.z * (SPEED * 0.8)
	else:
		velocity.x = lerp(velocity.x, 0.0, delta * 6.0)
		velocity.z = lerp(velocity.z, 0.0, delta * 6.0)
		
	if grenade_cooldown <= 0.0 and dist_to_enemy > 6.0:
		if has_flashbang and randf() < 0.5:
			has_flashbang = false
			grenade_cooldown = randf_range(6.0, 10.0)
			Grenade.throw_grenade(global_position + Vector3(0, 1.2, 0), dir_to, Grenade.GrenadeType.FLASHBANG, TEAM, get_tree())
		elif has_he_grenade and randf() < 0.5:
			has_he_grenade = false
			grenade_cooldown = randf_range(6.0, 10.0)
			Grenade.throw_grenade(global_position + Vector3(0, 1.2, 0), dir_to, Grenade.GrenadeType.HE, TEAM, get_tree())
		
	if shoot_timer <= 0.0:
		_shoot_at_enemy(_target_enemy)
		shoot_timer = shoot_cooldown
		
	move_and_slide()

func _process_walking(delta: float) -> void:
	combat_timer = 0.0
	
	# Escanear enemigos (si no está cegado)
	if not is_blinded and _scan_for_enemies():
		return

	# Recoger C4 si está en el suelo y paso cerca
	if not has_c4 and BombSite.dropped_c4_position != Vector3.INF:
		var dist_to_c4 := global_position.distance_to(BombSite.dropped_c4_position)
		if dist_to_c4 <= 1.8:
			has_c4 = true
			BombSite.remove_dropped_c4()
			choose_next_objective()
			return

	# Si llevo la C4, comprobar si llegué al site para plantar
	if has_c4 and BombSite.active_planted_site == null:
		var sites: Array = get_tree().get_nodes_in_group("BombSite")
		for s in sites:
			if s is BombSite and (s as BombSite).is_npc_in_site(self):
				if (s as BombSite).start_planting(self):
					_target_site = s as BombSite
					current_state = State.PLANTING
					has_c4 = false
					return

	if check_player_collision():
		choose_next_objective()
		return

	destination_timer += delta
	var target_xz := Vector2(agent.target_position.x, agent.target_position.z)
	var pos_xz := Vector2(global_position.x, global_position.z)
	var path := agent.get_current_navigation_path()
	
	var reached: bool = false
	if agent.is_navigation_finished() or pos_xz.distance_to(target_xz) < ARRIVE_DIST:
		reached = true
	elif not path.is_empty() and _path_idx >= path.size() - 1:
		var last_wp_xz := Vector2(path[path.size() - 1].x, path[path.size() - 1].z)
		if pos_xz.distance_to(last_wp_xz) < 0.8:
			reached = true

	if reached or destination_timer >= destination_interval:
		choose_next_objective()
	else:
		_avance(delta)

	if current_state == State.WALKING and spawned and check_if_stuck(delta):
		if is_on_floor() and _stuck_jumps < stuck_jump_limit:
			_stuck_jumps += 1
			_do_jump()
		else:
			_stuck_jumps = 0
			choose_next_objective()

	_update_audio()
	move_and_slide()

# ── Escaneo de enemigos con RayCast ────────────────────────────────────────
func _scan_for_enemies() -> bool:
	if ray == null or is_blinded: return false
	var enemies: Array = get_tree().get_nodes_in_group(ENEMY_TEAM)
	for enemy in enemies:
		if not enemy is Node3D: continue
		if "current_state" in enemy and enemy.current_state == State.DEAD_FROZEN:
			continue
			
		var to_enemy: Vector3 = (enemy as Node3D).global_position - global_position
		if to_enemy.length() > detection_radius:
			continue
			
		ray.target_position = to_local((enemy as Node3D).global_position + Vector3(0, 1.0, 0))
		ray.force_raycast_update()
		
		if not ray.is_colliding() or ray.get_collider() == enemy:
			_target_enemy = enemy as Node3D
			current_state = State.COMBAT
			combat_timer = 0.0
			shoot_timer = 0.2
			return true
	return false

func _shoot_at_enemy(enemy: Node3D) -> void:
	_play_shot()
	if randf() <= hit_chance:
		if enemy.has_method("receive_shot"):
			enemy.call("receive_shot", self)

func _play_shot() -> void:
	if shot_player != null and shot_player.stream != null:
		shot_player.play()

# ── Movimiento ─────────────────────────────────────────────────────────────
# Querido forker o modder, te advierto que al modificar esta zona vas a querer
# arrancarte cualquier miembro que tengas cercano.
func _avance(delta: float) -> void:
	var path: PackedVector3Array = agent.get_current_navigation_path()
	if path.is_empty():
		return

	_path_idx = clampi(_path_idx, 0, path.size() - 1)
	while _path_idx < path.size() - 1:
		var d_xz: float = Vector2(path[_path_idx].x - global_position.x,
								 path[_path_idx].z - global_position.z).length()
		if d_xz < 0.6:
			_path_idx += 1
		else:
			break

	var look_idx: int = path.size() - 1
	for i in range(_path_idx, path.size()):
		var d: float = Vector2(path[i].x - global_position.x, path[i].z - global_position.z).length()
		if d > 0.75:
			look_idx = i
			break

	var feet_y: float = global_position.y - _half_h
	var npc_full_h: float = _half_h * 2.0
	while look_idx < path.size() - 1:
		var gh: float = Vector2(path[look_idx].x - global_position.x, path[look_idx].z - global_position.z).length()
		var gv: float = absf(path[look_idx].y - feet_y)
		if gh < 0.15 and gv > npc_full_h * 1.5:
			look_idx += 1
		else:
			break

	var goal: Vector3 = path[look_idx]
	var current_2d := Vector2(global_position.x, global_position.z)
	var goal_2d := Vector2(goal.x, goal.z)
	var distance: float = current_2d.distance_to(goal_2d)
	var height_diff: float = goal.y - feet_y

	if distance > 0.2:
		var direction := (goal_2d - current_2d).normalized()
		
		var sep := _get_separation_vector()
		if sep.length_squared() > 0.001:
			direction = (direction + sep * 0.8).normalized()
			
		velocity.x = direction.x * SPEED
		velocity.z = direction.y * SPEED
		
		if is_on_floor() and height_diff > step_height and height_diff <= npc_full_h:
			_do_jump()
		elif is_on_floor() and height_diff > step_height * 0.5 and height_diff <= step_height:
			velocity.y = minf(SPEED * (height_diff / maxf(distance, 0.001)), jump_velocity * 0.4)
				
		if direction.length_squared() > 0.01:
			var target_rotation: float = atan2(-direction.x, direction.y)
			rotation.y = lerp_angle(rotation.y, target_rotation, delta * 8.0)
	else:
		velocity.x = lerp(velocity.x, 0.0, delta * 8.0)
		velocity.z = lerp(velocity.z, 0.0, delta * 8.0)

# ── Separación entre NPCs (Evita atascos y que se encimen) ────────────────
func _get_separation_vector() -> Vector2:
	var separation := Vector2.ZERO
	var my_xz := Vector2(global_position.x, global_position.z)
	var allies: Array = get_tree().get_nodes_in_group(TEAM)
	for ally in allies:
		if ally == self or not ally is Node3D or ("current_state" in ally and ally.current_state == State.DEAD_FROZEN):
			continue
		var ally_xz := Vector2((ally as Node3D).global_position.x, (ally as Node3D).global_position.z)
		var dist := my_xz.distance_to(ally_xz)
		if dist > 0.001 and dist < 1.1:
			var strength: float = (1.1 - dist) / 1.1
			separation += (my_xz - ally_xz).normalized() * strength
	return separation

func check_if_stuck(delta: float) -> bool:
	if not spawned:
		return false
	position_check_timer += delta
	if position_check_timer >= POSITION_CHECK_INTERVAL:
		var moved: float = global_position.distance_to(last_position)
		var is_stuck: bool = moved < STUCK_DIST_THRESHOLD
		if not is_stuck:
			_stuck_jumps = 0
		last_position = global_position
		position_check_timer = 0.0
		return is_stuck
	return false

func check_player_collision() -> bool:
	for i in get_slide_collision_count():
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider != null and (collider.name == "Jugador" or collider.name == "NPC"):
			if dialog_cooldown <= 0.0:
				_spawn_dialog()
			elif _dialog_timer <= 0.0:
				_dialog_timer = dialog_cooldown
				_spawn_dialog()
			return true
	return false

func _spawn_dialog() -> void:
	if speech_streams.is_empty():
		return
	var dialog: Node = dialog_scene.instantiate()
	var random_index: int = randi() % speech_streams.size()
	add_child(dialog)
	dialog.global_position = global_position + Vector3(0, 1.5, 0)
	talk.set("stream", speech_streams[random_index])
	talk.call("play")

func _update_audio() -> void:
	var is_moving: bool = Vector2(velocity.x, velocity.z).length() > 0.5
	if is_moving and is_on_floor():
		if not audio.playing:
			audio.play()
	else:
		if audio.playing:
			audio.stop()
	audio.pitch_scale = 1.4 if SPEED > 6.0 else 1.05

func _apply_skin() -> void:
	if sprite_3d != null:
		sprite_3d.texture = SKIN_TEX
		sprite_3d.scale = SKIN_SCALE
		sprite_3d.position.y = SKIN_POS_Y
	if sombra != null:
		sombra.texture = SKIN_TEX
	if collision_node != null:
		var shape: Shape3D = collision_node.shape.duplicate()
		if shape is CapsuleShape3D:
			(shape as CapsuleShape3D).height = SKIN_HEIGHT
		collision_node.shape = shape
		_half_h = SKIN_HEIGHT * 0.5

func aplicar_skin_aleatoria() -> void:
	_apply_skin()
