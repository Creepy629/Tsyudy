extends Area3D
class_name Hitbox

var damage: int = 10
var knockback: float = 5.0
var hitstun_frames: int = 15
var hitstop_duration: float = 0.15
var launch_velocity: float = 0.0
var launch_angle_degrees: float = 90.0
var multi_hits: int = 1
var attach: bool = false
var is_low: bool = false
var show_debug_visuals: bool = true

var owner_fighter: FighterBody
var hits_remaining: int = 1
var default_position: Vector3

var _debug_mesh: MeshInstance3D
var _projectile_sprite: Sprite3D

func _ready() -> void:
	default_position = position
	
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
	set_collision_layer_value(3, true) # Existe en capa 3 (la Hurtbox la busca aquí)
	
	# Roles de detección
	monitoring = false # Empieza desactivada; se activa con enable_hitbox()
	monitorable = true # Debe poder ser ENCONTRADA por la Hurtbox
	
	# Debug visual (cubo rojo)
	_debug_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	_debug_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 0.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_mesh.material_override = mat
	add_child(_debug_mesh)
	
	# Sprite3D para proyectiles
	_projectile_sprite = Sprite3D.new()
	_projectile_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_projectile_sprite.scale = Vector3(2.5, 2.5, 2.5) # Escalado proporcional para hacer visible el sprite del proyectil
	_projectile_sprite.visible = false
	add_child(_projectile_sprite)
	
	visible = false # Oculta hasta que se active

# Control de activación
func enable_hitbox() -> void:
	hits_remaining = multi_hits
	set_deferred("monitorable", true)
	visible = true

func disable_hitbox() -> void:
	set_deferred("monitorable", false)
	visible = false
	clear_projectile_sprite()
	reset_hitbox()

# Manejo de Sprite3D para proyectiles
func set_projectile_sprite(sprite_name: String, facing_sign: float = 1.0) -> void:
	if sprite_name.is_empty():
		clear_projectile_sprite()
		return
	
	var full_path := sprite_name
	if not full_path.begins_with("res://"):
		var char_name := owner_fighter.character_name if owner_fighter else "Kung Lao"
		var class_name_str := char_name.replace(" ", "")
		full_path = "res://Personajes/" + char_name + "/" + class_name_str + "Spr/" + sprite_name + ".png"
	
	if FileAccess.file_exists(full_path) or ResourceLoader.exists(full_path):
		var tex = load(full_path)
		if tex:
			_projectile_sprite.texture = tex
			_projectile_sprite.flip_h = (facing_sign < 0)
			_projectile_sprite.visible = true
			return
			
	clear_projectile_sprite()

func clear_projectile_sprite() -> void:
	if _projectile_sprite:
		_projectile_sprite.visible = false
		_projectile_sprite.texture = null

func resize_hitbox(new_size: Vector3) -> void:
	var col := get_node_or_null("CollisionShape3D")
	if col and col.shape is BoxShape3D:
		col.shape.size = new_size
	if _debug_mesh and _debug_mesh.mesh is BoxMesh:
		_debug_mesh.mesh.size = new_size

func reposition_hitbox(offset: Vector3) -> void:
	position = offset

func reset_hitbox() -> void:
	position = default_position

func set_debug_visible(v: bool) -> void:
	show_debug_visuals = v
	_apply_debug_visibility()

func _apply_debug_visibility() -> void:
	# Apaga/prende los meshes de debug hijos (las cajas verdes/rojas)
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = show_debug_visuals
