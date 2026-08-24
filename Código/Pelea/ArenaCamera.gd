extends SpringArm3D
class_name ArenaCamera

@export var player1: NodePath
@export var player2: NodePath
@export var fight_plane_path: NodePath
var _fight_plane: FightPlane

# ── Configuración base ──────────────────────────────────────────────────────
@export var base_spring_length: float = 1.9
@export var spring_length_per_distance: float = 0.5
@export var min_spring_length: float = 1.7
@export var max_spring_length: float = 5.5

@export var position_lerp_speed: float = 7.0
@export var zoom_lerp_speed: float = 5.0

@export var height_offset: float = 0.1
@export var tilt_degrees: float = 4.0
@export var camera_shake_intensity: float = 0.12
@export var camera_shake_speed: float = 30.0

@export_group("Camera Walls")
@export var enable_camera_walls: bool = true
@export var wall_margin: float = 0.85
@export var wall_padding: float = 0.5
@export var wall_debug: bool = false

var _wall_camera: Camera3D
var _p1: Node3D
var _p2: Node3D
var _shake_amount: float = 0.0
var _shake_time: float = 0.0

func _ready() -> void:
	if not player1.is_empty() and has_node(player1):
		_p1 = get_node(player1)
	if not player2.is_empty() and has_node(player2):
		_p2 = get_node(player2)

	if not _p1 or not _p2:
		var parent = get_parent()
		for child in parent.get_children():
			if child is CharacterBody3D:
				if not _p1: _p1 = child
				elif not _p2: _p2 = child

	if not fight_plane_path.is_empty() and has_node(fight_plane_path):
		_fight_plane = get_node(fight_plane_path) as FightPlane
	
	_wall_camera = _get_camera()

	# Escuchar señales de hitstop para shake
	var hs := get_node_or_null("/root/Hitstop")
	if hs and hs.has_signal("hitstop_triggered"):
		hs.hitstop_triggered.connect(_on_hitstop)

func _on_hitstop(_duration: float) -> void:
	_shake_amount = camera_shake_intensity
	_shake_time = 0.0

func _process(delta: float) -> void:
	if not _p1 or not _p2:
		return
	
	# Shake de cámara
	var shake_x: float = 0.0
	var shake_y: float = 0.0
	if _shake_amount > 0.001:
		_shake_time += delta * camera_shake_speed
		shake_x = sin(_shake_time * 1.7) * _shake_amount
		shake_y = cos(_shake_time * 2.3) * _shake_amount * 0.6
		_shake_amount = max(0.0, _shake_amount - delta * 4.0)
	
	if enable_camera_walls:
		_apply_camera_walls(delta)
	
	var p1_pos: Vector3 = _p1.global_position
	var p2_pos: Vector3 = _p2.global_position
	
	# Punto medio entre jugadores
	var midpoint := Vector3(
		(p1_pos.x + p2_pos.x) * 0.5,
		(p1_pos.y + p2_pos.y) * 0.5 + height_offset,
		(p1_pos.z + p2_pos.z) * 0.5
	)
	
	# Añadir shake
	midpoint.x += shake_x
	midpoint.y += shake_y
	
	global_position = global_position.lerp(midpoint, position_lerp_speed * delta)
	
	# Orientación del SpringArm
	var cam_dir := Vector3.FORWARD
	var fight_dir := Vector3.RIGHT
	
	if _fight_plane:
		cam_dir = _fight_plane.cam_dir
		fight_dir = _fight_plane.fight_dir
	
	var tilt_rad := deg_to_rad(tilt_degrees)
	var z_axis := (cam_dir + Vector3(0.0, tan(tilt_rad), 0.0)).normalized()
	var x_axis := fight_dir
	var y_axis := z_axis.cross(x_axis).normalized()
	x_axis = y_axis.cross(z_axis).normalized()
	global_basis = Basis(x_axis, y_axis, z_axis)
	
	# Zoom dinámico
	var fight_vec := Vector3(p2_pos.x - p1_pos.x, 0.0, p2_pos.z - p1_pos.z)
	var dist: float = fight_vec.length()
	var target_length: float = base_spring_length + dist * spring_length_per_distance
	target_length = clamp(target_length, min_spring_length, max_spring_length)
	spring_length = lerp(spring_length, target_length, zoom_lerp_speed * delta)

func _get_camera() -> Camera3D:
	if _wall_camera and is_instance_valid(_wall_camera):
		return _wall_camera
	for child in get_children():
		if child is Camera3D:
			_wall_camera = child
			return _wall_camera
	_wall_camera = get_viewport().get_camera_3d()
	return _wall_camera

func _apply_camera_walls(_delta: float) -> void:
	var cam := _get_camera()
	if not cam or not _fight_plane:
		return

	var f_dir := _fight_plane.fight_dir
	f_dir.y = 0.0
	if f_dir.length_squared() > 0.0001:
		f_dir = f_dir.normalized()
	else:
		f_dir = Vector3.RIGHT

	var cam_pos := cam.global_position
	var cam_right := cam.global_basis.x
	var cam_forward := -cam.global_basis.z

	for player in [_p1, _p2]:
		var pos: Vector3 = player.global_position
		var to_player := pos - cam_pos
		var depth := to_player.dot(cam_forward)
		if depth <= 0.05:
			continue

		var half_width := _get_half_width_for_depth(depth, cam)
		var max_offset := maxf(0.1, half_width * wall_margin - wall_padding)
		var screen_x := to_player.dot(cam_right)

		if wall_debug and Engine.get_process_frames() % 30 == 0:
			print_debug(
				player.name,
				" screen_x=", snappedf(screen_x, 0.01),
				" | max=", snappedf(max_offset, 0.01)
			)

		if abs(screen_x) <= max_offset:
			continue

		var sign_dir := 1.0 if screen_x > 0.0 else -1.0
		var target_x := sign_dir * max_offset
		player.global_position = pos + f_dir * (target_x - screen_x)

		var body := player as FighterBody
		if body:
			var v_fight := body.velocity.dot(f_dir)
			if sign_dir > 0.0 and v_fight > 0.0:
				body.velocity -= f_dir * v_fight
			elif sign_dir < 0.0 and v_fight < 0.0:
				body.velocity -= f_dir * v_fight

func _get_half_width_for_depth(depth: float, cam: Camera3D) -> float:
	if depth <= 0.0:
		return 0.0

	var vp_size := get_viewport().get_visible_rect().size
	var aspect := 16.0 / 9.0
	if vp_size.y > 0.0:
		aspect = vp_size.x / vp_size.y

	if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		if cam.keep_aspect == Camera3D.KEEP_HEIGHT:
			return cam.size * 0.5 * aspect
		else:
			return cam.size * 0.5

	var fov_rad := deg_to_rad(cam.fov)
	if cam.keep_aspect == Camera3D.KEEP_HEIGHT:
		return depth * tan(fov_rad * 0.5) * aspect
	else:
		return depth * tan(fov_rad * 0.5)
