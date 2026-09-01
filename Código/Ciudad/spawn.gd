extends Node3D

@onready var spawn_timer: Timer = $spawnTimer
@export  var npc_scenes:  Array[PackedScene] = []
@export  var team_group:  String = ""   # "CT" o "TT" — asignar en el Inspector

const DEFAULT_NPC_SCENE: String = "res://Escenas/Nodos/NPC.tscn"

# Lista de NPCs que este spawner ha generado en la ronda actual
var _spawned_npcs: Array[Node] = []

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# El timer original sigue funcionando para spawn periódico tipo CS
	# (el tiempo de warmup antes de que empiecen a aparecer)
	# Cuando el timer llega a 0 llama a _on_spawn_timer_timeout.
	pass

func _on_spawn_timer_timeout() -> void:
	var count := GameManager.npc_count_per_team
	for i in count:
		_spawn_one()
	spawn_timer.stop()   # todos salen de golpe al inicio de ronda, luego se para

func _spawn_one() -> Node:
	var scene: PackedScene
	if npc_scenes.is_empty():
		scene = load(DEFAULT_NPC_SCENE)
	else:
		scene = npc_scenes[randi() % npc_scenes.size()]

	if scene == null:
		push_warning("Spawner %s: escena NPC nula." % name)
		return null

	var npc: Node = scene.instantiate()

	# Añadir al grupo del equipo si está configurado
	if team_group != "":
		npc.add_to_group(team_group)

	# Asignar dispersión aleatoria suave
	var offset := Vector3(randf_range(-1.2, 1.2), 0.1, randf_range(-1.2, 1.2))
	var spawn_pos := global_position + offset

	# Añadir al árbol primero para evitar la advertencia "!is_inside_tree()"
	get_parent().add_child(npc)

	if npc is Node3D:
		npc.global_position = spawn_pos
		if "spawn_point" in npc:
			npc.set("spawn_point", spawn_pos)

	_spawned_npcs.append(npc)
	return npc

# ── Respawn al inicio de cada nueva ronda (llamado por BombSite) ──────────
func respawn_all() -> void:
	# Limpiar instancias previas muertas
	for npc in _spawned_npcs:
		if is_instance_valid(npc):
			npc.queue_free()
	_spawned_npcs.clear()

	# Generar cantidad actualizada (puede haber cambiado desde el celular)
	var count := GameManager.npc_count_per_team
	for i in count:
		_spawn_one()
