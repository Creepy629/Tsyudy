extends Sprite3D
class_name SpriteDoomUniversal

@export_group("Referencias")
@export var parent_body: CharacterBody3D # El bastardo que se mueve
@export var face_node: Node3D # El nodo que define hacia dónde mira
@export var target_node: Node3D # Si es null, usa la cámara actual. Si no, usa este nodo (ej: El Sol)

@export_group("Configuración")
@export var hframes_per_direction := 12
@export var anim_speed := 15.0
@export var is_shadow := false # Si es sombra, usa la lógica de ángulo invertido
@export var invert_target_angle := false # Para corregir diferencias entre Jugador y NPCs que ya me tenía hasta la vrg
@export var invert_rotation_direction := false # Opción para corregir el giro de cámara

var frame_timer := 0.0

func _process(delta: float) -> void:
	# Determinar el objetivo (Cámara o nodo específico como el Sol)
	var active_target = target_node if target_node else get_viewport().get_camera_3d()
	if not active_target or not face_node: return

	# Billboard hardcoded únicamente en el eje Y
	var to_target = active_target.global_position - global_position
	to_target.y = 0
	if to_target.length() > 0.01:
		look_at(global_position + to_target.normalized(), Vector3.UP)

	# Cálculo de Dirección de pa donde mira
	var to_face = face_node.global_position - global_position
	to_face.y = 0
	
	var target_pos = to_target
	if is_shadow or invert_target_angle:
		target_pos = -to_target

	# Corrección del giro
	var angle: float
	if invert_rotation_direction:
		angle = atan2(to_face.x, to_face.z) - atan2(target_pos.x, target_pos.z)
	else:
		angle = atan2(to_face.x, to_face.z) + atan2(target_pos.x, target_pos.z)

	var dir_index = get_direction_index(angle)

	# Animación hardcodeada
	var velocity_length = parent_body.velocity.length() if parent_body else 0.0
	if velocity_length > 0.1:
		frame_timer += delta * anim_speed
		frame = dir_index + (int(frame_timer) % hframes_per_direction)
	else:
		frame = dir_index
		frame_timer = 0.0

func get_direction_index(angle: float) -> int:
	var ang = fmod(angle + TAU, TAU) 
	# 8 direcciones, a lo Earthbound
	if ang < (PI * 0.125) and ang > (PI * -0.125): return 0
	elif ang > (PI * 0.125) and ang < (PI * 0.375): return 12
	elif ang > (PI * 0.375) and ang < (PI * 0.625): return 24
	elif ang > (PI * 0.625) and ang < (PI * 0.875): return 36
	elif ang > (PI * 0.875) and ang < (PI * 1.125): return 48
	elif ang > (PI * 1.125) and ang < (PI * 1.375): return 60
	elif ang > (PI * 1.375) and ang < (PI * 1.625): return 72
	elif ang > (PI * 1.625) and ang < (PI * 1.875): return 84
	return 0
