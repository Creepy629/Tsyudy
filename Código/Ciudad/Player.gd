extends CharacterBody3D

# Técnicamente es el mismo código que el de los NPCs, pero con feeling más pulido.
@onready var cam:   Camera3D              = $Pivote/Camera3D
@onready var audio: AudioStreamPlayer3D  = $AudioStreamPlayer3D

# ── Constantes de movimiento ───────────────────────────────────────────────
const WALK_SPEED    : float = 8.5
const RUN_SPEED     : float = 14.0
const JUMP_VELOCITY : float = 12.5   # impulso inicial de salto rápido y firme
const ACCEL         : float = 85.0   # aceleración inmediata (sin retardo inicial al caminar)
const DECEL         : float = 95.0   # frenado inmediato (sin resbalarse)
const AIR_ACCEL     : float = 35.0   # control aéreo reactivo
const GRAVITY_MULT  : float = 2.2    # gravedad incrementada para evitar caída de globo

# ── Coyote time y jump buffer ──────────────────────────────────────────────
# Traducidos del playerExamp OGEnCiudad.gd 2D al espacio 3D.
const COYOTE_TIME   : float = 0.12   # segundos tras caer del borde donde aún se puede saltar
const JUMP_BUFFER   : float = 0.14   # segundos que se guarda el input de salto antes de tocar suelo

var _coyote_timer   : float = 0.0
var _jump_buffer    : float = 0.0
var _was_on_floor   : bool  = false

# ── Estado ────────────────────────────────────────────────────────────────
var _target_speed   : float = WALK_SPEED

func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	# ── Coyote time ────────────────────────────────────────────────────────
	if _was_on_floor and not on_floor:
		_coyote_timer = COYOTE_TIME   # acaba de caer: empieza a contar
	if _coyote_timer > 0.0:
		_coyote_timer -= delta

	# ── Jump buffer: guardar el input si no ha aterrizado aún ──────────────
	if Input.is_action_just_pressed("Salto"):
		_jump_buffer = JUMP_BUFFER
	if _jump_buffer > 0.0:
		_jump_buffer -= delta

	# ── Salto (coyote + buffer) ────────────────────────────────────────────
	var can_jump := on_floor or _coyote_timer > 0.0
	if _jump_buffer > 0.0 and can_jump:
		velocity.y    = JUMP_VELOCITY
		_coyote_timer = 0.0
		_jump_buffer  = 0.0

	# ── Gravedad firme (caída rápida sin flotar) ─────────────────────────
	if not on_floor:
		velocity += get_gravity() * GRAVITY_MULT * delta
		# Corte si se suelta el botón de salto en pleno ascenso
		if not Input.is_action_pressed("Salto") and velocity.y > 0.0:
			velocity.y = move_toward(velocity.y, 0.0, get_gravity().length() * GRAVITY_MULT * delta * 2.0)

	# ── Velocidad objetivo (walk/run) ─────────────────────────────────────
	if Input.is_action_pressed("Correr"):
		_target_speed = RUN_SPEED
	else:
		_target_speed = WALK_SPEED

	# ── Movimiento relativo a la cámara ───────────────────────────────────
	# Si ves que está extraño el orden de las direcciones, no te
	# imaginas cómo están en la config del proyecto
	var input_dir := Input.get_vector("Izquierda", "Atras", "Frente", "Derecha")
	var cam_basis  := cam.global_transform.basis
	var forward    := -cam_basis.z.normalized()
	var right      :=  cam_basis.x.normalized()
	forward.y = 0.0; forward = forward.normalized()
	right.y   = 0.0; right   = right.normalized()

	var direction := (right * -input_dir.x + forward * -input_dir.y)
	var dir_len   := direction.length()

	# ── Aceleración / Desaceleración progresiva (del feeling del 2D) ──────
	var accel := AIR_ACCEL if not on_floor else ACCEL
	var decel := AIR_ACCEL if not on_floor else DECEL

	if dir_len > 0.01:
		direction = direction / dir_len   # normalizar manualmente para no perder magnitud diagonal
		velocity.x = move_toward(velocity.x, direction.x * _target_speed, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * _target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		velocity.z = move_toward(velocity.z, 0.0, decel * delta)

	# ── Rotación del personaje ─────────────────────────────────────────────
	if dir_len > 0.01:
		var target_rot := atan2(direction.x, direction.z)
		$CollisionShape3D.rotation.y = lerp_angle(
			$CollisionShape3D.rotation.y, target_rot, delta * 12.0
		)

	# ── Sonido de pasos ───────────────────────────────────────────────────
	var is_moving := dir_len > 0.01 and on_floor
	if is_moving:
		if not audio.playing:
			audio.play()
	else:
		if audio.playing:
			audio.stop()
	audio.pitch_scale = 1.5 if _target_speed >= RUN_SPEED else 1.05

	_was_on_floor = on_floor
	move_and_slide()
