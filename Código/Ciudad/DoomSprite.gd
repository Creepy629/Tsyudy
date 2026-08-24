extends Sprite3D

@export_group("Referencias")
@export var parent_body: CharacterBody3D # El bastardo que se mueve
@export var face_node: Node3D # El nodo que define hacia dónde mira
@export var target_node: Node3D # Si es null, usa la cámara actual. Si no, usa este nodo (ej: El Sol)

@export_group("Configuración")
@export var walk_frames: int = 8 # Cantidad de HFrames del ciclo de caminata (0 a walk_frames-1)
@export var has_death_anim: bool = false # ¿Tiene animación de muerte? (CT/TT sí, Jugador no)
@export var death_frames: int = 8 # HFrames de la animación de muerte (solo si has_death_anim = true)
@export var anim_speed := 8.0 # FPS de la animación de caminata y muerte
@export var is_shadow := false # Si es sombra, usa la lógica de ángulo invertido
@export var invert_target_angle := false # Para corregir diferencias entre Jugador y NPCs
@export var invert_rotation_direction := false # Para corregir el giro de cámara

var walk_timer := 0.0
var death_timer := 0.0
var was_dead := false

func _process(delta: float) -> void:
	# Determina hacia dónde debe ver el Sprite3D
	var active_target = target_node if target_node else get_viewport().get_camera_3d()
	if not active_target or not face_node: return

	# Billboard en el eje Y mirando al objetivo
	var to_target = active_target.global_position - global_position
	to_target.y = 0
	if to_target.length() > 0.01:
		look_at(global_position + to_target.normalized(), Vector3.UP)

	var to_face = face_node.global_position - global_position
	to_face.y = 0

	var target_pos = to_target
	if is_shadow or invert_target_angle:
		target_pos = - to_target

	# Corrección del giro
	var angle: float
	if invert_rotation_direction:
		angle = atan2(to_face.x, to_face.z) - atan2(target_pos.x, target_pos.z)
	else:
		angle = atan2(to_face.x, to_face.z) + atan2(target_pos.x, target_pos.z)

	var dir_index := get_direction_index(angle)

	# Animación de muerte
	var is_dead := false
	if has_death_anim and parent_body != null and "current_state" in parent_body and "State" in parent_body:
		var keys: Array = parent_body.State.keys()
		var cs: int = parent_body.current_state
		if cs >= 0 and cs < keys.size():
			is_dead = "DEAD_FROZEN" in str(keys[cs])

	if has_death_anim and is_dead:
		if not was_dead:
			death_timer = 0.0
		was_dead = true

		# Animación de muerte: HFrames walk_frames..(walk_frames+death_frames-1)
		# Se avanza hasta el último frame y se congela ahí
		death_timer += delta * anim_speed
		var death_offset := mini(int(death_timer), death_frames - 1)
		frame = dir_index + walk_frames + death_offset
	else:
		if was_dead:
			walk_timer = 0.0
		was_dead = false

		# Animación de caminata: HFrames 0..(walk_frames-1)
		var velocity_length := parent_body.velocity.length() if parent_body else 0.0
		if velocity_length > 0.1:
			walk_timer += delta * anim_speed
			frame = dir_index + (int(walk_timer) % walk_frames)
		else:
			walk_timer = 0.0
			frame = dir_index

func get_direction_index(angle: float) -> int:
	var ang := fmod(angle + TAU, TAU)
	var frames_per_dir := walk_frames + (death_frames if has_death_anim else 0)
	if ang < (PI * 0.125) or ang >= (PI * 1.875): return 0
	elif ang < (PI * 0.375): return frames_per_dir * 1
	elif ang < (PI * 0.625): return frames_per_dir * 2
	elif ang < (PI * 0.875): return frames_per_dir * 3
	elif ang < (PI * 1.125): return frames_per_dir * 4
	elif ang < (PI * 1.375): return frames_per_dir * 5
	elif ang < (PI * 1.625): return frames_per_dir * 6
	else: return frames_per_dir * 7
