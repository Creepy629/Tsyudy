extends CanvasLayer

# Estaba harto de qué tan deforme estaba quedando con nodos a mano y cómo no
# estaba quedando como me gustaba.
@export var wallpaper_texture: Texture2D = null
@export_file var wallpaper_path: String = "res://Texturas/Branding/wallpaper.jpg"
var restore_mouse_captured_on_close: bool = true # Ahí cuando añada más compatibilidad a controles
const PHONE_W: int = 220                         # va a servir
const PHONE_H: int = 390
const MARGIN_R: int = 14
const MARGIN_B: int = 8
const BASE_RES: Vector2 = Vector2(640.0, 480.0)
const FRAME_PAD: int = 8
const STATUS_H: int = 28
const NAV_H: int = 28
var y_hidden: float = 9999.0
var y_shown: float = 0.0
var phone_panel: Panel
var screen_panel: Panel
var wallpaper_rect: TextureRect
var home_screen: Control
var settings_screen: Control
var match_screen: Control
var clock_label: Label
var home_clock: Label
var volume_slider: HSlider
var volume_val: Label
var sens_slider: HSlider
var sens_val: Label
var match_time_label: Label
var site_a_label: Label
var site_b_label: Label
var feed_box: VBoxContainer
var _feed_version: int = -1
var is_open: bool = false
var tween: Tween = null

func _refresh_scale() -> void:
	var win: Vector2 = Vector2(get_window().size)
	scale = Vector2(BASE_RES.x / win.x, BASE_RES.y / win.y)
	_recalculate_phone_position()

	if phone_panel != null:
		phone_panel.position.x = win.x - PHONE_W - MARGIN_R
		if is_open:
			phone_panel.position.y = y_shown
		else:
			phone_panel.position.y = y_hidden
			
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128

	_build_phone()

	var win: Vector2 = Vector2(get_window().size)
	_recalculate_phone_position()
	phone_panel.position = Vector2(win.x - PHONE_W - MARGIN_R, y_hidden)
	phone_panel.visible = false

	_refresh_scale()
	get_window().size_changed.connect(_refresh_scale)

func _process(_delta: float) -> void:
	if not is_open:
		return

	var time_dict: Dictionary = Time.get_time_dict_from_system()
	var ts: String = "%02d:%02d" % [int(time_dict.hour), int(time_dict.minute)]

	if clock_label != null:
		clock_label.text = ts

	if home_clock != null:
		home_clock.text = ts

	if match_screen != null and match_screen.visible:
		_update_match_app()

func _unhandled_input(event: InputEvent) -> void:
	var wants_toggle: bool = false

	if event.is_action_pressed("Salir"):
		wants_toggle = true

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_TAB:
			wants_toggle = true

	if wants_toggle:
		toggle_phone()
		get_viewport().set_input_as_handled()

func _recalculate_phone_position() -> void:
	var win: Vector2 = Vector2(get_window().size)
	y_shown = win.y - PHONE_H - MARGIN_B
	y_hidden = win.y + 12.0

# ── Apertura / cierre ────────────────────────────────────────────────────────
func toggle_phone() -> void:
	if is_open:
		close_phone()
	else:
		open_phone()

func open_phone() -> void:
	if is_open:
		return

	is_open = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_show_screen(home_screen)
	_recalculate_phone_position()

	var win: Vector2 = Vector2(get_window().size)
	phone_panel.position.x = win.x - PHONE_W - MARGIN_R
	phone_panel.position.y = y_hidden
	phone_panel.visible = true

	if tween != null:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(phone_panel, "position:y", y_shown, 0.42)

func close_phone() -> void:
	if not is_open:
		return

	is_open = false

	if tween != null:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(phone_panel, "position:y", y_hidden, 0.30)
	tween.tween_callback(func() -> void:
		phone_panel.visible = false
		if restore_mouse_captured_on_close:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	)

func _show_screen(target: Control) -> void:
	if home_screen != null:
		home_screen.visible = target == home_screen

	if settings_screen != null:
		settings_screen.visible = target == settings_screen

	if match_screen != null:
		match_screen.visible = target == match_screen

