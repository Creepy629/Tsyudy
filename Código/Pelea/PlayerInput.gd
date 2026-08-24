extends Node
class_name PlayerInput

# Diccionario con los botones predeterminados.
var key_config = {
	"left": KEY_A,
	"right": KEY_D,
	"up": KEY_W,
	"down": KEY_S,
	"heavy_punch": KEY_J,
	"light_punch": KEY_K,
	"heavy_kick": KEY_I,
	"light_kick": KEY_L,
	"guard": KEY_O,
	"sidestep_mod": KEY_U
}

# Prefijo para soportar múltiples jugadores en el futuro (ej. "p1_", "p2_")
var player_prefix = "p1_"
const DOUBLE_TAP_WINDOW := 0.3
var _last_tap_time := {"left": - 999.0, "right": - 999.0, "up": - 999.0, "down": - 999.0}
var _pending_double_tap := {"left": false, "right": false, "up": false, "down": false}
var _input_buffer: Array[Dictionary] = []
const BUFFER_SIZE := 45

func _ready():
	_load_saved_bindings()
	_setup_input_map()

# Registra las acciones dinámicamente en el InputMap de Godot
func _setup_input_map():
	for action_name in key_config.keys():
		var full_action_name = player_prefix + action_name

		if not InputMap.has_action(full_action_name):
			InputMap.add_action(full_action_name)
		else:
			InputMap.action_erase_events(full_action_name)

		var event = InputEventKey.new()
		event.physical_keycode = key_config[action_name]
		InputMap.action_add_event(full_action_name, event)

# Función para reconfigurar un botón en tiempo real
func rebind_key(action_name: String, new_key: int):
	if key_config.has(action_name):
		key_config[action_name] = new_key
		_setup_input_map()

# Debe llamarse UNA vez por frame de física, antes de get_movement_state(),
# para que la detección de doble toque quede sincronizada con el resto del juego.
func poll_double_tap() -> void:
	_check_double_tap("left")
	_check_double_tap("right")

	# Arriba/Abajo solo cuentan como doble-toque si Shift ya está sostenido —
	# así "doble W" sin Shift sigue siendo dos saltos normales, no un sidestep.
	if Input.is_action_pressed(player_prefix + "sidestep_mod"):
		_check_double_tap("up")
		_check_double_tap("down")

func _check_double_tap(dir: String) -> void:
	if Input.is_action_just_pressed(player_prefix + dir):
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_tap_time[dir] <= DOUBLE_TAP_WINDOW:
			_pending_double_tap[dir] = true
			_last_tap_time[dir] = -999.0 # evita que un triple toque dispare dos veces
		else:
			_last_tap_time[dir] = now

# Procesa y retorna los inputs de movimiento y estados especiales del frame.
func get_movement_state() -> Dictionary:
	var state = {
		"dir_x": 0.0,
		"dir_z": 0.0,
		"jump": false,
		"jump_just_pressed": false,
		"crouch": false,
		"guard": Input.is_action_pressed(player_prefix + "guard"),
		"double_tap_left": _pending_double_tap["left"],
		"double_tap_right": _pending_double_tap["right"],
		"double_tap_up": _pending_double_tap["up"],
		"double_tap_down": _pending_double_tap["down"],
		# Añadimos los botones de ataque para el buffer
		"heavy_punch": is_attack_just_pressed("heavy_punch"),
		"light_punch": is_attack_just_pressed("light_punch"),
		"heavy_kick": is_attack_just_pressed("heavy_kick"),
		"light_kick": is_attack_just_pressed("light_kick")
	}

	# Las banderas de doble toque se consumen aquí para que disparen una sola vez.
	_pending_double_tap["left"] = false
	_pending_double_tap["right"] = false
	_pending_double_tap["up"] = false
	_pending_double_tap["down"] = false

	if Input.is_action_pressed(player_prefix + "right"):
		state.dir_x += 1.0
	if Input.is_action_pressed(player_prefix + "left"):
		state.dir_x -= 1.0

	var is_sidestepping = Input.is_action_pressed(player_prefix + "sidestep_mod")

	if is_sidestepping:
		# Shift presionado: W y S se usan para moverse en profundidad (Eje Z)
		if Input.is_action_pressed(player_prefix + "up"):
			state.dir_z -= 1.0
		if Input.is_action_pressed(player_prefix + "down"):
			state.dir_z += 1.0
	else:
		# Sin Shift: W y S son Salto y Agacharse
		if Input.is_action_pressed(player_prefix + "up"):
			state.jump = true
		if Input.is_action_just_pressed(player_prefix + "up"):
			state.jump_just_pressed = true
		if Input.is_action_pressed(player_prefix + "down"):
			state.crouch = true

	# Guardar en el buffer
	_input_buffer.push_front(state.duplicate())
	if _input_buffer.size() > BUFFER_SIZE:
		_input_buffer.pop_back()

	return state

