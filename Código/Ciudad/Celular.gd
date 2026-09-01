extends CanvasLayer

# ─── Layout ──────────────────────────────────────────────────────────────────
const PHONE_W  : int = 230
const PHONE_H  : int = 360
const MARGIN_R : int = 14
const MARGIN_B : int = 8

var y_hidden : float = 9999.0
var y_shown  : float = 0.0

# ─── Nodos ───────────────────────────────────────────────────────────────────
var phone_panel     : Panel
var home_screen     : Control
var settings_screen : Control
var controls_screen : Control
var clock_label     : Label
var home_clock      : Label   # reloj grande en el home
var volume_slider   : HSlider
var volume_val      : Label
var sens_slider     : HSlider
var sens_val        : Label

var is_open : bool  = false
var tween   : Tween = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128

	var vp := get_viewport().get_visible_rect().size
	y_shown  = vp.y - PHONE_H - MARGIN_B
	y_hidden = vp.y + 12.0

	_build_phone()
	phone_panel.position = Vector2(vp.x - PHONE_W - MARGIN_R, y_hidden)
	phone_panel.visible  = false

func _process(_d: float) -> void:
	if not is_open:
		return
	var t := Time.get_time_dict_from_system()
	var ts  := "%02d:%02d" % [t.hour, t.minute]
	if clock_label: clock_label.text = ts
	if home_clock:  home_clock.text  = ts

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Salir") or \
	   (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB):
		toggle_phone()
		get_viewport().set_input_as_handled()

# ─────────────────────────────────────────────────────────────────────────────
func toggle_phone() -> void:
	if is_open: close_phone()
	else:       open_phone()

func open_phone() -> void:
	if is_open: return
	is_open = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_show_screen(home_screen)

	var vp := get_viewport().get_visible_rect().size
	phone_panel.position.x = vp.x - PHONE_W - MARGIN_R
	phone_panel.position.y = y_hidden
	phone_panel.visible    = true

	if tween: tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(phone_panel, "position:y", y_shown, 0.42)

func close_phone() -> void:
	if not is_open: return
	is_open = false

	if tween: tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(phone_panel, "position:y", y_hidden, 0.30)
	tween.tween_callback(func():
		phone_panel.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	)

func _show_screen(target: Control) -> void:
	home_screen.visible     = (target == home_screen)
	settings_screen.visible = (target == settings_screen)
	controls_screen.visible = (target == controls_screen)

# ─── Construcción del cuerpo del teléfono ────────────────────────────────────
func _build_phone() -> void:
	phone_panel = Panel.new()
	phone_panel.size = Vector2(PHONE_W, PHONE_H)

	# Marco exterior grueso estilo smartphone
	var outer := StyleBoxFlat.new()
	outer.bg_color          = Color(0.159, 0.108, 0.151, 1.0)
	outer.border_color      = Color(0.192, 0.186, 0.203, 1.0)
	outer.set_border_width_all(6)
	outer.corner_radius_top_left     = 20
	outer.corner_radius_top_right    = 20
	outer.corner_radius_bottom_left  = 20
	outer.corner_radius_bottom_right = 20
	outer.set_content_margin_all(0)
	phone_panel.add_theme_stylebox_override("panel", outer)
	add_child(phone_panel)

	# ── Notch/barra de estado superior ─────────────────────────────────────
	var status_bar := Panel.new()
	status_bar.position = Vector2(6, 6)
	status_bar.size     = Vector2(PHONE_W - 12, 22)
	var sb_style := StyleBoxFlat.new()
	sb_style.bg_color = Color(0.432, 0.354, 0.0, 1.0)
	sb_style.corner_radius_top_left     = 14
	sb_style.corner_radius_top_right    = 14
	sb_style.corner_radius_bottom_left  = 0
	sb_style.corner_radius_bottom_right = 0
	status_bar.add_theme_stylebox_override("panel", sb_style)
	phone_panel.add_child(status_bar)

	var sb_hbox := HBoxContainer.new()
	sb_hbox.position = Vector2(6, 2)
	sb_hbox.size     = Vector2(PHONE_W - 24, 18)
	status_bar.add_child(sb_hbox)

	var brand_lbl := Label.new()
	brand_lbl.text = "Trollian"
	brand_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand_lbl.add_theme_font_size_override("font_size", 9)
	brand_lbl.add_theme_color_override("font_color", Color(0.794, 0.754, 0.254, 1.0))
	sb_hbox.add_child(brand_lbl)

	clock_label = Label.new()
	clock_label.text = "00:00"
	clock_label.add_theme_font_size_override("font_size", 9)
	clock_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	sb_hbox.add_child(clock_label)

	var icons_lbl := Label.new()
	icons_lbl.text = " 🔋"
	icons_lbl.add_theme_font_size_override("font_size", 8)
	icons_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	sb_hbox.add_child(icons_lbl)

	# ── Pantalla (área de contenido) ────────────────────────────────────────
	var screen_bg := Panel.new()
	screen_bg.position = Vector2(6, 28)
	screen_bg.size     = Vector2(PHONE_W - 12, PHONE_H - 46)
	var screen_style := StyleBoxFlat.new()
	screen_style.bg_color                    = Color(0.161, 0.11, 0.227, 1.0)
	screen_style.corner_radius_top_left      = 0
	screen_style.corner_radius_top_right     = 0
	screen_style.corner_radius_bottom_left   = 14
	screen_style.corner_radius_bottom_right  = 14
	screen_bg.add_theme_stylebox_override("panel", screen_style)
	phone_panel.add_child(screen_bg)

	var screen_sz := Vector2(PHONE_W - 12, PHONE_H - 46)

	home_screen     = _build_home_screen(screen_sz)
	settings_screen = _build_settings_screen(screen_sz)
	controls_screen = _build_controls_screen(screen_sz)

	screen_bg.add_child(home_screen)
	screen_bg.add_child(settings_screen)
	screen_bg.add_child(controls_screen)
	_show_screen(home_screen)

	# ── Barra de inicio inferior (botón home) ───────────────────────────────
	var home_pill := Panel.new()
	home_pill.position = Vector2(PHONE_W / 2 - 28, PHONE_H - 16)
	home_pill.size     = Vector2(56, 5)
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color                    = Color(0.65, 0.65, 0.75, 0.85)
	pill_style.corner_radius_top_left      = 3
	pill_style.corner_radius_top_right     = 3
	pill_style.corner_radius_bottom_left   = 3
	pill_style.corner_radius_bottom_right  = 3
	home_pill.add_theme_stylebox_override("panel", pill_style)
	phone_panel.add_child(home_pill)