# ── Estructura ───────────────────────────────────────────────────────────────
func _build_phone() -> void:
	phone_panel = Panel.new()
	phone_panel.size = Vector2(PHONE_W, PHONE_H)
	phone_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var outer_style: StyleBoxFlat = StyleBoxFlat.new()
	outer_style.bg_color = Color(0.025, 0.024, 0.03, 1.0)
	outer_style.border_color = Color(0.13, 0.13, 0.16, 1.0)
	outer_style.set_border_width_all(3)
	outer_style.set_corner_radius_all(28)
	outer_style.set_content_margin_all(0)
	phone_panel.add_theme_stylebox_override("panel", outer_style)

	add_child(phone_panel)

	screen_panel = Panel.new()
	screen_panel.position = Vector2(FRAME_PAD, FRAME_PAD)
	screen_panel.size = Vector2(PHONE_W - FRAME_PAD * 2, PHONE_H - FRAME_PAD * 2)
	screen_panel.clip_contents = true
	screen_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var screen_style: StyleBoxFlat = StyleBoxFlat.new()
	screen_style.bg_color = Color(0.055, 0.05, 0.075, 1.0)
	screen_style.set_corner_radius_all(22)
	screen_style.set_content_margin_all(0)
	screen_panel.add_theme_stylebox_override("panel", screen_style)

	phone_panel.add_child(screen_panel)

	var screen_size: Vector2 = screen_panel.size

	_build_wallpaper_layer(screen_size)

	home_screen = _build_home_screen(screen_size)
	settings_screen = _build_settings_screen(screen_size)
	match_screen = _build_match_screen(screen_size)

	screen_panel.add_child(home_screen)
	screen_panel.add_child(settings_screen)
	screen_panel.add_child(match_screen)

	_build_status_bar(screen_size)
	_build_navigation_bar(screen_size)

	_show_screen(home_screen)
	_apply_wallpaper()

func _build_wallpaper_layer(screen_size: Vector2) -> void:
	var base: Panel = Panel.new()
	base.position = Vector2.ZERO
	base.size = screen_size

	var base_style: StyleBoxFlat = StyleBoxFlat.new()
	base_style.bg_color = Color(0.105, 0.075, 0.18, 1.0)
	base_style.set_corner_radius_all(22)
	base.add_theme_stylebox_override("panel", base_style)

	screen_panel.add_child(base)

	screen_panel.add_child(_make_wallpaper_blob(Vector2(-36, 42), Vector2(145, 145), Color(0.74, 0.22, 0.18, 0.70)))
	screen_panel.add_child(_make_wallpaper_blob(Vector2(120, 12), Vector2(138, 138), Color(0.90, 0.66, 0.18, 0.42)))
	screen_panel.add_child(_make_wallpaper_blob(Vector2(70, 225), Vector2(185, 185), Color(0.20, 0.55, 0.95, 0.28)))
	screen_panel.add_child(_make_wallpaper_blob(Vector2(-44, 270), Vector2(130, 130), Color(0.65, 0.25, 0.95, 0.35)))

	wallpaper_rect = TextureRect.new()
	wallpaper_rect.position = Vector2.ZERO
	wallpaper_rect.size = screen_size
	wallpaper_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallpaper_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wallpaper_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	wallpaper_rect.visible = false
	screen_panel.add_child(wallpaper_rect)

	var shade: ColorRect = ColorRect.new()
	shade.position = Vector2.ZERO
	shade.size = screen_size
	shade.color = Color(0.0, 0.0, 0.0, 0.16)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_panel.add_child(shade)

func _make_wallpaper_blob(pos: Vector2, size: Vector2, color: Color) -> Panel:
	var p: Panel = Panel.new()
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(int(max(size.x, size.y)))
	p.add_theme_stylebox_override("panel", s)

	return p

func _apply_wallpaper() -> void:
	if wallpaper_rect == null:
		return

	var tex: Texture2D = wallpaper_texture

	if tex == null and wallpaper_path.strip_edges() != "":
		var loaded_resource: Resource = load(wallpaper_path)
		if loaded_resource is Texture2D:
			tex = loaded_resource as Texture2D

	wallpaper_rect.texture = tex
	wallpaper_rect.visible = tex != null

func set_wallpaper_from_path(path: String) -> void:
	wallpaper_path = path
	wallpaper_texture = null
	_apply_wallpaper()

func set_wallpaper_texture(tex: Texture2D) -> void:
	wallpaper_texture = tex
	wallpaper_path = ""
	_apply_wallpaper()

