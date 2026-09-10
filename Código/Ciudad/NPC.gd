extends CharacterBody3D

@onready var audio: AudioStreamPlayer3D = $Steps
@onready var talk: Node = $Talk
@onready var sprite3D: Sprite3D = $Sprite3D
@onready var sombra: Sprite3D = $Sombra
@onready var collisionNode: CollisionShape3D = $CollisionShape3D

const DIALOG_SCENE: PackedScene = preload("res://Escenas/Nodos/DialogBobbl.tscn")

# ── Estadísticas y Configuración ────────────────────────────────────────────
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

var navMapReady := false
var speed: float = 4.0
var agent: NavigationAgent3D
var destinationTimer := 0.0
var destinationInterval := 35.0
const ARRIVE_DIST := 1.0
const PATH_CALC_GRACE := 0.5
enum State {WALKING, WAITING}
var currentState = State.WALKING
var waitTimer := 0.0
const WAIT_TIME := 2.0
var spawned = false
var _halfH: float = 1.0
var _bhopEnabled: bool = false
var _wasOnFloor: bool = true
var speechStreams: Array[AudioStream] = []
var _stuckJumps: int = 0
var _dialogTimer: float = 0.0
var lastPosition := Vector3.ZERO
var positionCheckTimer := 0.0
const POSITION_CHECK_INTERVAL := 0.5
const STUCK_DIST_THRESHOLD := 0.08
var _pathIdx: int = 0

# ── Inicialización y Navegación ─────────────────────────────────────────────
func _ready() -> void:
	floor_max_angle = deg_to_rad(max_floor_angle_deg)
	floor_snap_length = floor_snap
	safe_margin = body_safe_margin
	speed = walk_speed
	aplicar_skin_aleatoria()
	var cap := collisionNode.shape as CapsuleShape3D
	if cap != null:
		_halfH = cap.height * 0.5
	for path in speech_paths:
		var stream: Resource = load(path)
		if stream is AudioStream:
			speechStreams.append(stream)
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
	var navRegion: NavigationRegion3D = get_tree().current_scene.find_child("NavigationRegion3D", true, false)
	for _i in range(10):
		if navRegion != null and navRegion.get_navigation_map().is_valid():
			break
		await get_tree().create_timer(0.5).timeout
		navRegion = get_tree().current_scene.find_child("NavigationRegion3D", true, false)
	if navRegion == null or not navRegion.get_navigation_map().is_valid():
		push_warning("NPC %s: sin NavigationRegion3D válida; me quedo quieto." % name)
		return
	navMapReady = true
	var navMap: RID = agent.get_navigation_map()
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(navMap, global_position)
	var offXZ: float = Vector2(closest.x - global_position.x, closest.z - global_position.z).length()
	if offXZ > 0.5:
		global_position = Vector3(closest.x, global_position.y, closest.z)
	lastPosition = global_position
	await get_tree().process_frame
	set_random_destination()

func set_random_destination() -> void:
	if not navMapReady:
		return
	var navMap: RID = agent.get_navigation_map()
	if not navMap.is_valid():
		return
	var radius := 80.0
	for _attempt in range(20):
		var angle: float = randf() * TAU
		var dist: float = randf_range(10.0, radius)
		var randomPos := global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var target: Vector3 = NavigationServer3D.map_get_closest_point(navMap, randomPos)
		var horizontalDist := Vector2(target.x - global_position.x, target.z - global_position.z).length()
		var verticalDist: float = absf(target.y - global_position.y)
		if horizontalDist > 5.0 and verticalDist < 1.5:
			agent.target_position = target
			currentState = State.WALKING
			spawned = true
			destinationTimer = 0.0
			destinationInterval = randf_range(20.0, 50.0)
			_stuckJumps = 0
			_pathIdx = 0
			var willRun: bool = randf() < run_chance
			speed = run_speed if willRun else walk_speed
			_bhopEnabled = willRun and randf() < 0.5
			return

func start_waiting() -> void:
	currentState = State.WAITING
	waitTimer = 0.0

