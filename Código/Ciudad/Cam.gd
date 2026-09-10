extends Node3D

@export var sensibilidad: float = 0.005
@export var sensibilidad_joystick: float = 3.0
@export var distancia_minima: float = 3.0
@export var distancia_maxima: float = 15.0
@export var velocidad_zoom: float = 1.0

# ── Cámara al hombro para diálogos ──────────────────────────────────────────
@export var dialogo_lateral: float = 0.6
@export var dialogo_dist_npc: float = 0.6
@export var dialogo_altura: float = 0.25
@export var dialogo_focus_height: float = 0.0
@export var dialogo_lerp: float = 6.0
@export var hombro_derecho: bool = false
@export var dialogo_zoom: float = 3.0

@onready var spring_arm: SpringArm3D = $SpringArm3D

var _dialogo_target: Node3D = null
var _dialogo_cam_pos: Vector3 = Vector3.ZERO
var _spring_length_base: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	spring_arm.add_excluded_object(get_parent().get_rid())
	spring_arm.spring_length = clamp(spring_arm.spring_length, distancia_minima, distancia_maxima)
	_spring_length_base = spring_arm.spring_length
	$SpringArm3D/Spring.position.z = spring_arm.spring_length
	$Camera3D.position.z = spring_arm.spring_length
	add_to_group("cam_ciudad")

# ── API de Diálogo ──────────────────────────────────────────────────────────
func enter_dialogue_mode(target: Node3D) -> void:
	_dialogo_target = target
	_spring_length_base = spring_arm.spring_length
	spring_arm.spring_length = dialogo_zoom
	var playerPos: Vector3 = get_parent().global_position
	var npcPos: Vector3 = target.global_position
	target.look_at(Vector3(playerPos.x, npcPos.y, 2.0 * npcPos.z - playerPos.z), Vector3.UP)
	
	# Cálculo de offset de cámara sobre el hombro en base al vector relativo
	var toNpc: Vector3 = (npcPos - playerPos).normalized()
	var lateralDir: Vector3 = Vector3(toNpc.z, 0.0, -toNpc.x) * (1.0 if hombro_derecho else -1.0)
	_dialogo_cam_pos = npcPos - toNpc * dialogo_dist_npc + lateralDir * dialogo_lateral + Vector3(0.0, dialogo_altura, 0.0)
	get_parent().set_meta("en_dialogo", true)

func exit_dialogue_mode() -> void:
	_dialogo_target = null
	spring_arm.spring_length = _spring_length_base
	position = Vector3.ZERO
	rotation.z = 0.0
	rotation.x = clamp(rotation.x, -2 * PI / 9, PI / 5)
	get_parent().set_meta("en_dialogo", false)

# ── Input del Ratón ─────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if _dialogo_target != null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * sensibilidad
		rotation.y = wrapf(rotation.y, 0.0, TAU)
		rotation.x -= event.relative.y * sensibilidad
		rotation.x = clamp(rotation.x, -2 * PI / 9, PI / 5)
	if event.is_action_pressed("rued_arriba"):
		spring_arm.spring_length = clamp(spring_arm.spring_length - velocidad_zoom, distancia_minima, distancia_maxima)
	if event.is_action_pressed("rued_abajo"):
		spring_arm.spring_length = clamp(spring_arm.spring_length + velocidad_zoom, distancia_minima, distancia_maxima)
	if event.is_action_pressed("CapDelMouse"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)

# ── Proceso de Movimiento y Cámara al Hombro ────────────────────────────────
func _process(delta: float) -> void:
	if _dialogo_target != null and is_instance_valid(_dialogo_target):
		_process_dialogo(delta)
		return
	if _dialogo_target != null:
		exit_dialogue_mode()
		
	var cLeft = Input.get_action_strength("cDerecha")
	var cRight = Input.get_action_strength("cIzquierda")
	var cUp = Input.get_action_strength("cAbajo")
	var cDown = Input.get_action_strength("cArriba")
	var moveH = cRight - cLeft
	var moveV = cDown - cUp
	if abs(moveH) > 0.1 or abs(moveV) > 0.1:
		rotation.y = wrapf(rotation.y - moveH * sensibilidad_joystick * delta, 0.0, TAU)
		rotation.x = clamp(rotation.x - moveV * sensibilidad_joystick * delta, -2 * PI / 9, PI / 5)

# Interpolación de posición global y orientación mirando al objetivo
func _process_dialogo(delta: float) -> void:
	var targetPos: Vector3 = _dialogo_target.global_position + Vector3(0.0, dialogo_focus_height, 0.0)
	var desiredPos: Vector3 = global_position.lerp(_dialogo_cam_pos, clampf(dialogo_lerp * delta, 0.0, 1.0))
	var desiredBasis: Basis = global_transform.looking_at(targetPos, Vector3.UP).basis
	global_transform = Transform3D(desiredBasis, desiredPos)