func _build_status_bar(screen_size: Vector2) -> void:
	var bar: Panel = Panel.new()
	bar.position = Vector2(0, 0)
	bar.size = Vector2(screen_size.x, STATUS_H)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar_style: StyleBoxFlat = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.0, 0.0, 0.0, 0.24)
	bar_style.corner_radius_top_left = 22
	bar_style.corner_radius_top_right = 22
	bar_style.corner_radius_bottom_left = 0
	bar_style.corner_radius_bottom_right = 0
	bar.add_theme_stylebox_override("panel", bar_style)

	screen_panel.add_child(bar)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.position = Vector2(9, 5)
	hbox.size = Vector2(screen_size.x - 18, 18)
	hbox.add_theme_constant_override("separation", 4)
	bar.add_child(hbox)

	clock_label = Label.new()
	clock_label.text = "00:00"
	clock_label.custom_minimum_size = Vector2(40, 0)
	clock_label.add_theme_font_size_override("font_size", 10)
	clock_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.94))
	hbox.add_child(clock_label)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var brand: Label = Label.new()
	brand.text = "Trollian"
	brand.add_theme_font_size_override("font_size", 9)
	brand.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 0.88))
	hbox.add_child(brand)

	var icons: Label = Label.new()
	icons.text = " 5G 🔋"
	icons.add_theme_font_size_override("font_size", 8)
	icons.add_theme_color_override("font_color", Color(0.92, 1.0, 0.94, 0.94))
	hbox.add_child(icons)

func _build_navigation_bar(screen_size: Vector2) -> void:
	var nav: Panel = Panel.new()
	nav.position = Vector2(0, screen_size.y - NAV_H)
	nav.size = Vector2(screen_size.x, NAV_H)
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var nav_style: StyleBoxFlat = StyleBoxFlat.new()
	nav_style.bg_color = Color(0.0, 0.0, 0.0, 0.20)
	nav_style.corner_radius_top_left = 0
	nav_style.corner_radius_top_right = 0
	nav_style.corner_radius_bottom_left = 22
	nav_style.corner_radius_bottom_right = 22
	nav.add_theme_stylebox_override("panel", nav_style)

	screen_panel.add_child(nav)

	var pill: Panel = Panel.new()
	pill.position = Vector2(screen_size.x * 0.5 - 31.0, 11.0)
	pill.size = Vector2(62, 5)

	var pill_style: StyleBoxFlat = StyleBoxFlat.new()
	pill_style.bg_color = Color(1.0, 1.0, 1.0, 0.70)
	pill_style.set_corner_radius_all(4)
	pill.add_theme_stylebox_override("panel", pill_style)

	nav.add_child(pill)