func _do_jump() -> void:
	velocity.y = jump_velocity

# ── Bucle de Física y Estados ───────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not navMapReady:
		return
	if dialog_cooldown > 0.0:
		_dialogTimer = maxf(0.0, _dialogTimer - delta)

	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0

	if currentState == State.WAITING:
		waitTimer += delta
		velocity.x = 0.0
		velocity.z = 0.0
		if audio.playing:
			audio.stop()
		if waitTimer >= WAIT_TIME:
			set_random_destination()
		move_and_slide()
		return

	# Estado de caminata y navegación
	if check_player_collision():
		start_waiting()
	else:
		destinationTimer += delta
		var targetXZ := Vector2(agent.target_position.x, agent.target_position.z)
		var posXZ := Vector2(global_position.x, global_position.z)
		var path := agent.get_current_navigation_path()
		
		var reached: bool = false
		if agent.is_navigation_finished() or posXZ.distance_to(targetXZ) < 1.6:
			reached = true
		elif not path.is_empty() and _pathIdx >= path.size() - 1:
			var lastWpXZ := Vector2(path[path.size() - 1].x, path[path.size() - 1].z)
			if posXZ.distance_to(lastWpXZ) < 0.8:
				reached = true
				
		if reached or destinationTimer >= destinationInterval:
			set_random_destination()
		else:
			_avance(delta)

	if currentState == State.WALKING and spawned and check_if_stuck(delta):
		if is_on_floor() and _stuckJumps < stuck_jump_limit:
			_stuckJumps += 1
			_do_jump()
		else:
			_stuckJumps = 0
			set_random_destination()

	var isMoving: bool = Vector2(velocity.x, velocity.z).length() > 0.5
	if isMoving and is_on_floor():
		if not audio.playing:
			audio.play()
	else:
		if audio.playing:
			audio.stop()
	audio.pitch_scale = 1.5 if speed > 6.0 else 1.05
	
	var isOnFloorNow: bool = is_on_floor()
	if _bhopEnabled and not _wasOnFloor and isOnFloorNow:
		if randf() < 0.5:
			_do_jump()
	_wasOnFloor = isOnFloorNow

	move_and_slide()

# ── Algoritmo de Avance y Lookahead ─────────────────────────────────────────
func _avance(delta: float) -> void:
	var path: PackedVector3Array = agent.get_current_navigation_path()
	if path.is_empty():
		return

	_pathIdx = clampi(_pathIdx, 0, path.size() - 1)
	while _pathIdx < path.size() - 1:
		var dXZ: float = Vector2(path[_pathIdx].x - global_position.x, path[_pathIdx].z - global_position.z).length()
		if dXZ < 0.6:
			_pathIdx += 1
		else:
			break

	var lookIdx: int = path.size() - 1
	for i in range(_pathIdx, path.size()):
		var d: float = Vector2(path[i].x - global_position.x, path[i].z - global_position.z).length()
		if d > 0.75:
			lookIdx = i
			break

	var feetY: float = global_position.y - _halfH
	var npcFullH: float = _halfH * 2.0
	while lookIdx < path.size() - 1:
		var gh: float = Vector2(path[lookIdx].x - global_position.x, path[lookIdx].z - global_position.z).length()
		var gv: float = absf(path[lookIdx].y - feetY)
		if gh < 0.15 and gv > npcFullH * 1.5:
			lookIdx += 1
		else:
			break

	var goal: Vector3 = path[lookIdx]
	var current2D := Vector2(global_position.x, global_position.z)
	var goal2D := Vector2(goal.x, goal.z)
	var distance: float = current2D.distance_to(goal2D)
	var heightDiff: float = goal.y - feetY

	if distance > 0.2:
		var direction := (goal2D - current2D).normalized()
		var sep := _get_separation_vector()
		if sep.length_squared() > 0.001:
			direction = (direction + sep * 0.8).normalized()
			
		velocity.x = direction.x * speed
		velocity.z = direction.y * speed
		
		if is_on_floor() and heightDiff > step_height and heightDiff <= npcFullH:
			_do_jump()
		elif is_on_floor() and heightDiff > step_height * 0.5 and heightDiff <= step_height:
			velocity.y = minf(speed * (heightDiff / maxf(distance, 0.001)), jump_velocity * 0.4)
				
		if direction.length_squared() > 0.01:
			var targetRotation: float = atan2(-direction.x, direction.y)
			rotation.y = lerp_angle(rotation.y, targetRotation, delta * 8.0)
	else:
		velocity.x = lerp(velocity.x, 0.0, delta * 8.0)
		velocity.z = lerp(velocity.z, 0.0, delta * 8.0)

