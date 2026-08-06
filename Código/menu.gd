extends Control

func _ready() -> void:
	var prob = randi_range(1,5)
	var Coso = $Label
	
	match prob:
		1:
			Coso.text = "Siento que esto no está acabado."
		2:
			Coso.text = "Tengo frío, quiero ropa del chopo."
		3:
			Coso.text = "Ayer soñé acerca ocho héroes."
		4:
			Coso.text = "Me siento solo en esta ciudad morada."
		5:
			Coso.text = "Hola, bienvenido."

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/Mapas/Ciudad32.tscn")
	
func _on_button_2_pressed() -> void:
	get_tree().quit()
