extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_apply_saved_city_bindings()
	var prob = randi_range(1, 10)
	var coso = $Label
	
	match prob:
		1:
			coso.text = "Los del IDF deberían de ir en el TT."
		2:
			coso.text = "Un calor tremendo."
		3:
			coso.text = "Unos eran humanos."
		4:
			coso.text = "de Polvo Dos."
		5:
			coso.text = "Feliz Kirkversario."
		6:
			coso.text = "Mis clases de derecho me enseñaron a no usar\ncosas protegidas por copyright."
		7:
			coso.text = "Sabían que Alva Majo fué el primer YouTuber\nen jugar Tsyudy?"
		8:
			coso.text = "Solo usé LLMs 2 veces, ninguna para el código."
		9:
			coso.text = "Dos equipos son(?)"
		10:
			coso.text = "Odio el sistema de pelea."

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

func _on_button_pressed() -> void:
	call_deferred("_do_change_scene", "res://Escenas/Mapas/de_dust2.tscn")

func _do_change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)

func _on_button_2_pressed() -> void:
	get_tree().quit()

func _on_button_3_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/Pantallas/Controles.tscn")
