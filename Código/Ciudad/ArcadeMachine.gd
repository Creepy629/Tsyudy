extends Node3D
class_name ArcadeMachine

# Honestamente me dió flojera armar una máquina arcade
# de verdad. Un rectángulo moradito y una imágen en
# dónde pulsar E basta.

@export var select_scene_path: String = "res://Escenas/Pelea/CharacterSelect.tscn"
@export var interact_action: String = "Interactuar"
@export var prompt_distance: float = 2.5
@export var marquee_texture_path: String = "res://Texturas/Pelea/de_dust2.png" # Iba a poner un fondo del Dust II.
var _player: Node3D = null
var _prompt: Label3D = null

# ─── Init ───────────────────────────────────────────────────────────────────
# Define la forma, color, imágen de "pantalla" y letrero que te dice
# que hacer. Todo esto en orden.
func _ready() -> void:
	var cabinet := CSGBox3D.new()
	cabinet.size = Vector3(0.7, 1.4, 0.6)
	cabinet.position = Vector3(0.0, 0.7, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.05, 0.12)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.1, 0.6)
	mat.emission_energy = 1.5
	cabinet.material = mat
	add_child(cabinet)
	var marquee := Sprite3D.new()
	marquee.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	marquee.position = Vector3(0.0, 1.75, 0.0)
	marquee.pixel_size = 0.004
	if ResourceLoader.exists(marquee_texture_path):
		var res: Resource = load(marquee_texture_path)
		if res is Texture2D:
			marquee.texture = res
	add_child(marquee)
	_prompt = Label3D.new()
	_prompt.text = "PULSA E PARA JUGAR"
	_prompt.pixel_size = 0.005
	_prompt.position = Vector3(0.0, 2.1, 0.0)
	_prompt.modulate = Color(1.0, 0.8, 0.2)
	_prompt.visible = false
	add_child(_prompt)

# ─── Lógica ─────────────────────────────────────────────────────────────────
# Busca al jugador, ve si está cerca y si pulsa E, lo manda a la escena
# asignada (select_scene_path). 
func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		var scene_root: Node = get_tree().current_scene
		if scene_root != null:
			_player = scene_root.get_node_or_null("Jugador")
	if _player == null:
		return
	var near: bool = global_position.distance_to(_player.global_position) <= prompt_distance
	if _prompt != null:
		_prompt.visible = near
	if near and Input.is_action_just_pressed(interact_action):
		CityReturnRef.scene_path = get_tree().current_scene.scene_file_path
		CityReturnRef.position = _player.global_position
		CityReturnRef.active = true
		get_tree().change_scene_to_file(select_scene_path)
