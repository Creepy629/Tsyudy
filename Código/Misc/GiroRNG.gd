extends Sprite3D
class_name GiradorAleatorio

@export var velocidad_min: float = 0.2
@export var velocidad_max: float = 1.2

var _eje: Vector3 = Vector3.UP
var _vel: float = 0.0

func _ready() -> void:
	_eje = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if _eje.length_squared() < 0.001:
		_eje = Vector3.UP
	_eje = _eje.normalized()
	_vel = randf_range(velocidad_min, velocidad_max)

func _process(delta: float) -> void:
	rotate(_eje, _vel * delta)
