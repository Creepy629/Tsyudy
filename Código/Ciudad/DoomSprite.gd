extends Sprite3D

@export_group("Referencias")
@export var parent_body: CharacterBody3D
@export var face_node: Node3D
@export var target_node: Node3D # Si es null, usa la cámara actual. Si no, usa este nodo (ej: El Sol)

@export_group("Configuración")
@export var walk_frames: int = 8
@export var has_death_anim: bool = false
@export var death_frames: int = 8
@export var anim_speed := 8.0
@export var is_shadow := false
@export var invert_target_angle := false
@export var invert_rotation_direction := false

var walkTimer := 0.0
var deathTimer := 0.0
var wasDead := false
var _prev_pos := Vector3.ZERO

func _ready() -> void:
	_prev_pos = global_position

func _process(delta: float) -> void:
	var activeTarget = target_node if target_node else get_viewport().get_camera_3d()
	if not activeTarget or not face_node: return

	var toTarget = activeTarget.global_position - global_position
	toTarget.y = 0
	if toTarget.length() > 0.01:
		look_at(global_position + toTarget.normalized(), Vector3.UP)

	var toFace = face_node.global_position - global_position
	toFace.y = 0

	var targetPos = toTarget
	if is_shadow or invert_target_angle:
		targetPos = - toTarget

	# Corrección del giro según si el sprite debe verse invertido o no
	var angle: float
	if invert_rotation_direction:
		angle = atan2(toFace.x, toFace.z) - atan2(targetPos.x, targetPos.z)
	else:
		angle = atan2(toFace.x, toFace.z) + atan2(targetPos.x, targetPos.z)

	var dirIndex := get_direction_index(angle)

	var isDead := false
	if has_death_anim and parent_body != null and "current_state" in parent_body and "State" in parent_body:
		var keys: Array = parent_body.State.keys()
		var cs: int = parent_body.current_state
		if cs >= 0 and cs < keys.size():
			isDead = "DEAD_FROZEN" in str(keys[cs])

	if has_death_anim and isDead:
		if not wasDead:
			deathTimer = 0.0
		wasDead = true
		deathTimer += delta * anim_speed
		var deathOffset := mini(int(deathTimer), death_frames - 1)
		frame = dirIndex + walk_frames + deathOffset
	else:
		if wasDead:
			walkTimer = 0.0
		wasDead = false

		var vel: Vector3
		if parent_body:
			vel = parent_body.velocity
		else:
			vel = (global_position - _prev_pos) / maxf(delta, 0.0001)
			_prev_pos = global_position
		var velocityLength := vel.length()
		if velocityLength > 0.1:
			walkTimer += delta * anim_speed
			frame = dirIndex + (int(walkTimer) % walk_frames)
		else:
			walkTimer = 0.0
			frame = dirIndex

func get_direction_index(angle: float) -> int:
	var ang := fmod(angle + TAU, TAU)
	var framesPerDir := walk_frames + (death_frames if has_death_anim else 0)
	if ang < (PI * 0.125) or ang >= (PI * 1.875): return 0
	elif ang < (PI * 0.375): return framesPerDir * 1
	elif ang < (PI * 0.625): return framesPerDir * 2
	elif ang < (PI * 0.875): return framesPerDir * 3
	elif ang < (PI * 1.125): return framesPerDir * 4
	elif ang < (PI * 1.375): return framesPerDir * 5
	elif ang < (PI * 1.625): return framesPerDir * 6
	else: return framesPerDir * 7