# ─── HOME: grid de iconos estilo Android ─────────────────────────────────────
func _build_home_screen(sz: Vector2) -> Control:
	var c := Control.new()
	c.size = sz

	# Reloj grande en la parte superior del wallpaper
	home_clock = Label.new()
	home_clock.text = "00:00"
	home_clock.position = Vector2(0, 10)
	home_clock.size     = Vector2(sz.x, 30)
	home_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_clock.add_theme_font_size_override("font_size", 20)
	home_clock.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	c.add_child(home_clock)

	var date_lbl := Label.new()
	date_lbl.position = Vector2(0, 40)
	date_lbl.size     = Vector2(sz.x, 14)
	date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date_lbl.add_theme_font_size_override("font_size", 9)
	date_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 0.60))
	var d := Time.get_date_dict_from_system()
	date_lbl.text = "%04d-%02d-%02d" % [d.year, d.month, d.day]
	c.add_child(date_lbl)

	# ── Grid de apps ────────────────────────────────────────────────────────
	const APPS := [
		["▶", "Reanudar"],
		["⚙", "Ajustes"],
		["🎮", "Controles"],
		["🏠", "Menú"],
		["🚪", "Salir"],
	]
	const COLS   : int   = 3
	const CELL_W : float = 70.0
	const CELL_H : float = 68.0
	var grid_start_y : float = 60.0
	var grid_start_x : float = (sz.x - COLS * CELL_W) / 2.0

	var cbs := [
		_on_resume_pressed,
		_on_settings_pressed,
		_on_controls_pressed,
		_on_main_menu_pressed,
		_on_quit_pressed,
	]

	for i in APPS.size():
		var col := i % COLS
		var row := i / COLS
		var px  := grid_start_x + col * CELL_W
		var py  := grid_start_y + row * CELL_H
		var icon := _make_app_icon(APPS[i][0], APPS[i][1], CELL_W, CELL_H, cbs[i])
		icon.position = Vector2(px, py)
		c.add_child(icon)

	return c

func _make_app_icon(icon: String, lbl_text: String, w: float, h: float, cb: Callable) -> Control:
	var cell := Control.new()
	cell.size         = Vector2(w, h)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP

	# Fondo del ícono redondeado
	const BG : float = 38.0
	var icon_bg := Panel.new()
	icon_bg.position = Vector2((w - BG) / 2.0, 4.0)
	icon_bg.size     = Vector2(BG, BG)
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color     = Color(0.58, 0.176, 0.125, 0.949)
	bg_s.border_color = Color(0.54, 0.452, 0.164, 0.7)
	bg_s.set_border_width_all(1)
	bg_s.corner_radius_top_left     = 10
	bg_s.corner_radius_top_right    = 10
	bg_s.corner_radius_bottom_left  = 10
	bg_s.corner_radius_bottom_right = 10
	icon_bg.add_theme_stylebox_override("panel", bg_s)
	cell.add_child(icon_bg)

	# Emoji/texto del ícono
	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.position = Vector2(0, 4)
	icon_lbl.size     = Vector2(BG, BG - 6)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 18)
	icon_bg.add_child(icon_lbl)

	# Nombre debajo del ícono
	var name_lbl := Label.new()
	name_lbl.text = lbl_text
	name_lbl.position = Vector2(0, BG + 6)
	name_lbl.size     = Vector2(w, 16)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 1.0, 1.0))
	cell.add_child(name_lbl)

	# Botón invisible que captura el click en toda la celda
	var btn := Button.new()
	btn.flat     = true
	btn.position = Vector2(0, 0)
	btn.size     = Vector2(w, h)
	var flat_s := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", flat_s)
	btn.add_theme_stylebox_override("hover",  flat_s)
	btn.add_theme_stylebox_override("pressed", flat_s)
	btn.pressed.connect(cb)
	cell.add_child(btn)

	return cell

