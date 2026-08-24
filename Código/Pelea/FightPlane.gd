extends Node3D
class_name FightPlane

# Este es el pilar más importante en M.U.K.K.E.N.
# para que los personajes no se paseen libremente por todo el escenario.
var fight_dir: Vector3:
	get: return global_basis.x.normalized()

var cam_dir: Vector3:
	get: return global_basis.z.normalized()

func apply_sidestep(angle_rad: float) -> void:
	rotate_y(angle_rad)

func get_projected_position(world_pos: Vector3) -> Vector3:
	var safe_dir: Vector3 = fight_dir
	safe_dir.y = 0.0
	
	if safe_dir.length_squared() > 0.0001:
		safe_dir = safe_dir.normalized()
	else:
		safe_dir = Vector3.RIGHT
	
	var to_pos := world_pos - global_position
	var projected := to_pos.dot(safe_dir) * safe_dir
	
	return global_position + projected + Vector3.UP * world_pos.y
