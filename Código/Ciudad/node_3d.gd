extends Node3D

func _ready() -> void:
	if Input.is_action_just_pressed("Salir"):
		get_tree().quit()