# ─── AJUSTES ─────────────────────────────────────────────────────────────────
func _build_settings_screen(sz: Vector2) -> Control:
	var c := Control.new()
	c.size = sz

	var vb := VBoxContainer.new()
	vb.position = Vector2(10, 8)
	vb.size     = Vector2(sz.x - 20, sz.y - 16)
	vb.add_theme_constant_override("separation", 8)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(vb)

	var title := Label.new()
	title.text = "⚙ AJUSTES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.35))
	vb.add_child(title)
	vb.add_child(_spacer(4))

	# Volumen
	var vlbl := Label.new(); vlbl.text = "Volumen"
	vlbl.add_theme_font_size_override("font_size", 11)
	vb.add_child(vlbl)

	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 6)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step      = 1.0
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mi := AudioServer.get_bus_index("Master")
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(mi)) * 100.0
	volume_slider.value_changed.connect(_on_volume_changed)
	vrow.add_child(volume_slider)
	volume_val = Label.new()
	volume_val.text = "%d%%" % int(volume_slider.value)
	volume_val.add_theme_font_size_override("font_size", 10)
	volume_val.custom_minimum_size = Vector2(34, 0)
	vrow.add_child(volume_val)
	vb.add_child(vrow)

	# Sensibilidad
	var slbl := Label.new(); slbl.text = "Sensibilidad Cámara"
	slbl.add_theme_font_size_override("font_size", 11)
	vb.add_child(slbl)

	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	sens_slider = HSlider.new()
	sens_slider.min_value = 0.001
	sens_slider.max_value = 0.020
	sens_slider.step      = 0.001
	sens_slider.value     = 0.005
	sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sens_slider.value_changed.connect(_on_sens_changed)
	srow.add_child(sens_slider)
	sens_val = Label.new()
	sens_val.text = "%.3f" % sens_slider.value
	sens_val.add_theme_font_size_override("font_size", 10)
	sens_val.custom_minimum_size = Vector2(40, 0)
	srow.add_child(sens_val)
	vb.add_child(srow)

	# NPCs por Spawn / Equipo
	var npclbl := Label.new(); npclbl.text = "NPCs por Bando"
	npclbl.add_theme_font_size_override("font_size", 11)
	vb.add_child(npclbl)

	var npcrow := HBoxContainer.new()
	npcrow.add_theme_constant_override("separation", 6)
	var npc_slider := HSlider.new()
	npc_slider.min_value = 1.0
	npc_slider.max_value = 128.0
	npc_slider.step      = 1.0
	npc_slider.value     = float(GameManager.npc_count_per_team)
	npc_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var npc_val := Label.new()
	npc_val.text = "%d" % GameManager.npc_count_per_team
	npc_val.add_theme_font_size_override("font_size", 10)
	npc_val.custom_minimum_size = Vector2(24, 0)
	
	npc_slider.value_changed.connect(func(v: float):
		GameManager.npc_count_per_team = int(v)
		npc_val.text = "%d" % int(v)
		GameManager.save_config()
	)
	
	npcrow.add_child(npc_slider)
	npcrow.add_child(npc_val)
	vb.add_child(npcrow)

	vb.add_child(_spacer(8))
	var back_btn := Button.new()
	back_btn.text = "⬅  Volver al inicio"
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.add_theme_font_size_override("font_size", 11)
	back_btn.pressed.connect(func(): _show_screen(home_screen))
	vb.add_child(back_btn)

	return c

# ─── CONTROLES (incrustado) ───────────────────────────────────────────────────
func _build_controls_screen(sz: Vector2) -> Control:
	var c := Control.new()
	c.size = sz

	var controles_script = load("res://Código/Ciudad/Controles.gd")
	if controles_script:
		var ctrl := Control.new()
		ctrl.set_script(controles_script)
		ctrl.position = Vector2(0, 0)
		ctrl.size     = sz
		# IMPORTANTE: llamar antes de add_child
		ctrl.set_embedded_mode(func(): _show_screen(home_screen))
		c.add_child(ctrl)
	return c

# ─── Callbacks ────────────────────────────────────────────────────────────────
func _on_resume_pressed()    -> void: close_phone()
func _on_settings_pressed()  -> void: _show_screen(settings_screen)
func _on_controls_pressed()  -> void: _show_screen(controls_screen)
func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/Pantallas/menu.tscn")
func _on_quit_pressed()      -> void: get_tree().quit()

func _on_volume_changed(v: float) -> void:
	var mi := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(mi, linear_to_db(v / 100.0))
	if volume_val: volume_val.text = "%d%%" % int(v)

func _on_sens_changed(v: float) -> void:
	if sens_val: sens_val.text = "%.3f" % v
	var cam := get_tree().root.find_child("Pivote", true, false)
	if cam and "sensibilidad" in cam:
		cam.sensibilidad = v

# ─── Utilidades ───────────────────────────────────────────────────────────────
func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s
