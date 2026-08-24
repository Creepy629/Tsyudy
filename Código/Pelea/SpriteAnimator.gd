extends Sprite3D
class_name SpriteAnimator

# ─── Métricas: píxeles → metros ──────────────────────────────────────────
@export var pixels_per_meter: float = 170.0 # Densidad por personaje/saga
@export var feet_margin: float = 0.0 # Micro-ajuste vertical
@export var fps: float = 12.0

var animations: Dictionary = {}
var _animations_loaded: bool = false
var _current_sequence: Array = []
var _frame_index: int = 0
var _loop: bool = false
var _path: String = "res://Personajes/"
var _current_anim_name: String = ""
var _frame_timer: float = 0.0
var fighter: FighterBody
var _half_body_local: float = 1.0
var forced_anim: String = ""

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	scale = Vector3.ONE

	var p = get_parent()
	while p != null:
		if p is FighterBody:
			fighter = p
			break
		p = p.get_parent()

	if fighter and fighter.character_name != "":
		_init_character_properties()
	
	# Solo arrancar si las animaciones existen
	if not animations.is_empty():
		play_sequence("idle", true)

func _init_character_properties() -> void:
	if not fighter: return
	var class_name_str = fighter.character_name.replace(" ", "")
	_path = "res://Personajes/" + fighter.character_name + "/" + class_name_str + "Spr/"
	var col := fighter.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col and col.shape is BoxShape3D:
		_half_body_local = (col.shape as BoxShape3D).size.y * 0.5

func _ensure_animations() -> void:
	if _animations_loaded:
		return
	if fighter and fighter.special_moves and fighter.special_moves.has_method("get_universal_animations"):
		_init_character_properties()
		animations = fighter.special_moves.get_universal_animations()
		_animations_loaded = true
		play_sequence(_current_anim_name if _current_anim_name != "" else "idle", _loop)

func _process(delta: float) -> void:
	_ensure_animations()
	_update_state_machine()

	if _current_sequence.is_empty():
		return

	var is_universal_move = (fighter.state_machine.current_action != FighterStateMachine.ActionState.ATTACK)
	if is_universal_move:
		_frame_timer += delta
		var frame_duration = 1.0 / fps
		if _frame_timer >= frame_duration:
			_frame_timer -= frame_duration
			_frame_index += 1
			if _frame_index >= _current_sequence.size():
				if _loop:
					_frame_index = 0
				else:
					_frame_index = _current_sequence.size() - 1
			_load_current_frame()

	_apply_sprite_metrics()

func _load_current_frame() -> void:
	if _current_sequence.is_empty() or _frame_index >= _current_sequence.size():
		return
	var sprite_name = _current_sequence[_frame_index]
	var path: String = _path + sprite_name + ".png"
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		push_error("El sprite \"" + sprite_name + "\" del personaje " + fighter.character_name + " no existe. Borrar referencia o complementar?")
		return
	var tex = load(path)
	if tex:
		self.texture = tex

# ─── Métricas: centrado horizontal + pegado a la base ────────────────────
func _apply_sprite_metrics() -> void:
	if fighter == null or texture == null:
		return

	var parent_scale: float = fighter.scale.y if fighter.scale.y > 0.001 else 1.0
	var px_local: float = 1.0 / (pixels_per_meter * parent_scale)

	pixel_size = px_local
	scale = Vector3.ONE

	# Y: borde inferior del sprite tocando la base del cuerpo
	var half_h_local: float = (float(texture.get_height()) / pixels_per_meter) / (2.0 * parent_scale)
	position.y = - _half_body_local + feet_margin + half_h_local

	# X y Z: siempre centrado. Sin correcciones horizontales.
	position.x = 0.0
	position.z = 0.0

func _update_state_machine() -> void:
	if forced_anim != "":
		if _current_anim_name != forced_anim:
			play_sequence(forced_anim, false)
		return
	
	if not fighter or not fighter.state_machine:
		return

	var sm = fighter.state_machine
	self.flip_h = (fighter.facing_sign < 0)
	self.visible = true
	var target_anim := "idle"
	var should_loop := true

	match sm.current_action:
		sm.ActionState.IDLE:
			match sm.current_move:
				sm.MoveState.GROUND:
					var fight_axis = fighter.get_fight_axis()
					var local_vel = fighter.velocity.dot(fight_axis) * fighter.facing_sign
					if fighter.last_input_state.get("crouch", false):
						target_anim = "crouch"
						should_loop = false
					elif abs(local_vel) > 0.1:
						if local_vel > 0:
							target_anim = "walk_forward"
						else:
							target_anim = "walk_backward"
					else:
						target_anim = "idle"
				sm.MoveState.AIR:
					should_loop = false
					if fighter.velocity.y > 0:
						target_anim = "jump_up"
					else:
						target_anim = "jump_fall"
				sm.MoveState.DASH:
					target_anim = "dash"
					should_loop = true
				sm.MoveState.RUN:
					target_anim = "run"
					should_loop = true
				sm.MoveState.BACKDASH:
					target_anim = "walk_backward"
				sm.MoveState.SIDESTEP:
					target_anim = "walk_forward"
		sm.ActionState.ATTACK:
			var timeline = sm._attack_timeline
			var idx = sm._timeline_idx
			if timeline.size() > 0 and idx >= 0 and idx < timeline.size():
				var step = timeline[idx]
				if step.has("anim"):
					target_anim = step["anim"]
				else:
					target_anim = _current_anim_name
				if step.get("hide", false):
					self.visible = false
			should_loop = false
		sm.ActionState.HIT:
			if sm.is_blocking:
				target_anim = "guard_crouch" if fighter.is_crouch_guarding else "guard_stand"
			elif sm.is_knocked_down:
				target_anim = "knockdown"
			elif sm.current_move == sm.MoveState.AIR:
				target_anim = "hit_air"
			else:
				target_anim = "hit_ground"
			should_loop = false

	if target_anim != _current_anim_name and target_anim != "":
		play_sequence(target_anim, should_loop)

func play_sequence(anim_name: String, loop: bool = false) -> void:
	_current_anim_name = anim_name
	_loop = loop
	_frame_index = 0
	_frame_timer = 0.0
	if animations.has(anim_name):
		_current_sequence = animations[anim_name]
	else:
		_current_sequence = [anim_name]
	_load_current_frame()
