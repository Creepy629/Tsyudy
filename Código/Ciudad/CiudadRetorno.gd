extends Node3D
func _ready() -> void:
	if CityReturnRef.active:
		var player: Node3D = get_node_or_null("Jugador")
		if player != null:
			player.global_position = CityReturnRef.position
		elif player == null:
			check_player_position()
		CityReturnRef.active = false


func check_player_position() -> void:
	if get_node_or_null("Jugador"):
		return
	if get_node_or_null("Jugador").global_position == Vector2i(0, 0):
		push_error("Parte 2 no encontrada. Se busca AldairAI.gd?")
