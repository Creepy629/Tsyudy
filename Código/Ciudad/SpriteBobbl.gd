extends Sprite3D

@export var anim_speed := 12.0
@export var lifetime := 3.0

var animFrame := 0
var frameTimer := 0.0
var selectedRow := 0
var timer := 0.0

func _ready() -> void:
	selectedRow = randi_range(0, 2)
	hframes = 16
	vframes = 3
	frame = selectedRow * hframes

func _process(delta: float) -> void:
	timer += delta
	if timer >= lifetime:
		queue_free()
		return
	frameTimer += delta * anim_speed
	animFrame = int(frameTimer) % hframes
	frame = (selectedRow * hframes) + animFrame
