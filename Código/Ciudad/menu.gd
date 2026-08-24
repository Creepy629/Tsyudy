extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_apply_saved_city_bindings()
	_setup_controles_button()
	var prob = randi_range(1, 5)
	var Coso = $Label
	
	match prob:
		1:
			Coso.text = "Disparos en la esquina de mi casa."
		2:
			Coso.text = "Un calor tremendo."
		3:
			Coso.text = "Unos eran humanos."
		4:
			Coso.text = "de Polvo Dos."
		5:
			Coso.text = "Buenos días."

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/Mapas/de_dust2.tscn")
	
func _on_button_2_pressed() -> void:
	get_tree().quit()

const CITY_ACTIONS: Array = ["Frente", "Atras", "Derecha", "Izquierda", "Salto", "Correr", "Salir"]

func _apply_saved_city_bindings() -> void:
	var f := FileAccess.open("user://keybinds.cfg", FileAccess.READ)
	if f == null:
		return
	var line := f.get_line()
	while line != "":
		var parts := line.split(":")
		if parts.size() == 2 and CITY_ACTIONS.has(parts[0]):
			if InputMap.has_action(parts[0]):
				InputMap.action_erase_events(parts[0])
				var ev := InputEventKey.new()
				ev.physical_keycode = int(parts[1]) as Key
				InputMap.action_add_event(parts[0], ev)
		line = f.get_line()

func _setup_controles_button() -> void:
	var b := Button.new()
	b.text = "CONTROLES"
	b.anchor_left = 0.5; b.anchor_right = 0.5
	b.anchor_top = 1.0; b.anchor_bottom = 1.0
	b.offset_left = -60; b.offset_right = 60
	b.offset_top = -70; b.offset_bottom = -40
	b.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://Escenas/Pantallas/Controles.tscn"))
	add_child(b)