func _build_home_screen(screen_size: Vector2) -> Control:
	var c: Control = Control.new()
	c.size = screen_size
	c.mouse_filter = Control.MOUSE_FILTER_PASS

	home_clock = Label.new()
	home_clock.text = "00:00"
	home_clock.position = Vector2(0, 39)
	home_clock.size = Vector2(screen_size.x, 34)
	home_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_clock.add_theme_font_size_override("font_size", 27)
	home_clock.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.96))
	c.add_child(home_clock)

	var date_lbl: Label = Label.new()
	date_lbl.position = Vector2(0, 73)
	date_lbl.size = Vector2(screen_size.x, 16)
	date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date_lbl.add_theme_font_size_override("font_size", 9)
	date_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.72))

	var date_dict: Dictionary = Time.get_date_dict_from_system()
	date_lbl.text = "%04d-%02d-%02d" % [int(date_dict.year), int(date_dict.month), int(date_dict.day)]
	c.add_child(date_lbl)

	var search: Panel = Panel.new()
	search.position = Vector2(14, 101)
	search.size = Vector2(screen_size.x - 28, 29)

	var search_style: StyleBoxFlat = StyleBoxFlat.new()
	search_style.bg_color = Color(1.0, 1.0, 1.0, 0.16)
	search_style.border_color = Color(1.0, 1.0, 1.0, 0.10)
	search_style.set_border_width_all(1)
	search_style.set_corner_radius_all(15)
	search.add_theme_stylebox_override("panel", search_style)
	c.add_child(search)

	var search_lbl: Label = Label.new()
	search_lbl.text = "🔎 Buscar en Trollian"
	search_lbl.position = Vector2(12, 5)
	search_lbl.size = Vector2(search.size.x - 24, 18)
	search_lbl.add_theme_font_size_override("font_size", 10)
	search_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.72))
	search.add_child(search_lbl)

	const COLS: int = 3
	const CELL_W: float = 64.0
	const CELL_H: float = 70.0

	var grid_start_x: float = (screen_size.x - float(COLS) * CELL_W) * 0.5
	var grid_start_y: float = 146.0

	_add_home_icon(
		c, "▶", "Reanudar", 0, 0,
		grid_start_x, grid_start_y, CELL_W, CELL_H,
		Callable(self, "_on_resume_pressed"),
		Color(0.10, 0.72, 0.38, 1.0)
	)

	_add_home_icon(
		c, "⚙", "Ajustes", 1, 0,
		grid_start_x, grid_start_y, CELL_W, CELL_H,
		Callable(self, "_on_settings_pressed"),
		Color(0.23, 0.45, 0.95, 1.0)
	)

	_add_home_icon(
		c, "📡", "Operativo", 2, 0,
		grid_start_x, grid_start_y, CELL_W, CELL_H,
		Callable(self, "_on_match_pressed"),
		Color(0.80, 0.15, 0.20, 1.0)
	)

	# Dock inferior Android
	var dock: Panel = Panel.new()
	dock.position = Vector2(15, screen_size.y - 91)
	dock.size = Vector2(screen_size.x - 30, 58)

	var dock_style: StyleBoxFlat = StyleBoxFlat.new()
	dock_style.bg_color = Color(1.0, 1.0, 1.0, 0.14)
	dock_style.border_color = Color(1.0, 1.0, 1.0, 0.10)
	dock_style.set_border_width_all(1)
	dock_style.set_corner_radius_all(22)
	dock.add_theme_stylebox_override("panel", dock_style)
	c.add_child(dock)

	var dock_cell_w: float = dock.size.x * 0.5

	var menu_icon: Control = _make_app_icon(
		"🏠", "Menú", dock_cell_w, 58.0,
		Callable(self, "_on_main_menu_pressed"),
		Color(0.95, 0.55, 0.12, 1.0)
	)
	menu_icon.position = Vector2(0, 0)
	dock.add_child(menu_icon)

	var quit_icon: Control = _make_app_icon(
		"🚪", "Salir", dock_cell_w, 58.0,
		Callable(self, "_on_quit_pressed"),
		Color(0.88, 0.17, 0.13, 1.0)
	)
	quit_icon.position = Vector2(dock_cell_w, 0)
	dock.add_child(quit_icon)

	return c

func _add_home_icon(
	parent: Control,
	icon: String,
	label_text: String,
	col: int,
	row: int,
	start_x: float,
	start_y: float,
	cell_w: float,
	cell_h: float,
	callback: Callable,
	icon_color: Color
) -> void:
	var item: Control = _make_app_icon(icon, label_text, cell_w, cell_h, callback, icon_color)
	item.position = Vector2(start_x + float(col) * cell_w, start_y + float(row) * cell_h)
	parent.add_child(item)

func _make_app_icon(
	icon: String,
	label_text: String,
	w: float,
	h: float,
	callback: Callable,
	icon_color: Color
) -> Control:
	var cell: Control = Control.new()
	cell.size = Vector2(w, h)
	cell.mouse_filter = Control.MOUSE_FILTER_PASS

	var shadow: Panel = Panel.new()
	shadow.position = Vector2((w - 42.0) * 0.5 + 1.5, 8.0)
	shadow.size = Vector2(42, 42)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shadow_style: StyleBoxFlat = StyleBoxFlat.new()
	shadow_style.bg_color = Color(0.0, 0.0, 0.0, 0.26)
	shadow_style.set_corner_radius_all(13)
	shadow.add_theme_stylebox_override("panel", shadow_style)
	cell.add_child(shadow)

	var icon_bg: Panel = Panel.new()
	icon_bg.position = Vector2((w - 42.0) * 0.5, 5.0)
	icon_bg.size = Vector2(42, 42)
	icon_bg.pivot_offset = Vector2(21, 21)
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = icon_color
	bg_style.border_color = Color(1.0, 1.0, 1.0, 0.18)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(13)
	icon_bg.add_theme_stylebox_override("panel", bg_style)
	cell.add_child(icon_bg)

	var icon_lbl: Label = Label.new()
	icon_lbl.text = icon
	icon_lbl.position = Vector2(0, 0)
	icon_lbl.size = icon_bg.size
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 19)
	icon_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	icon_bg.add_child(icon_lbl)

	var name_lbl: Label = Label.new()
	name_lbl.text = label_text
	name_lbl.position = Vector2(0, 50)
	name_lbl.size = Vector2(w, 17)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.94))
	cell.add_child(name_lbl)

	var btn: Button = Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.position = Vector2.ZERO
	btn.size = Vector2(w, h)

	var empty_style: StyleBoxEmpty = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_style)
	btn.add_theme_stylebox_override("hover", empty_style)
	btn.add_theme_stylebox_override("pressed", empty_style)
	btn.add_theme_stylebox_override("focus", empty_style)

	btn.mouse_entered.connect(func() -> void:
		icon_bg.scale = Vector2(1.06, 1.06)
	)

	btn.mouse_exited.connect(func() -> void:
		icon_bg.scale = Vector2.ONE
	)

	btn.pressed.connect(callback)
	cell.add_child(btn)

	return cell

