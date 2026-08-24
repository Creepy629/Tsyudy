extends CharacterBody3D

@onready var audio: AudioStreamPlayer3D = $Steps
@onready var talk: Node = $Talk
@onready var sprite_3d: Sprite3D = $Sprite3D
@onready var sombra: Sprite3D = $Sombra
@onready var collision_node: CollisionShape3D = $CollisionShape3D

const dialog_scene: PackedScene = preload("res://Escenas/Nodos/DialogBobbl.tscn")

@export_category("Stats")
@export var walk_speed: float = 4.0
@export var run_speed: float = 9.0
@export var run_chance: float = 0.5
@export var jump_velocity: float = 5.0
@export var step_height: float = 0.30
@export var max_floor_angle_deg: float = 60.0
@export var floor_snap: float = 0.25
@export var body_safe_margin: float = 0.05
@export var stuck_jump_limit: int = 2
@export var dialog_cooldown: float = 0.0
@export var speech_paths: Array[String] = [
	"res://Audio/Ciudad/NPCs/Scream1.wav"
]

var nav_map_ready := false
var SPEED: float = 4.0
var agent: NavigationAgent3D
var destination_timer := 0.0
var destination_interval := 35.0 # se randomiza en set_random_destination
const ARRIVE_DIST := 1.0
const PATH_CALC_GRACE := 0.5
enum State {WALKING, WAITING}
var current_state = State.WALKING
var wait_timer := 0.0
const WAIT_TIME := 2.0
var spawned = false
var _half_h: float = 1.0
var _print_timer := 0.0
var _bhop_enabled: bool = false # true cuando este NPC corre con bhop
var _was_on_floor: bool = true # para detectar el frame exacto de aterrizaje
var speech_streams: Array[AudioStream] = []
var _stuck_jumps: int = 0
var _dialog_timer: float = 0.0
var last_position := Vector3.ZERO
var position_check_timer := 0.0
const POSITION_CHECK_INTERVAL := 0.5
const STUCK_DIST_THRESHOLD := 0.08 # metros mínimos a moverse por intervalo
var _path_idx: int = 0 # Índice progresivo en el path; NUNCA retrocede

func _ready() -> void:
	floor_max_angle = deg_to_rad(max_floor_angle_deg)
	floor_snap_length = floor_snap
	safe_margin = body_safe_margin
	SPEED = walk_speed
	aplicar_skin_aleatoria()
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
	agent = $NavigationAgent3D # Chinga tu madre
	agent.target_desired_distance = 0.5
	agent.path_desired_distance = 0.5
	agent.avoidance_enabled = false
	agent.path_height_offset = 0.0
	call_deferred("setup_navigation")

func setup_navigation() -> void:
	await get_tree().create_timer(0.5).timeout
	var nav_region: NavigationRegion3D = get_tree().current_scene.find_child("NavigationRegion3D", true, false)
	for _i in range(10):
		if nav_region != null and nav_region.get_navigation_map().is_valid():
			break
		await get_tree().create_timer(0.5).timeout
		nav_region = get_tree().current_scene.find_child("NavigationRegion3D", true, false)
	if nav_region == null or not nav_region.get_navigation_map().is_valid():
		push_warning("NPC %s: sin NavigationRegion3D válida; me quedo quieto." % name)
		return
	nav_map_ready = true
	var nav_map: RID = agent.get_navigation_map()
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, global_position)
	var off_xz: float = Vector2(closest.x - global_position.x, closest.z - global_position.z).length()
	if off_xz > 0.5:
		global_position = Vector3(closest.x, global_position.y, closest.z)
	last_position = global_position
	await get_tree().process_frame
	set_random_destination()

