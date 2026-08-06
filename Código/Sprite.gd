extends Sprite3D
@onready var cam: Camera3D = get_node("/root/Node3D/Jugador/Pivote/Camera3D")
@onready var look: MeshInstance3D = get_node("/root/Node3D/Jugador/CollisionShape3D/MeshInstance3D")
@onready var guy: CharacterBody3D = get_node("/root/Node3D/Jugador")
var anim_frame := 0
var frame_timer := 0.0
@export var anim_speed := 15.0

func get_direction_index(angle: float) -> int:
	var ang = fmod(angle + TAU, TAU) 

	if ang < (PI * 0.125) and ang > (PI * -0.125):
		return 0
	elif ang > (PI * 0.125) and ang < (PI * 0.375):
		return 12
	elif ang > (PI * 0.375) and ang < (PI * 0.625):
		return 24
	elif ang > (PI * 0.625) and ang < (PI * 0.875):
		return 36
	elif ang > (PI * 0.875) and ang < (PI * 1.125):
		return 48
	elif ang > (PI * 1.125) and ang < (PI * 1.375):
		return 60
	elif ang > (PI * 1.375) and ang < (PI * 1.625):
		return 72
	elif ang > (PI * 1.625) and ang < (PI * 1.875):
		return 84
	else:
		return 0
	
func _process(delta: float) -> void:
	var to_cam = cam.global_position - global_position
	to_cam.y = 0
	look_at(global_position + to_cam.normalized(), Vector3.UP)

	var to_look = look.global_position - global_position
	to_look.y = 0

	var angle = atan2(to_look.x, to_look.z) + atan2(-to_cam.x, to_cam.z)
	var dir_index = get_direction_index(angle)

	var is_moving := check_if_moving()

	if Input.is_action_pressed("Correr") or !guy.is_on_floor():
		anim_speed = 30.0
	else:
		anim_speed = 15.0
	if is_moving:
		frame_timer += delta * anim_speed
		anim_frame = int(frame_timer) % 12
	else:
		anim_frame = 0
		frame_timer = 0.0

	frame = dir_index + anim_frame

func check_if_moving() -> bool:
	var parent := get_parent()
	if parent is CharacterBody3D:
		return parent.velocity.length() > 0.05
	return false
