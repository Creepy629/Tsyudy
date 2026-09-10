extends Node3D
class_name Tesseract4D

# ── Velocidades de rotación por plano 4D (rad/s) ──────────────────────────
@export var vel_xy: float = 0.0
@export var vel_xz: float = 0.0
@export var vel_xw: float = 0.6
@export var vel_yz: float = 0.0
@export var vel_yw: float = 0.4
@export var vel_zw: float = 0.0
@export var tamano: float = 1.5
@export var dist_4d: float = 3.0
@export var grosor_arista: float = 0.02
@export var color_aristas: Color = Color("#8A5CFF")
@export var brillo_hdr: float = 2.5
@export var pulso_amount: float = 0.25
@export var pulso_speed: float = 2.0

const NEON_SHADER: Shader = preload("res://Shaders/neon.gdshader")
@export var colocar_frente_a_camara: bool = false
@export var distancia_camara: float = 6.0

var _base: Array[Vector4] = []
var _edges: Array[Vector2i] = []
var _ang: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _edge_nodes: Array[MeshInstance3D] = []

func _ready() -> void:
	_build_topologia()
	_build_meshes()
	if colocar_frente_a_camara:
		call_deferred("_colocar_frente_a_camara")

func _build_topologia() -> void:
	for i in 16:
		_base.append(Vector4(
			1.0 if i & 1 else -1.0,
			1.0 if i & 2 else -1.0,
			1.0 if i & 4 else -1.0,
			1.0 if i & 8 else -1.0))
	for i in 16:
		for j in range(i + 1, 16):
			if (i ^ j) > 0 and ((i ^ j) & ((i ^ j) - 1)) == 0:
				_edges.append(Vector2i(i, j))

func _build_meshes() -> void:
	var cyl := CylinderMesh.new()
	cyl.height = 1.0
	cyl.top_radius = grosor_arista
	cyl.bottom_radius = grosor_arista
	cyl.radial_segments = 6
	cyl.rings = 1
	var mat_a := ShaderMaterial.new()
	mat_a.shader = NEON_SHADER
	mat_a.set_shader_parameter("color", color_aristas)
	mat_a.set_shader_parameter("brillo_hdr", brillo_hdr)
	mat_a.set_shader_parameter("pulso_amount", pulso_amount)
	mat_a.set_shader_parameter("pulso_speed", pulso_speed)
	for e in _edges:
		var m := MeshInstance3D.new()
		m.mesh = cyl
		m.material_override = mat_a
		add_child(m)
		_edge_nodes.append(m)

func _colocar_frente_a_camara() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		var found: Array[Node] = get_tree().current_scene.find_children("*", "Camera3D", true, false)
		if not found.is_empty():
			cam = found[0] as Camera3D
	if cam == null:
		return
	global_position = cam.global_position - cam.global_transform.basis.z * distancia_camara

func _process(delta: float) -> void:
	_ang[0] += vel_xy * delta
	_ang[1] += vel_xz * delta
	_ang[2] += vel_xw * delta
	_ang[3] += vel_yz * delta
	_ang[4] += vel_yw * delta
	_ang[5] += vel_zw * delta
	var pts: Array[Vector3] = []
	for v0 in _base:
		var v := v0
		for i in 6:
			if _ang[i] != 0.0:
				v = _rotar_plano(v, i, _ang[i])
		var f := dist_4d / maxf(dist_4d - v.w, 0.35)
		pts.append(Vector3(v.x, v.y, v.z) * (f * tamano))
	for k in _edges.size():
		var a: Vector3 = pts[_edges[k].x]
		var b: Vector3 = pts[_edges[k].y]
		var dir := b - a
		var len := dir.length()
		var node := _edge_nodes[k]
		if len < 0.0001:
			node.visible = false
			continue
		node.visible = true
		node.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir / len)), (a + b) * 0.5)
		node.scale = Vector3(1.0, len, 1.0)

func _rotar_plano(v: Vector4, plano: int, ang: float) -> Vector4:
	var c := cos(ang)
	var s := sin(ang)
	match plano:
		0: return Vector4(v.x * c - v.y * s, v.x * s + v.y * c, v.z, v.w)   # XY
		1: return Vector4(v.x * c - v.z * s, v.y, v.x * s + v.z * c, v.w)   # XZ
		2: return Vector4(v.x * c - v.w * s, v.y, v.z, v.x * s + v.w * c)   # XW
		3: return Vector4(v.x, v.y * c - v.z * s, v.y * s + v.z * c, v.w)   # YZ
		4: return Vector4(v.x, v.y * c - v.w * s, v.z, v.y * s + v.w * c)   # YW
		5: return Vector4(v.x, v.y, v.z * c - v.w * s, v.z * s + v.w * c)   # ZW
	return v
