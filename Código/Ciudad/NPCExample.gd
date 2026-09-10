extends CharacterBody3D
class_name NPCExample

# ── Parámetros de Interacción ───────────────────────────────────────────────
@export var radio_interaccion: float = 2.0
@export var tecla_interaccion: Key = KEY_E
@export var accion_interaccion: String = ""
@export var cooldown_charla: float = 2.0

enum State {IDLE, HABLANDO, COOLDOWN}
var currentState: State = State.IDLE

var sprite: Sprite3D = null
var dialogBox: DialogBox = null
var _playerRef: Node3D = null
var _frameIdx: int = 0
var _frameTimer: float = 0.0
var _isAnimating: bool = false
var _cooldownTimer: float = 0.0
var _prevKeyPressed: bool = false
var _lastCase: int = 0

const LAYER_NPC: int = 2
const MASK_FAR: int = 5
const CHARLAS_TOTALES: int = 3

# ── Skin ────────────────────────────────────────────────────────────────────
@export var skin_scale: Vector3 = Vector3(4.836, 4.836, 4.836)
@export var skin_pos_y: float = -0.131

func _ready() -> void:
	collision_layer = LAYER_NPC
	collision_mask = MASK_FAR
	_build_collision()
	_build_sprite()
	dialogBox = DialogBox.new()
	dialogBox.name = "Dialogo"
	add_child(dialogBox)
	dialogBox.dialogo_cerrado.connect(_on_dialogo_cerrado)

func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 2.0
	cap.radius = 0.35
	col.shape = cap
	add_child(col)

func _build_sprite() -> void:
	sprite = Sprite3D.new()
	add_child(sprite)
	sprite.scale = skin_scale
	sprite.position.y = skin_pos_y

func _elegir_charla() -> Array[String]:
	var caso: int = randi() % CHARLAS_TOTALES + 1
	if CHARLAS_TOTALES > 1 and caso == _lastCase:
		caso = caso % CHARLAS_TOTALES + 1
	_lastCase = caso
	var charla: Array[String] = []
	match caso:
		1:
			charla = [
				"¿Un... _ troll?",
				"¿En Medio Oriente?",
				"Que jodida está la situación en Alternia, ¿no?",
				"... _ No es como que aquí estemos mejor."
			]
		2:
			charla = [
				"Un calor tremendo, ¿eh? Y apenas es mediodía.",
				"Tres días encadenado a la máquina... _ ~La máquina me habla, te lo juro.~",
				"Dicen que un round perfecto te regresa a tu mundo.",
				"... _ ¿Que te me quedas viendo, estúpido?"
			]
		3:
			charla = [
				"Descargaste el juego como un .exe, ¿cierto?",
				"Escuché de un chico que abrió un juego así, y... _ ~y murió.~",
				"También escuché de un chico que descargó el código fuente en lugar del .exe",
				"Que baboso."
			]
		4:
			charla = [
				"No te he visto por aquí.",
				"¿Ya has probado el cuadrado morado que llamamos \"~Arcade~\"?",
				"Pontele en frente y puchale \"E\"... _ ¿Que qué es \"E\"?",
				"Heh. _ Estos chavos."
			]
		5:
			charla = [
				"Se supone que estoy aquí para proteger la bomba.",
				"¡Pero ni siquiera han venido con ella!",
				"Osea, no está tan mal... _ Fuera de que me estoy quemando en el sol."
			]
		6:
			charla = [
				"No entiendo, ¿no me veo como Terrorista?",
				"Ya van como 3 veces que spawnean y nadie me dispara.",
				"Heh, _ probablemente estoy bien guapo.",
				"Si tuviera redes sociales, hablaría de esto en ellas."
			]
	return charla

# ── Ciclo de Vida y Estados ─────────────────────────────────────────────────
func _process(delta: float) -> void:
	match currentState:
		State.IDLE:
			if _try_interactuar():
				_iniciar_charla()
		State.COOLDOWN:
			_cooldownTimer -= delta
			if _cooldownTimer <= 0.0:
				currentState = State.IDLE

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func _try_interactuar() -> bool:
	var player := _get_player()
	if player == null:
		return false
	var d := global_position - player.global_position
	d.y = 0.0
	if d.length() > radio_interaccion:
		return false
	var pressed: bool
	if accion_interaccion != "" and InputMap.has_action(accion_interaccion):
		pressed = Input.is_action_just_pressed(accion_interaccion)
	else:
		pressed = Input.is_physical_key_pressed(tecla_interaccion) and not _prevKeyPressed
	_prevKeyPressed = Input.is_physical_key_pressed(tecla_interaccion)
	return pressed

func _iniciar_charla() -> void:
	var charla := _elegir_charla()
	if charla.is_empty():
		return
	var player := _get_player()
	if player != null:
		var target := Vector3(player.global_position.x, global_position.y, 2.0 * global_position.z - player.global_position.z)
		if target.distance_squared_to(global_position) > 0.01:
			look_at(target, Vector3.UP)
	currentState = State.HABLANDO
	_isAnimating = true
	_frameIdx = 0
	_frameTimer = 0.0
	dialogBox.mostrar("\n".join(charla))

func _on_dialogo_cerrado() -> void:
	_isAnimating = false
	currentState = State.COOLDOWN
	_cooldownTimer = cooldown_charla

func _get_player() -> Node3D:
	if _playerRef != null and is_instance_valid(_playerRef):
		return _playerRef
	var found: Node = get_tree().current_scene.find_child("Jugador", true, false)
	if found is Node3D:
		_playerRef = found as Node3D
	return _playerRef
