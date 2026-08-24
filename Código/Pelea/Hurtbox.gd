extends Area3D
class_name Hurtbox

@export var show_debug_visuals: bool = true

var owner_fighter: FighterBody
var _active_multi_hitboxes: Array[Hitbox] = []
var _multi_hit_timer: float = 0.0
const MULTI_HIT_INTERVAL := 0.12

var _default_hurtbox_size: Vector3 = Vector3.ZERO
var _default_hurtbox_offset: Vector3 = Vector3.ZERO
var _debug_mesh: MeshInstance3D

func _ready() -> void:
	# Ownership
	var p = get_parent()
	while p != null:
		if p is FighterBody:
			owner_fighter = p
			break
		p = p.get_parent()

	# Capas de colisión
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(4, true) # Existe en capa 4
	set_collision_mask_value(3, true) # Escanea Hitboxes (capa 3)
	set_collision_mask_value(4, true) # Escanea otras Hurtboxes (capa 4) → pushbox

	# Monitorea activamente Y puede ser detectada por otras Hurtboxes
	monitoring = true
	monitorable = true

	# Debug visual (cubo verde)
	_debug_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 2.0, 0.9)
	_debug_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 1.0, 0.0, 0.1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_mesh.material_override = mat
	add_child(_debug_mesh)

	# Cachear el tamaño base del CollisionShape3D
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col and col.shape is BoxShape3D:
		_default_hurtbox_size = (col.shape as BoxShape3D).size
		_default_hurtbox_offset = col.position

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

# Process: multi-hit + pushbox
func _physics_process(delta: float) -> void:
	# Multi-hit
	if not _active_multi_hitboxes.is_empty():
		_multi_hit_timer += delta
		if _multi_hit_timer >= MULTI_HIT_INTERVAL:
			_multi_hit_timer = 0.0
			for hitbox in _active_multi_hitboxes:
				if hitbox.hits_remaining > 0:
					owner_fighter.receive_hit(hitbox)
					hitbox.hits_remaining -= 1

	# Pushbox
	_resolve_pushbox(delta)

func _resolve_pushbox(delta: float) -> void:
	if not owner_fighter: return

	# Solo el de menor instance_id resuelve, para no corregir dos veces
	for area in get_overlapping_areas():
		if not area is Hurtbox: continue
		var other := area as Hurtbox
		if not other.owner_fighter: continue

		# Solo uno de los dos resuelve por frame
		if owner_fighter.get_instance_id() > other.owner_fighter.get_instance_id():
			continue

		# Solo en tierra (no empujamos mientras alguno está en el aire)
		var my_sm := owner_fighter.state_machine
		var other_sm := other.owner_fighter.state_machine
		if my_sm.current_move != FighterStateMachine.MoveState.GROUND: continue
		if other_sm.current_move != FighterStateMachine.MoveState.GROUND: continue

		# Ignorar si están en diferentes "profundidades" (cross-up / sidestep)
		if owner_fighter.fight_plane:
			var cam_dir := owner_fighter.fight_plane.cam_dir
			var depth_diff: float = abs(owner_fighter.global_position.dot(cam_dir) - other.owner_fighter.global_position.dot(cam_dir))
			if depth_diff > 0.4: continue

		# Calcular separación mínima usando el tamaño real de los CollisionShape3D
		var min_sep := _get_half_extent() + other._get_half_extent()

		var fight_dir := owner_fighter.get_fight_axis()
		var d := fight_dir.dot(other.owner_fighter.global_position - owner_fighter.global_position)
		var overlap: float = min_sep - abs(d)

		if overlap <= 0.0: continue

		var push_sign := 1.0 if d >= 0.0 else -1.0
		var speed := owner_fighter.pushbox_correction_speed
		var correction: float = min(overlap * 0.5, speed * delta * 0.5)
		var push: Vector3 = fight_dir * correction * push_sign

		owner_fighter.global_position -= push
		other.owner_fighter.global_position += push

# Devuelve la mitad del ancho del CollisionShape3D en espacio mundo
func _get_half_extent() -> float:
	var col := get_node_or_null("CollisionShape3D")
	if col and col.shape is BoxShape3D:
		var world_scale := global_transform.basis.get_scale()
		return col.shape.size.x * world_scale.x * 0.5
	return 0.25 # fallback

# Redimensionar y reposicionar la Hurtbox (para agacharse / estar en el aire)
func resize_hurtbox(new_size: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col and col.shape is BoxShape3D:
		col.shape.size = new_size
		col.position = offset
	if _debug_mesh and _debug_mesh.mesh is BoxMesh:
		_debug_mesh.mesh.size = new_size
		_debug_mesh.position = offset

func reset_hurtbox_size() -> void:
	if _default_hurtbox_size != Vector3.ZERO:
		resize_hurtbox(_default_hurtbox_size, _default_hurtbox_offset)

func set_debug_visible(v: bool) -> void:
	show_debug_visuals = v
	_apply_debug_visibility()

func _apply_debug_visibility() -> void:
	# Apaga/prende los meshes de debug hijos (las cajas verdes/rojas)
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = show_debug_visuals

# Señales de área
func _on_area_entered(area: Area3D) -> void:
	if not area is Hitbox:
		return # Hurtbox a Hurtbox no genera daño, solo pushbox (en _physics_process)
	var hitbox := area as Hitbox

	# No nos golpeamos a nosotros mismos
	if hitbox.owner_fighter != null and hitbox.owner_fighter == owner_fighter:
		return

	# Multi-hit: registrar
	if hitbox.multi_hits > 1 and not _active_multi_hitboxes.has(hitbox):
		_active_multi_hitboxes.append(hitbox)

	# Primer golpe instantáneo
	if owner_fighter and hitbox.hits_remaining > 0:
		owner_fighter.receive_hit(hitbox)
		hitbox.hits_remaining -= 1

func _on_area_exited(area: Area3D) -> void:
	if area is Hitbox:
		_active_multi_hitboxes.erase(area)