func set_random_destination() -> void:
	if not nav_map_ready:
		return
	var nav_map: RID = agent.get_navigation_map()
	if not nav_map.is_valid():
		return
	var radius := 80.0
	for _attempt in range(20):
		var angle: float = randf() * TAU
		var dist: float = randf_range(10.0, radius)
		var random_pos := global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var target: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, random_pos)
		var horizontal_dist := Vector2(target.x - global_position.x, target.z - global_position.z).length()
		var vertical_dist: float = absf(target.y - global_position.y)
		if horizontal_dist > 5.0 and vertical_dist < 1.5:
			agent.target_position = target
			current_state = State.WALKING
			spawned = true
			destination_timer = 0.0
			destination_interval = randf_range(20.0, 50.0) # ruta larga = más tiempo
			_stuck_jumps = 0
			_path_idx = 0 # Reiniciar índice de path al asignar nuevo destino
			var will_run: bool = randf() < run_chance
			SPEED = run_speed if will_run else walk_speed
			_bhop_enabled = will_run and randf() < 0.5 # 50 % de los runners hacen bhop
			return

func start_waiting() -> void:
	current_state = State.WAITING
	wait_timer = 0.0

func _do_jump() -> void:
	velocity.y = jump_velocity

func _physics_process(delta: float) -> void:
	if not nav_map_ready:
		return
	if dialog_cooldown > 0.0:
		_dialog_timer = maxf(0.0, _dialog_timer - delta)

	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0

	if current_state == State.WAITING:
		wait_timer += delta
		velocity.x = 0.0
		velocity.z = 0.0
		if audio.playing:
			audio.stop()
		if wait_timer >= WAIT_TIME:
			set_random_destination() # destination_interval se fija dentro
		move_and_slide()
		return

	# WALKING
	if check_player_collision():
		start_waiting()
	else:
		destination_timer += delta
		var target_xz := Vector2(agent.target_position.x, agent.target_position.z)
		var pos_xz := Vector2(global_position.x, global_position.z)
		var path := agent.get_current_navigation_path()
		
		var reached: bool = false
		if agent.is_navigation_finished() or pos_xz.distance_to(target_xz) < 1.6:
			reached = true
		elif not path.is_empty() and _path_idx >= path.size() - 1:
			var last_wp_xz := Vector2(path[path.size() - 1].x, path[path.size() - 1].z)
			if pos_xz.distance_to(last_wp_xz) < 0.8:
				reached = true
				
		if reached or destination_timer >= destination_interval:
			set_random_destination()
		else:
			_avance(delta)

	if current_state == State.WALKING and spawned and check_if_stuck(delta):
		if is_on_floor() and _stuck_jumps < stuck_jump_limit:
			_stuck_jumps += 1
			_do_jump()
		else:
			# Sin timer: recalcular ruta al instante
			_stuck_jumps = 0
			set_random_destination()

	var is_moving: bool = Vector2(velocity.x, velocity.z).length() > 0.5
	if is_moving and is_on_floor():
		if not audio.playing:
			audio.play()
	else:
		if audio.playing:
			audio.stop()
	audio.pitch_scale = 1.5 if SPEED > 6.0 else 1.05
	
	# Debug throttled (bórralo cuando esté verde)
	_print_timer += delta
	if _print_timer >= 2.0:
		_print_timer = 0.0
	
	var is_on_floor_now: bool = is_on_floor()
	# Bhop: saltar exactamente en el frame en que el NPC toca el suelo (aterrizaje).
	# Solo si estaba en el aire el frame anterior y ahora aterrizó.
	if _bhop_enabled and not _was_on_floor and is_on_floor_now:
		if randf() < 0.5:
			_do_jump()
	_was_on_floor = is_on_floor_now

	move_and_slide()

