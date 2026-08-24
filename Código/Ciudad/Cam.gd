extends Node3D
@export var sensibilidad: float = 0.005
@export var sensibilidad_joystick: float = 3.0
@export var distancia_minima: float = 3.0
@export var distancia_maxima: float = 15.0
@export var velocidad_zoom: float = 1.0

@onready var spring_arm: SpringArm3D = $SpringArm3D

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	spring_arm.spring_length = clamp(spring_arm.spring_length, distancia_minima, distancia_maxima)

# ── Input general del ratón ───────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	# Control con ratón
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * sensibilidad
		rotation.y = wrapf(rotation.y, 0.0, TAU)
		
		rotation.x -= event.relative.y * sensibilidad
		rotation.x = clamp(rotation.x, -2 * PI / 9, PI / 5)
	
	# Zoom con rueda del ratón
	if event.is_action_pressed("rued_arriba"):
		spring_arm.spring_length -= velocidad_zoom
		spring_arm.spring_length = clamp(spring_arm.spring_length, distancia_minima, distancia_maxima)
		
	if event.is_action_pressed("rued_abajo"):
		spring_arm.spring_length += velocidad_zoom
		spring_arm.spring_length = clamp(spring_arm.spring_length, distancia_minima, distancia_maxima)
	
	# Captura/libera el ratón de la ventana
	if event.is_action_pressed("CapDelMouse"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ── Input general del joystick ────────────────────────────────────────────
func _process(delta: float) -> void:
	# Control con joystick
	var cIzquierda = Input.get_action_strength("cDerecha")
	var cDerecha = Input.get_action_strength("cIzquierda")
	var cArriba = Input.get_action_strength("cAbajo")
	var cAbajo = Input.get_action_strength("cArriba")
	
	# Cálculo del movimiento horizontal y vertical
	var movimiento_horizontal = cDerecha - cIzquierda
	var movimiento_vertical = cAbajo - cArriba
	
	# Aplica la rotación de la cámara con el joystick
	if abs(movimiento_horizontal) > 0.1 or abs(movimiento_vertical) > 0.1:
		rotation.y -= movimiento_horizontal * sensibilidad_joystick * delta
		rotation.y = wrapf(rotation.y, 0.0, TAU)
		
		rotation.x -= movimiento_vertical * sensibilidad_joystick * delta
		rotation.x = clamp(rotation.x, -2 * PI / 9, PI / 5)
