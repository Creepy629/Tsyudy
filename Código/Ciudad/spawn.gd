extends Node3D

@onready var spawnTimer = $spawnTimer

# ──────────────────────────────────────────────────────────────
# Escenas NPC disponibles para este spawner.
# Asigna desde el Inspector las escenas que quieras que aparezcan
# (p. ej. NPC.tscn, NPC_CT.tscn, NPC_T.tscn…).
# Si el array está vacío se usa la escena por defecto.
# ──────────────────────────────────────────────────────────────
@export var npc_scenes: Array[PackedScene] = []

# Escena de respaldo si npc_scenes queda vacío
const DEFAULT_NPC_SCENE: String = "res://Escenas/Nodos/NPC.tscn"

var npcs_spawned: int = 0
const MAX_NPCS: int = 16

func _on_spawn_timer_timeout() -> void:
	if npcs_spawned >= MAX_NPCS:
		spawnTimer.stop()
		return

	# Elegir escena: aleatoria del array o la de respaldo
	var scene: PackedScene
	if npc_scenes.is_empty():
		scene = load(DEFAULT_NPC_SCENE)
	else:
		scene = npc_scenes[randi() % npc_scenes.size()]

	if scene == null:
		push_warning("Spawner %s: escena NPC nula, se omite spawn." % name)
		return

	var spawnNPC: Node = scene.instantiate()
	get_parent().add_child(spawnNPC)
	spawnNPC.global_position = global_position

	npcs_spawned += 1