# ── Ajustes ──────────────────────────────────────────────────────────────────
func _build_settings_screen(screen_size: Vector2) -> Control:
	var c: Control = Control.new()
	c.size = screen_size

	var bg: Panel = Panel.new()
	bg.position = Vector2.ZERO
	bg.size = screen_size

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.055, 0.045, 0.085, 1.0)
	bg_style.set_corner_radius_all(22)
	bg.add_theme_stylebox_override("panel", bg_style)
	c.add_child(bg)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, STATUS_H + 6)
	scroll.size = Vector2(screen_size.x - 16, screen_size.y - STATUS_H - NAV_H - 14)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(scroll)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	scroll.add_child(vb)

	var title: Label = Label.new()
	title.text = "⚙ Ajustes"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.36, 1.0))
	vb.add_child(title)

	var vlbl: Label = Label.new()
	vlbl.text = "Volumen Master"
	vlbl.add_theme_font_size_override("font_size", 11)
	vlbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.88))
	vb.add_child(vlbl)

	var vrow: HBoxContainer = HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 6)
	vb.add_child(vrow)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var master_bus_index: int = AudioServer.get_bus_index("Master")
	if master_bus_index >= 0:
		volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus_index)) * 100.0
	else:
		volume_slider.value = 100.0

	volume_slider.value_changed.connect(_on_volume_changed)
	vrow.add_child(volume_slider)

	volume_val = Label.new()
	volume_val.text = "%d%%" % int(volume_slider.value)
	volume_val.add_theme_font_size_override("font_size", 10)
	volume_val.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.86))
	volume_val.custom_minimum_size = Vector2(36, 0)
	vrow.add_child(volume_val)

	var slbl: Label = Label.new()
	slbl.text = "Sensibilidad Cámara"
	slbl.add_theme_font_size_override("font_size", 11)
	slbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.88))
	vb.add_child(slbl)

	var srow: HBoxContainer = HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	vb.add_child(srow)

	sens_slider = HSlider.new()
	sens_slider.min_value = 0.001
	sens_slider.max_value = 0.020
	sens_slider.step = 0.001
	sens_slider.value = 0.005
	sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sens_slider.value_changed.connect(_on_sens_changed)
	srow.add_child(sens_slider)

	sens_val = Label.new()
	sens_val.text = "%.3f" % sens_slider.value
	sens_val.add_theme_font_size_override("font_size", 10)
	sens_val.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.86))
	sens_val.custom_minimum_size = Vector2(42, 0)
	srow.add_child(sens_val)

	var npclbl: Label = Label.new()
	npclbl.text = "NPCs por Bando"
	npclbl.add_theme_font_size_override("font_size", 11)
	npclbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.88))
	vb.add_child(npclbl)

	var npcrow: HBoxContainer = HBoxContainer.new()
	npcrow.add_theme_constant_override("separation", 6)
	vb.add_child(npcrow)

	var npc_slider: HSlider = HSlider.new()
	npc_slider.min_value = 1.0
	npc_slider.max_value = 128.0
	npc_slider.step = 1.0
	npc_slider.value = float(_get_npc_count_per_team())
	npc_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	npcrow.add_child(npc_slider)

	var npc_val: Label = Label.new()
	npc_val.text = "%d" % int(npc_slider.value)
	npc_val.add_theme_font_size_override("font_size", 10)
	npc_val.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.86))
	npc_val.custom_minimum_size = Vector2(30, 0)
	npcrow.add_child(npc_val)

	npc_slider.value_changed.connect(func(v: float) -> void:
		var new_value: int = int(v)
		_set_npc_count_per_team(new_value)
		npc_val.text = "%d" % new_value
	)
	
	var sep: Label = Label.new()
	sep.text = "── 🎮 Controles ──"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.add_theme_font_size_override("font_size", 11)
	sep.add_theme_color_override("font_color", Color(1.0, 0.90, 0.36, 0.9))
	vb.add_child(sep)

	var controles_script: Resource = load("res://Código/Ciudad/Controles.gd")
	if controles_script != null:
		var ctrl: Control = Control.new()
		ctrl.set_script(controles_script)
		ctrl.custom_minimum_size = Vector2(0, 260)

		if ctrl.has_method("set_embedded_mode"):
			ctrl.call("set_embedded_mode", Callable(self, "_return_from_controls"))
		vb.add_child(ctrl)
	return c