# ── Separación entre NPCs (Evita atascos y encimamientos) ───────────────────
func _get_separation_vector() -> Vector2:
	var separation := Vector2.ZERO
	var myXZ := Vector2(global_position.x, global_position.z)
	var npcs: Array = get_tree().get_nodes_in_group("TT") + get_tree().get_nodes_in_group("CT")
	for npc in npcs:
		if npc == self or not npc is Node3D or ("current_state" in npc and str(npc.current_state) == "DEAD_FROZEN"):
			continue
		var otherXZ := Vector2((npc as Node3D).global_position.x, (npc as Node3D).global_position.z)
		var dist := myXZ.distance_to(otherXZ)
		if dist > 0.001 and dist < 1.2:
			var strength: float = (1.2 - dist) / 1.2
			separation += (myXZ - otherXZ).normalized() * strength
	return separation

func _is_touching_other_npc() -> bool:
	for i in get_slide_collision_count():
		var col: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = col.get_collider()
		if collider != null and collider != self and (collider.is_in_group("TT") or collider.is_in_group("CT") or collider.name.begins_with("NPC")):
			return true
	return false

func check_if_stuck(delta: float) -> bool:
	if not spawned or currentState != State.WALKING:
		return false
	positionCheckTimer += delta
	if positionCheckTimer >= POSITION_CHECK_INTERVAL:
		var movedDistance: float = global_position.distance_to(lastPosition)
		var isStuck: bool = movedDistance < STUCK_DIST_THRESHOLD and velocity.length() > 0.5
		if not isStuck:
			_stuckJumps = 0
		lastPosition = global_position
		positionCheckTimer = 0.0
		return isStuck
	return false

# ── Interacción y Diálogos ──────────────────────────────────────────────────
func check_player_collision() -> bool:
	for i in get_slide_collision_count():
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider != null and (collider.name == "Jugador" or collider.name == "NPC"):
			if dialog_cooldown <= 0.0:
				_spawn_dialog()
			elif _dialogTimer <= 0.0:
				_dialogTimer = dialog_cooldown
				_spawn_dialog()
			return true
	return false

func _spawn_dialog() -> void:
	if speechStreams.is_empty():
		return
	var dialog: Node = DIALOG_SCENE.instantiate()
	var randomIndex: int = randi() % speechStreams.size()
	add_child(dialog)
	dialog.global_position = global_position + Vector3(0, 1.5, 0)
	talk.set("stream", speechStreams[randomIndex])
	talk.call("play")

func aplicar_skin_aleatoria() -> void:
	var skins: Array[Dictionary] = [
		{
			"tex": preload("res://Texturas/Personajes/Solluxsheet.png"),
			"altura": 2.0,
			"escala": Vector3(4.836, 4.836, 4.836),
			"pos_y": -0.45
		}
	]
	var skin: Dictionary = skins[randi() % skins.size()]
	if sprite3D != null:
		sprite3D.texture = skin["tex"]
		sprite3D.scale = skin["escala"]
		sprite3D.position.y = skin["pos_y"]
	if sombra != null:
		sombra.texture = skin["tex"]
	if collisionNode != null:
		var shape: Shape3D = collisionNode.shape.duplicate()
		if shape is CapsuleShape3D:
			(shape as CapsuleShape3D).height = float(skin["altura"])
		collisionNode.shape = shape
