extends Node3D

@onready var spawnTimer: Timer = $spawnTimer
@export var npc_scenes: Array[PackedScene] = []
@export var team_group: String = "" # "CT" o "TT" — asignar en el Inspector

const DEFAULT_NPC_SCENE: String = "res://Escenas/Nodos/NPC.tscn"

var _spawnedNPCs: Array[Node] = []

func _ready() -> void:
	pass

func _on_spawn_timer_timeout() -> void:
	var count := GameManager.npc_count_per_team
	for i in count:
		_spawnOne()
	spawnTimer.stop()

func _spawnOne() -> Node:
	var scene: PackedScene
	if npc_scenes.is_empty():
		scene = load(DEFAULT_NPC_SCENE)
	else:
		scene = npc_scenes[randi() % npc_scenes.size()]

	if scene == null:
		push_warning("Spawner %s: escena NPC nula." % name)
		return null

	var npc: Node = scene.instantiate()

	if team_group != "":
		npc.add_to_group(team_group)

	var offset := Vector3(randf_range(-1.2, 1.2), 0.1, randf_range(-1.2, 1.2))
	var spawnPos := global_position + offset

	get_parent().add_child(npc)

	if npc is Node3D:
		npc.global_position = spawnPos
		if "spawn_point" in npc:
			npc.set("spawn_point", spawnPos)

	_spawnedNPCs.append(npc)
	return npc

# ── Respawn al inicio de cada nueva ronda ─────────────────────────────
func respawn_all() -> void:
	for npc in _spawnedNPCs:
		if is_instance_valid(npc):
			npc.queue_free()
	_spawnedNPCs.clear()

	var count := GameManager.npc_count_per_team
	for i in count:
		_spawnOne()
