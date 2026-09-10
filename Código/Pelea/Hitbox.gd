extends Area3D
class_name Hitbox

@export var show_debug_visuals: bool = true

var damage: int = 10
var knockback: float = 5.0
var hitstun_frames: int = 15
var hitstop_duration: float = 0.15
var launch_velocity: float = 0.0
var launch_angle_degrees: float = 90.0
var multi_hits: int = 1
var attach: bool = false
var is_low: bool = false

var owner_fighter: FighterBody
var hits_remaining: int = 1
var is_enabled: bool = false

var default_position: Vector3 = Vector3.ZERO

var _default_hitbox_size: Vector3 = Vector3(0.5, 0.5, 0.5)
var _default_hitbox_offset: Vector3 = Vector3.ZERO
var _debug_mesh: MeshInstance3D
var _projectile_sprite: Sprite3D


func _ready() -> void:
	default_position = position
	_default_hitbox_offset = position

	# Ownership
	var p: Node = get_parent()
	while p != null:
		if p is FighterBody:
			owner_fighter = p as FighterBody
			break
		p = p.get_parent()

	# Capas de colisión
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true) # Existe en capa 3; la Hurtbox la busca aquí.

	# La Hurtbox monitorea; la Hitbox solo es monitorable cuando está activa.
	monitoring = false
	monitorable = false

	# Duplicar shape para evitar SubResources compartidos entre personajes/instancias.
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null:
		col.position = Vector3.ZERO
		if col.shape is BoxShape3D:
			col.shape = (col.shape as BoxShape3D).duplicate()
			_default_hitbox_size = (col.shape as BoxShape3D).size

	# Debug visual rojo
	_debug_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = _default_hitbox_size
	_debug_mesh.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 0.0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_mesh.material_override = mat
	add_child(_debug_mesh)

	# Sprite opcional para proyectiles.
	# No usamos billboard automático para evitar rarezas/crashes de Godot 4.7.
	_projectile_sprite = Sprite3D.new()
	_projectile_sprite.visible = false
	add_child(_projectile_sprite)

	visible = false
	_apply_debug_visibility()


func enable_hitbox() -> void:
	hits_remaining = multi_hits
	is_enabled = true
	set_deferred("monitorable", true)
	visible = true
	_apply_debug_visibility()


func disable_hitbox() -> void:
	is_enabled = false
	set_deferred("monitorable", false)
	visible = false
	clear_projectile_sprite()
	reset_hitbox()
	_apply_debug_visibility()


func resize_hitbox(new_size: Vector3) -> void:
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null and col.shape is BoxShape3D:
		(col.shape as BoxShape3D).size = new_size

	if _debug_mesh != null and _debug_mesh.mesh is BoxMesh:
		(_debug_mesh.mesh as BoxMesh).size = new_size


func reposition_hitbox(offset: Vector3) -> void:
	position = offset


func set_hitbox_shape(new_size: Vector3, offset: Vector3) -> void:
	resize_hitbox(new_size)
	reposition_hitbox(offset)


func apply_timeline_step(step: Dictionary) -> void:
	# Si estamos en startup/recovery partimos desde la base;
	# si estamos en un frame activo, conservamos la forma anterior salvo que el step la sobreescriba.
	var target_size: Vector3 = get_current_hitbox_size() if is_enabled else _default_hitbox_size
	var target_offset: Vector3 = position if is_enabled else _default_hitbox_offset

	if step.has("size") and step["size"] is Vector3:
		target_size = step["size"] as Vector3

	if step.has("offset") and step["offset"] is Vector3:
		target_offset = step["offset"] as Vector3

	set_hitbox_shape(target_size, target_offset)


func reset_hitbox() -> void:
	set_hitbox_shape(_default_hitbox_size, _default_hitbox_offset)


func get_default_hitbox_size() -> Vector3:
	return _default_hitbox_size


func get_default_hitbox_offset() -> Vector3:
	return _default_hitbox_offset


func get_current_hitbox_size() -> Vector3:
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null and col.shape is BoxShape3D:
		return (col.shape as BoxShape3D).size
	return _default_hitbox_size


func set_projectile_sprite(sprite_name: String, facing_sign: float = 1.0) -> void:
	if sprite_name.is_empty():
		clear_projectile_sprite()
		return

	if _projectile_sprite == null:
		return

	var full_path: String = sprite_name
	if not full_path.begins_with("res://"):
		var char_name: String = "Kung Lao"
		if owner_fighter != null and owner_fighter.character_name != "":
			char_name = owner_fighter.character_name

		var class_name_str: String = char_name.replace(" ", "")
		full_path = "res://Personajes/" + char_name + "/" + class_name_str + "Spr/" + sprite_name + ".png"

	if ResourceLoader.exists(full_path):
		var tex_res: Resource = ResourceLoader.load(full_path)
		if tex_res is Texture2D:
			_projectile_sprite.texture = tex_res as Texture2D
			_projectile_sprite.flip_h = facing_sign < 0.0
			_projectile_sprite.visible = true
			return

	clear_projectile_sprite()


func clear_projectile_sprite() -> void:
	if _projectile_sprite == null:
		return

	_projectile_sprite.visible = false
	_projectile_sprite.texture = null


func set_debug_visible(v: bool) -> void:
	show_debug_visuals = v
	_apply_debug_visibility()


func _apply_debug_visibility() -> void:
	if _debug_mesh != null:
		_debug_mesh.visible = show_debug_visuals and is_enabled
