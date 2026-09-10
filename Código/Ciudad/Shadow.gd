extends Sprite3D

@onready var lit: MeshInstance3D = get_node("/root/Node3D/LaLuh")
@onready var look: MeshInstance3D = get_node("/root/Node3D/Jugador/CollisionShape3D/MeshInstance3D")
var animFrame := 0
var frameTimer := 0.0
@export var anim_speed := 15.0

# Se supone que ya no se ocupa este script en su totalidad, pero
# me da culo quitarlo

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
	var toLit = lit.global_position - global_position
	toLit.y = 0
	look_at(global_position + toLit.normalized(), Vector3.UP)

	var toLook = look.global_position - global_position
	toLook.y = 0

	var angle = atan2(toLook.x, toLook.z) + atan2(-toLit.x, toLit.z)
	var dirIndex = get_direction_index(angle)

	var isMoving := checkIfMoving()

	if Input.is_action_pressed("Correr"):
		anim_speed = 30.0
	else:
		anim_speed = 15.0
	if isMoving:
		frameTimer += delta * anim_speed
		animFrame = int(frameTimer) % 12
	else:
		animFrame = 0
		frameTimer = 0.0

	frame = dirIndex + animFrame

func checkIfMoving() -> bool:
	var parent := get_parent()
	if parent is CharacterBody3D:
		return parent.velocity.length() > 0.05
	return false
