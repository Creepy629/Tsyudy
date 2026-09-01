extends Control

const CFG_PATH: String = "user://keybinds.cfg"
var _entries: Array = []
var _overrides: Dictionary = {}
var _waiting_index: int = -1
var _container: VBoxContainer = null

var _on_back_callback: Callable = Callable()
var _is_embedded: bool = false

# Debe llamarse ANTES de add_child para que _ready() vea _is_embedded=true
func set_embedded_mode(callback: Callable) -> void:
	_is_embedded = true
	_on_back_callback = callback

func _ready() -> void:
	if not _is_embedded:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_load_cfg()
	_build_ui()

func _load_cfg() -> void:
	var f := FileAccess.open(CFG_PATH, FileAccess.READ)
	if f == null:
		return
	var line := f.get_line()
	while line != "":
		var parts := line.split(":")
		if parts.size() == 2:
			_overrides[parts[0]] = int(parts[1])
		line = f.get_line()

# ── Construcción de config. ───────────────────────────────────────────────
func _build_ui() -> void:
	if not _is_embedded:
		var bg := ColorRect.new()
		bg.color = Color(0.03, 0.02, 0.05)
		bg.set_anchors_preset(PRESET_FULL_RECT)
		add_child(bg)
	
	var title := Label.new()
	title.text = "CONTROLES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_right = 1.0
	title.offset_top = 5
	title.offset_bottom = 30
	title.add_theme_font_size_override("font_size", 14 if _is_embedded else 24)
	add_child(title)
	
	var scroll := ScrollContainer.new()
	scroll.offset_left = 5 if _is_embedded else 80
	scroll.offset_right = -5 if _is_embedded else -80
	scroll.offset_top = 30 if _is_embedded else 50
	scroll.offset_bottom = -45 if _is_embedded else -50
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)
	
	_container = VBoxContainer.new()
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_container)
	
	_add_section("PELEA")
	_add_row("Izquierda", "fight", "left")
	_add_row("Derecha", "fight", "right")
	_add_row("Salto", "fight", "up")
	_add_row("Agacharse", "fight", "down")
	_add_row("Golpe Fuerte", "fight", "heavy_punch")
	_add_row("Golpe Débil", "fight", "light_punch")
	_add_row("Patada Fuerte", "fight", "heavy_kick")
	_add_row("Patada Débil", "fight", "light_kick")
	_add_row("Guardia", "fight", "guard")
	_add_row("Sidestep", "fight", "sidestep_mod")
	_add_section("CIUDAD")
	_add_row("Frente", "city", "Frente")
	_add_row("Atras", "city", "Atras")
	_add_row("Derecha", "city", "Derecha")
	_add_row("Izquierda", "city", "Izquierda")
	_add_row("Salto", "city", "Salto")
	_add_row("Correr", "city", "Correr")
	
	var back := Button.new()
	back.text = "VOLVER"
	back.anchor_left = 0.5; back.anchor_right = 0.5
	back.anchor_top = 1.0; back.anchor_bottom = 1.0
	back.offset_left = -50 if _is_embedded else -60
	back.offset_right = 50 if _is_embedded else 60
	back.offset_top = -38 if _is_embedded else -40
	back.offset_bottom = -8 if _is_embedded else -10
	back.pressed.connect(func() -> void:
		if _on_back_callback.is_valid():
			_on_back_callback.call()
		else:
			get_tree().change_scene_to_file("res://Escenas/Pantallas/menu.tscn")
	)
	add_child(back)

func _add_section(text: String) -> void:
	var l := Label.new()
	l.text = "-- " + text + " --"
	_container.add_child(l)

func _add_row(display: String, scope: String, key: String) -> void:
	var row := HBoxContainer.new()
	_container.add_child(row)
	var name_l := Label.new()
	name_l.text = display
	name_l.custom_minimum_size = Vector2(100 if _is_embedded else 220, 0)
	if _is_embedded:
		name_l.add_theme_font_size_override("font_size", 11)
	row.add_child(name_l)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(90 if _is_embedded else 180, 0)
	if _is_embedded:
		btn.add_theme_font_size_override("font_size", 11)
	row.add_child(btn)
	var idx := _entries.size()
	_entries.append({"display": display, "scope": scope, "key": key, "btn": btn})
	btn.pressed.connect(func() -> void: _on_row_pressed(idx))
	_refresh_row(idx)

func _current_keycode(idx: int) -> int:
	var e: Dictionary = _entries[idx]
	if e.scope == "fight":
		return int(_overrides.get(e.key, _default_fight(e.key)))
	return int(_overrides.get(e.key, _default_city(e.key)))

func _default_fight(key: String) -> int:
	match key:
		"left": return KEY_A
		"right": return KEY_D
		"up": return KEY_W
		"down": return KEY_S
		"heavy_punch": return KEY_J
		"light_punch": return KEY_K
		"heavy_kick": return KEY_I
		"light_kick": return KEY_L
		"guard": return KEY_O
		"sidestep_mod": return KEY_U
	return KEY_SPACE

func _default_city(key: String) -> int:
	match key:
		"Frente": return KEY_W
		"Atras": return KEY_A
		"Derecha": return KEY_S
		"Izquierda": return KEY_D
		"Salto": return KEY_SPACE
		"Correr": return KEY_SHIFT
	return KEY_SPACE

func _refresh_row(idx: int) -> void:
	var e: Dictionary = _entries[idx]
	(e.btn as Button).text = OS.get_keycode_string(_current_keycode(idx) as Key)

func _on_row_pressed(idx: int) -> void:
	_waiting_index = idx
	(_entries[idx].btn as Button).text = "PRESIONA..."

func _unhandled_key_input(event: InputEvent) -> void:
	if _waiting_index < 0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = int(event.physical_keycode)
		if code != 0:
			var e: Dictionary = _entries[_waiting_index]
			_overrides[e.key] = code
			_apply_live(e.scope, e.key, code)
			_refresh_row(_waiting_index)
		_waiting_index = -1
		_save_cfg()

func _apply_live(scope: String, key: String, code: int) -> void:
	var action: String = ("p1_" + key) if scope == "fight" else key
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = code as Key
		InputMap.action_add_event(action, ev)

func _save_cfg() -> void:
	var f := FileAccess.open(CFG_PATH, FileAccess.WRITE)
	if f == null:
		return
	for k in _overrides.keys():
		f.store_line("%s:%d" % [str(k), int(_overrides[k])])
