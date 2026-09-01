extends RigidBody3D
class_name Grenade

enum GrenadeType {HE, FLASHBANG}

var type: GrenadeType = GrenadeType.HE
var fuse_time: float = 1.6
var explosion_radius: float = 5.0
var flash_radius: float = 22.0
var thrower_team: String = ""
var timer: float = 0.0

static func throw_grenade(from_pos: Vector3, throw_dir: Vector3, g_type: GrenadeType, team: String, tree: SceneTree) -> Grenade:
	var g := Grenade.new()
	g.type = g_type
	g.thrower_team = team
	
	# Configurar colisión física
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.15
	col.shape = sphere
	g.add_child(col)
	
	# Forma de la granada
	var mesh_inst := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.15
	sphere_mesh.height = 0.3
	mesh_inst.mesh = sphere_mesh
	
	var mat := StandardMaterial3D.new()
	if g_type == GrenadeType.HE:
		mat.albedo_color = Color(0.2, 0.4, 0.2) # Verde militar HE
	else:
		mat.albedo_color = Color(0.8, 0.8, 0.9) # Gris/blanco Flashbang
	mesh_inst.material_override = mat
	g.add_child(mesh_inst)
	
	tree.current_scene.add_child(g)
	g.global_position = from_pos
	
	# Tiro parabólico Física I Voca 13
	var impulse := (throw_dir.normalized() + Vector3(0, 0.4, 0)).normalized() * 14.0
	g.apply_central_impulse(impulse)
	
	return g

func _physics_process(delta: float) -> void:
	timer += delta
	if timer >= fuse_time:
		detonate()

func detonate() -> void:
	if type == GrenadeType.HE:
		_detonate_he()
	else:
		_detonate_flashbang()
	queue_free()

func _detonate_he() -> void:
	_spawn_visual_blast(Color(1.0, 0.5, 0.1), explosion_radius)
	
	var npcs: Array = get_tree().get_nodes_in_group("CT") + get_tree().get_nodes_in_group("TT")
	for npc in npcs:
		if not npc is Node3D: continue
		var dist := global_position.distance_to((npc as Node3D).global_position)
		if dist <= explosion_radius:
			if npc.has_method("receive_shot"):
				npc.call("receive_shot", self)

func _detonate_flashbang() -> void:
	_spawn_visual_blast(Color(1.0, 1.0, 1.0, 0.9), flash_radius * 0.4)
	
	var npcs: Array = get_tree().get_nodes_in_group("CT") + get_tree().get_nodes_in_group("TT")
	for npc in npcs:
		if not npc is Node3D: continue
		var dist := global_position.distance_to((npc as Node3D).global_position)
		if dist <= flash_radius:
			if npc.has_method("apply_flashbang"):
				npc.call("apply_flashbang", 5.0)

# ── Explosión visual ──────────────────────────────────────────────────────
func _spawn_visual_blast(color: Color, radius: float) -> void:
	var flash_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius * 0.5
	sphere.height = radius
	flash_mesh.mesh = sphere
	
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.6)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mesh.material_override = mat
	
	get_tree().current_scene.add_child(flash_mesh)
	flash_mesh.global_position = global_position
	
	var tw := flash_mesh.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(flash_mesh.queue_free)
