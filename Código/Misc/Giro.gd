extends Camera3D
class_name CamaraGiroLento

# Positivo = a contrarreloj
@export var velocidad: float = 0.05   # rad/s: una vuelta completa cada ~2 minutos

func _process(delta: float) -> void:
	rotation.y += velocidad * delta