# Verifica si se acaba de presionar un botón de ataque (Just Pressed)
func is_attack_just_pressed(attack_name: String) -> bool:
	var action = player_prefix + attack_name
	if InputMap.has_action(action):
		return Input.is_action_just_pressed(action)
	return false

# Verifica si una secuencia de inputs se cumplió recientemente (orden inverso: índice 0 es el input actual).
# sequence es un arreglo de diccionarios, ej: [{"crouch": true}, {"dir_x": 1.0}, {"heavy_punch": true}]
# Tolerancia define cuántos frames pueden pasar entre cada input de la secuencia.
func check_combo(sequence: Array, facing_sign: float = 1.0, tolerance: int = 45) -> bool:
	if _input_buffer.is_empty(): return false
	
	var seq_index = sequence.size() - 1
	var frames_since_last_match = 0
	
	# Buscamos de atrás hacia adelante en el tiempo (índice 0 es hoy, índice 1 es ayer)
	# para encontrar la secuencia (donde el último elemento de sequence debe ocurrir HOY o muy recientemente)
	for i in range(_input_buffer.size()):
		if frames_since_last_match > tolerance:
			return false
			
		var frame_state = _input_buffer[i]
		var match_current = true
		
		# Verificamos si este frame cumple las condiciones del paso actual de la secuencia
		var conditions = sequence[seq_index]
		for key in conditions:
			var val_in_frame = frame_state.get(key)
			var val_in_cond = conditions[key]
			
			# Si la condición es sobre dir_x (movimiento horizontal),
			# multiplicamos por facing_sign para que 1.0 siempre signifique "Hacia adelante"
			# y -1.0 siempre signifique "Hacia atrás", sin importar de qué lado esté el personaje.
			if key == "dir_x" and typeof(val_in_frame) == TYPE_FLOAT:
				val_in_frame *= facing_sign
				
			if val_in_frame != val_in_cond:
				match_current = false
				break
				
		if match_current:
			seq_index -= 1
			frames_since_last_match = 0
			if seq_index < 0:
				return true
		else:
			frames_since_last_match += 1
			
	return false

# Verifica si un botón fue presionado exactamente `times` veces (o más) dentro de una ventana de `window_frames` frames.
# Útil para detectar doble-pulsación del mismo botón sin usar condiciones "false" como separador.
# Ejemplo: check_repeated_button("light_punch", 2, 30) → true si LP se presionó 2 veces en los últimos 30 frames.
func check_repeated_button(button: String, times: int, window_frames: int = 30) -> bool:
	if _input_buffer.is_empty():
		return false
	var limit = min(window_frames, _input_buffer.size())
	var count := 0
	var prev_was_true := false
	for i in range(limit):
		var val = _input_buffer[i].get(button, false)
		if val and not prev_was_true:
			count += 1
			if count >= times:
				return true
		prev_was_true = val
	return false

# Verifica si un ataque fue presionado recientemente dentro de una ventana de frames (Input Buffer)
func was_attack_pressed(attack_name: String, buffer_frames: int = 10) -> bool:
	if _input_buffer.is_empty():
		return false
	var search_limit = min(buffer_frames, _input_buffer.size())
	for i in range(search_limit):
		if _input_buffer[i].get(attack_name, false):
			return true
	return false

# Consume un botón de ataque específico en todo el buffer para evitar re-disparos
func consume_attack_input(attack_name: String) -> void:
	for frame_state in _input_buffer:
		if frame_state.has(attack_name):
			frame_state[attack_name] = false

# Limpia todo el buffer de inputs
func clear_input_buffer() -> void:
	_input_buffer.clear()

func _load_saved_bindings() -> void:
	var f := FileAccess.open("user://keybinds.cfg", FileAccess.READ)
	if f == null:
		return
	var line := f.get_line()
	while line != "":
		var parts := line.split(":")
		if parts.size() == 2 and key_config.has(parts[0]):
			key_config[parts[0]] = int(parts[1])
		line = f.get_line()