# ── App Operativo CS ─────────────────────────────────────────────────────────
func _build_match_screen(screen_size: Vector2) -> Control:
	var c: Control = Control.new()
	c.size = screen_size

	var bg: Panel = Panel.new()
	bg.position = Vector2.ZERO
	bg.size = screen_size

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.055, 0.045, 0.085, 1.0)
	bg_style.set_corner_radius_all(22)
	bg.add_theme_stylebox_override("panel", bg_style)
	c.add_child(bg)

	var title: Label = Label.new()
	title.text = "📡 Operativo"
	title.position = Vector2(0, STATUS_H + 6)
	title.size = Vector2(screen_size.x, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.36, 1.0))
	c.add_child(title)

	match_time_label = Label.new()
	match_time_label.text = "--:--"
	match_time_label.position = Vector2(0, STATUS_H + 28)
	match_time_label.size = Vector2(screen_size.x, 30)
	match_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match_time_label.add_theme_font_size_override("font_size", 24)
	match_time_label.add_theme_color_override("font_color", Color(0.99, 0.83, 0.28, 1.0))
	c.add_child(match_time_label)

	site_a_label = Label.new()
	site_a_label.text = "A: LIBRE"
	site_a_label.position = Vector2(16, STATUS_H + 62)
	site_a_label.size = Vector2(screen_size.x - 32, 16)
	site_a_label.add_theme_font_size_override("font_size", 10)
	c.add_child(site_a_label)

	site_b_label = Label.new()
	site_b_label.text = "B: LIBRE"
	site_b_label.position = Vector2(16, STATUS_H + 78)
	site_b_label.size = Vector2(screen_size.x - 32, 16)
	site_b_label.add_theme_font_size_override("font_size", 10)
	c.add_child(site_b_label)

	var feed_title: Label = Label.new()
	feed_title.text = "── Bajas ──"
	feed_title.position = Vector2(0, STATUS_H + 100)
	feed_title.size = Vector2(screen_size.x, 14)
	feed_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feed_title.add_theme_font_size_override("font_size", 10)
	feed_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.6))
	c.add_child(feed_title)

	feed_box = VBoxContainer.new()
	feed_box.position = Vector2(12, STATUS_H + 118)
	feed_box.size = Vector2(screen_size.x - 24, screen_size.y - STATUS_H - NAV_H - 160)
	feed_box.add_theme_constant_override("separation", 3)
	c.add_child(feed_box)

	var back_btn: Button = Button.new()
	back_btn.text = "⬅  Volver al inicio"
	back_btn.position = Vector2(12, screen_size.y - NAV_H - 32)
	back_btn.size = Vector2(screen_size.x - 24, 26)
	back_btn.add_theme_font_size_override("font_size", 11)
	_style_android_button(back_btn, Color(1.0, 1.0, 1.0, 0.14), Color(1.0, 1.0, 1.0, 0.22))
	back_btn.pressed.connect(func() -> void:
		_show_screen(home_screen)
	)
	c.add_child(back_btn)

	return c