func _avance(delta: float) -> void:
	var path: PackedVector3Array = agent.get_current_navigation_path()
	if path.is_empty():
		return

	# 1) Avanzar _path_idx solo hacia adelante: saltamos waypoints ya superados.
	#    Un waypoint se considera "superado" cuando estamos a menos de 0.6 m en XZ.
	_path_idx = clampi(_path_idx, 0, path.size() - 1)
	while _path_idx < path.size() - 1:
		var d_xz: float = Vector2(path[_path_idx].x - global_position.x,
								 path[_path_idx].z - global_position.z).length()
		if d_xz < 0.6:
			_path_idx += 1
		else:
			break

	# 2) Lookahead: desde _path_idx, buscar el primer punto al menos 0.75 m en XZ.
	#    Así el NPC siempre mira ADELANTE, nunca atrás.
	var look_idx: int = path.size() - 1
	for i in range(_path_idx, path.size()):
		var d: float = Vector2(path[i].x - global_position.x, path[i].z - global_position.z).length()
		if d > 0.75:
			look_idx = i
			break

	# 3) Saltar corners-vent: solo saltar waypoints que están literalmente encima
	#    del NPC (gh < 0.15) con una diferencia de Y absurda (> altura completa).
	#    Umbral reducido para NO descartar escalones ni plataformas legítimas.
	var feet_y: float = global_position.y - _half_h
	var npc_full_h: float = _half_h * 2.0
	while look_idx < path.size() - 1:
		var gh: float = Vector2(path[look_idx].x - global_position.x, path[look_idx].z - global_position.z).length()
		var gv: float = absf(path[look_idx].y - feet_y)
		if gh < 0.15 and gv > npc_full_h * 1.5: # solo vent-corners imposibles
			look_idx += 1
		else:
			break

	var goal: Vector3 = path[look_idx]
	var current_2d := Vector2(global_position.x, global_position.z)
	var goal_2d := Vector2(goal.x, goal.z)
	var distance: float = current_2d.distance_to(goal_2d)
	var height_diff: float = goal.y - feet_y # positivo = subir, negativo = bajar

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
	var npcs: Array = get_tree().get_nodes_in_group("TT") + get_tree().get_nodes_in_group("CT")
	for npc in npcs:
		if npc == self or not npc is Node3D or ("current_state" in npc and str(npc.current_state) == "DEAD_FROZEN"):
			continue
		var other_xz := Vector2((npc as Node3D).global_position.x, (npc as Node3D).global_position.z)
		var dist := my_xz.distance_to(other_xz)
		if dist > 0.001 and dist < 1.2:
			var strength: float = (1.2 - dist) / 1.2
			separation += (my_xz - other_xz).normalized() * strength
	return separation

func _is_touching_other_npc() -> bool:
	for i in get_slide_collision_count():
		var col: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = col.get_collider()
		if collider != null and collider != self and (collider.is_in_group("TT") or collider.is_in_group("CT") or collider.name.begins_with("NPC")):
			return true
	return false

func check_if_stuck(delta: float) -> bool:
	if not spawned or current_state != State.WALKING:
		return false
	position_check_timer += delta
	if position_check_timer >= POSITION_CHECK_INTERVAL:
		var moved_distance: float = global_position.distance_to(last_position)
		var is_stuck: bool = moved_distance < STUCK_DIST_THRESHOLD and velocity.length() > 0.5
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
		if collider != null and collider.name == "Jugador" or collider.name == "NPC":
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

func aplicar_skin_aleatoria() -> void:
	var skins: Array[Dictionary] = [
		{
			"tex": preload("res://Texturas/Personajes/Solluxsheet.png"),
			"altura": 2.0,
			"escala": Vector3(4.836, 4.836, 4.836),
			"pos_y": - 0.45
		}
	]
	var skin: Dictionary = skins[randi() % skins.size()]
	if sprite_3d != null:
		sprite_3d.texture = skin["tex"]
		sprite_3d.scale = skin["escala"]
		sprite_3d.position.y = skin["pos_y"]
	if sombra != null:
		sombra.texture = skin["tex"]
	if collision_node != null:
		var shape: Shape3D = collision_node.shape.duplicate()
		if shape is CapsuleShape3D:
			(shape as CapsuleShape3D).height = float(skin["altura"])
		collision_node.shape = shape
