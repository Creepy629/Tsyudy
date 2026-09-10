extends Node3D
class_name OrbitWalker

@export var radio_orbita: float = 3.0
@export var velocidad_orbita: float = 0.6
@export var altura: float = 0.0
@export var fase_inicial: float = 0.0
@export var mirar_hacia_adelante: bool = true
var _theta: float = 0.0
var _pivot: Node3D = null

func _ready() -> void:
	_theta = fase_inicial
	_pivot = Node3D.new()
	_pivot.name = "OrbitPivot"
	add_child(_pivot)
	for kid: Node in get_children():
		if kid != _pivot:
			remove_child(kid)
			_pivot.add_child(kid)

func _process(delta: float) -> void:
	_theta += velocidad_orbita * delta
	if _pivot == null:
		return
	_pivot.position = Vector3(cos(_theta) * radio_orbita, altura, sin(_theta) * radio_orbita)
	if mirar_hacia_adelante and absf(velocidad_orbita) > 0.001:
		var tangente: Vector3 = Vector3(-sin(_theta), 0.0, cos(_theta)) * sign(velocidad_orbita)
		_pivot.rotation.y = atan2(-tangente.x, -tangente.z)
	else:
		_pivot.rotation.y = 0.0
