extends Sprite3D
class_name CharacterPreview

@export var character_name: String = ""
@export var pixels_per_meter: float = 170.0
@export var preview_scale: float = 1.0
@export_range(0.1, 16.0, 0.1) var size_multiplier: float = 2.0
@export var fps: float = 12.0

var _sequence: Array = []
var _frame_index: int = 0
var _timer: float = 0.0
var _path: String = ""
var _debug_printed: bool = false

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	set_character(character_name)

func set_character(char_name: String) -> void:
	character_name = char_name
	_frame_index = 0
	_timer = 0.0
	_sequence = []
	_debug_printed = false

	if character_name == "":
		texture = null
		return

	var class_str: String = character_name.replace(" ", "")
	_path = "res://Personajes/" + character_name + "/" + class_str + "Spr/"
	var sm_path: String = "res://Personajes/" + character_name + "/" + class_str + "SpecialMoves.gd"

	if FileAccess.file_exists(sm_path) or ResourceLoader.exists(sm_path):
		var sm_script: Resource = load(sm_path)
		if sm_script is GDScript:
			var sm: RefCounted = sm_script.new()
			if sm != null and sm.has_method("get_universal_animations"):
				var universal: Dictionary = sm.get_universal_animations()
				_sequence = universal.get("idle", [])

	if _sequence.is_empty():
		_sequence = ["A_1", "A1"]

	_load_frame()
	_apply_metrics()

func _process(delta: float) -> void:
	if _sequence.is_empty():
		return

	_timer += delta
	if _timer >= 1.0 / fps:
		_timer -= 1.0 / fps
		_frame_index = (_frame_index + 1) % _sequence.size()
		_load_frame()
		_apply_metrics()

func _load_frame() -> void:
	var path: String = _path + str(_sequence[_frame_index]) + ".png"
	if FileAccess.file_exists(path) or ResourceLoader.exists(path):
		var tex: Resource = load(path)
		if tex is Texture2D:
			texture = tex

func _apply_metrics() -> void:
	if texture == null:
		return

	var effective_scale: float = preview_scale * size_multiplier
	pixel_size = 1.0 / pixels_per_meter
	scale = Vector3.ONE * effective_scale
	position.y = ((float(texture.get_height()) / pixels_per_meter) / 2.0) * effective_scale

	if not _debug_printed:
		_debug_printed = true
		print("[CharacterPreview] %s | ppm=%f preview_scale=%f size_multiplier=%f effective=%f h_px=%d" % [
			character_name,
			pixels_per_meter,
			preview_scale,
			size_multiplier,
			effective_scale,
			texture.get_height()
		])
