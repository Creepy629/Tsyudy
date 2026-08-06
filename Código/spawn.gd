extends Node3D
@onready var spawnTimer = $spawnTimer
var RNG
var NPC

# Variable para contar los NPCs spawneados
var npcs_spawned = 0
const MAX_NPCS = 4

func _on_spawn_timer_timeout() -> void:
	# Verificar si ya alcanzamos el límite
	if npcs_spawned >= MAX_NPCS:
		spawnTimer.stop()  # Detener el timer
		return
		
	# Siempre spawneamos la escena base, el NPC elegirá su skin solo
	var NPC_scene = preload("res://Escenas/Nodos/NPC.tscn")
	var spawnNPC = NPC_scene.instantiate()
	
	get_parent().add_child(spawnNPC)
	spawnNPC.global_position = global_position
	
	npcs_spawned += 1
