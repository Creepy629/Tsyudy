extends CharacterBody3D

@onready var cam: Camera3D = $Pivote/Camera3D
@onready var audio: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var bodyShape: CollisionShape3D = $CollisionShape3D
@export_category("Movimiento")
@export var walk_speed: float = 8.5
@export var run_speed: float = 14.0
@export var jump_velocity: float = 12.5
@export var accel: float = 85.0
@export var brake_accel: float = 115.0
@export var ground_release_decel: float = 26.0
@export var air_accel: float = 42.0
@export var air_drag: float = 5.0
@export var air_overspeed_drag: float = 0.8
@export var max_air_speed: float = 17.5
@export var landing_momentum: float = 0.05
@export var gravity_mult: float = 2.2

const COYOTE_TIME: float = 0.12
const JUMP_BUFFER: float = 0.14

var _coyote_timer: float = 0.0
var _jump_buffer: float = 0.0
var _was_on_floor: bool = false
var _target_speed: float = 8.5
var _air_hold_speed: float = 0.0
var _last_vertical_speed: float = 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 3

# ── Física y Movimiento ─────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if get_meta("en_dialogo", false):
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var onFloor: bool = is_on_floor()
	var horizontal: Vector2 = Vector2(velocity.x, velocity.z)

	# Coyote time y jump buffer
	if _was_on_floor and not onFloor:
		_coyote_timer = COYOTE_TIME
		_air_hold_speed = horizontal.length()

	if _coyote_timer > 0.0:
		_coyote_timer -= delta

	if Input.is_action_just_pressed("Salto"):
		_jump_buffer = JUMP_BUFFER

	if _jump_buffer > 0.0:
		_jump_buffer -= delta

	var canJump: bool = onFloor or _coyote_timer > 0.0
	if _jump_buffer > 0.0 and canJump:
		velocity.y = jump_velocity
		_coyote_timer = 0.0
		_jump_buffer = 0.0

		horizontal = Vector2(velocity.x, velocity.z)
		if horizontal.length() > 0.1:
			horizontal = horizontal.normalized() * maxf(horizontal.length(), walk_speed)

	# Gravedad y corte de salto variable
	if not onFloor:
		velocity += get_gravity() * gravity_mult * delta
		if not Input.is_action_pressed("Salto") and velocity.y > 0.0:
			velocity.y = move_toward(velocity.y, 0.0, get_gravity().length() * gravity_mult * delta * 2.0)

	_target_speed = run_speed if Input.is_action_pressed("Correr") else walk_speed

	var inputDir: Vector2 = Input.get_vector("Izquierda", "Atras", "Frente", "Derecha")
	var camBasis: Basis = cam.global_transform.basis
	var forward: Vector3 = - camBasis.z.normalized()
	var right: Vector3 = camBasis.x.normalized()
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var direction: Vector3 = (right * -inputDir.x + forward * -inputDir.y)
	var dirLen: float = direction.length()
	if dirLen > 0.01:
		direction = direction / dirLen

	if onFloor:
		if dirLen > 0.01:
			var desiredDir: Vector2 = Vector2(direction.x, direction.z).normalized()
			var desired: Vector2 = desiredDir * _target_speed
			var currentAccel: float = accel

			if horizontal.dot(desired) < 0.0:
				currentAccel = brake_accel
			elif horizontal.length() > desired.length() + 0.25:
				currentAccel = ground_release_decel * 1.35

			horizontal = horizontal.move_toward(desired, currentAccel * delta)
		else:
			horizontal = horizontal.move_toward(Vector2.ZERO, ground_release_decel * delta)
			if horizontal.length() < 0.2:
				horizontal = Vector2.ZERO

		# Transferencia de inercia vertical al caer a velocidad alta
		if not _was_on_floor:
			var impactSpeed: float = absf(_last_vertical_speed)
			if impactSpeed > 8.0 and horizontal.length() > 0.5:
				var boost: float = minf(impactSpeed * landing_momentum, run_speed * 0.30)
				var newSpeed: float = minf(horizontal.length() + boost, max_air_speed)
				horizontal = horizontal.normalized() * newSpeed
	else:
		# Control de movimiento aéreo con inercia y fricción de exceso
		var refSpeed: float = minf(maxf(_target_speed, _air_hold_speed * 0.98), max_air_speed)
		if dirLen > 0.01:
			var wishDir: Vector2 = Vector2(direction.x, direction.z).normalized()
			var projection: float = horizontal.dot(wishDir)
			var addSpeed: float = clampf(refSpeed - projection, 0.0, air_accel * delta)

			if addSpeed > 0.0:
				horizontal += wishDir * addSpeed

			var currentLen: float = horizontal.length()
			if currentLen > refSpeed:
				horizontal = horizontal.normalized() * maxf(refSpeed, currentLen - air_drag * delta * 0.25)
		else:
			horizontal = horizontal.move_toward(Vector2.ZERO, air_drag * delta)

		var hLen: float = horizontal.length()
		if hLen > max_air_speed:
			var excess: float = hLen - max_air_speed
			var reducedLen: float = maxf(max_air_speed, hLen - excess * air_overspeed_drag * delta)
			horizontal = horizontal.normalized() * reducedLen

		_air_hold_speed = maxf(_air_hold_speed - air_drag * delta * 0.5, horizontal.length())

	velocity.x = horizontal.x
	velocity.z = horizontal.y

	# Orientación y rotación suave del personaje
	if dirLen > 0.01:
		var targetRot: float = atan2(direction.x, direction.z)
		bodyShape.rotation.y = lerp_angle(bodyShape.rotation.y, targetRot, delta * 12.0)
	elif horizontal.length() > 0.6:
		var slideRot: float = atan2(horizontal.x, horizontal.y)
		bodyShape.rotation.y = lerp_angle(bodyShape.rotation.y, slideRot, delta * 6.0)

	# Efectos de audio de pasos
	var isMoving: bool = horizontal.length() > 0.05 and onFloor
	if isMoving:
		if not audio.playing:
			audio.play()
	else:
		if audio.playing:
			audio.stop()

	audio.pitch_scale = clampf(1.0 + horizontal.length() / 26.0, 1.05, 1.65)

	_was_on_floor = onFloor
	_last_vertical_speed = velocity.y

	move_and_slide()