func _update_match_app() -> void:
	var snap: Dictionary = CSHUD.get_match_snapshot()
	if snap.is_empty():
		return

	if match_time_label != null:
		match_time_label.text = str(snap.get("time", "--:--"))

	if site_a_label != null:
		site_a_label.text = "A: %s" % str(snap.get("a_text", "LIBRE "))
		site_a_label.add_theme_color_override(
			"font_color", CSHUD.site_color(int(snap.get("a_state", 0)))
		)

	if site_b_label != null:
		site_b_label.text = "B: %s" % str(snap.get("b_text", "LIBRE "))
		site_b_label.add_theme_color_override(
			"font_color", CSHUD.site_color(int(snap.get("b_state", 0)))
		)

	var current_version: int = CSHUD.get_killfeed_version()
	if feed_box != null and current_version != _feed_version:
		_feed_version = current_version

		for ch in feed_box.get_children():
			ch.queue_free()

		for entry in CSHUD.get_killfeed():
			var rtl := RichTextLabel.new()
			rtl.fit_content = true
			rtl.bbcode_enabled = true
			rtl.scroll_active = false
			rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rtl.add_theme_font_size_override("normal_font_size", 9)

			var killer_color: Color = CSHUD.COL_CT if bool(entry.get("killer_ct", false)) else CSHUD.COL_TT
			var victim_color: Color = CSHUD.COL_TT if bool(entry.get("killer_ct", false)) else CSHUD.COL_CT

			rtl.text = "[color=%s][b]%s[/b][/color] %s [color=%s][b]%s[/b][/color]" % [
				killer_color.to_html(false), str(entry.get("killer", "?")),
				str(entry.get("weapon", "🔫")),
				victim_color.to_html(false), str(entry.get("victim", "?"))
			]
			feed_box.add_child(rtl)

# ── Callbacks de apps ────────────────────────────────────────────────────────
func _on_resume_pressed() -> void:
	close_phone()

func _on_settings_pressed() -> void:
	_show_screen(settings_screen)

func _on_match_pressed() -> void:
	_show_screen(match_screen)

func _return_from_controls() -> void:
	_show_screen(home_screen)

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/Pantallas/menu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_volume_changed(v: float) -> void:
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	if master_bus_index >= 0:
		var linear_value: float = clampf(v / 100.0, 0.0, 1.0)
		var db_value: float = -80.0

		if linear_value > 0.001:
			db_value = linear_to_db(linear_value)

		AudioServer.set_bus_volume_db(master_bus_index, db_value)

	if volume_val != null:
		volume_val.text = "%d%%" % int(v)

func _on_sens_changed(v: float) -> void:
	if sens_val != null:
		sens_val.text = "%.3f" % v

	var cam: Node = get_tree().root.find_child("Pivote", true, false)
	if cam != null and "sensibilidad" in cam:
		cam.set("sensibilidad", v)

# ── GameManager seguro ───────────────────────────────────────────────────────
func _get_npc_count_per_team() -> int:
	var gm_node: Node = get_node_or_null("/root/GameManager")
	if gm_node == null:
		return 16

	var raw_value: Variant = gm_node.get("npc_count_per_team")
	if raw_value == null:
		return 16

	return clampi(int(raw_value), 1, 128)

func _set_npc_count_per_team(value: int) -> void:
	var gm_node: Node = get_node_or_null("/root/GameManager")
	if gm_node == null:
		return

	var safe_value: int = clampi(value, 1, 128)
	gm_node.set("npc_count_per_team", safe_value)

	if gm_node.has_method("save_config"):
		gm_node.call("save_config")

# ── Utilidades UI ────────────────────────────────────────────────────────────
func _spacer(h: int) -> Control:
	var s: Control = Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

func _style_android_button(btn: Button, normal_color: Color, hover_color: Color) -> void:
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = normal_color
	normal_style.border_color = Color(1.0, 1.0, 1.0, 0.12)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(14)

	var hover_style: StyleBoxFlat = StyleBoxFlat.new()
	hover_style.bg_color = hover_color
	hover_style.border_color = Color(1.0, 1.0, 1.0, 0.18)
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(14)

	var pressed_style: StyleBoxFlat = StyleBoxFlat.new()
	pressed_style.bg_color = Color(1.0, 1.0, 1.0, 0.28)
	pressed_style.border_color = Color(1.0, 1.0, 1.0, 0.22)
	pressed_style.set_border_width_all(1)
	pressed_style.set_corner_radius_all(14)

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
