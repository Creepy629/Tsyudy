extends Area3D
class_name BombSite

enum BombState {UNPLANTED, PLANTING, PLANTED, DEFUSING, EXPLODED, DEFUSED, TIMEOUT}

@export var site_name: String = "Site A"
@export var plant_time: float = 5.0
@export var defuse_time: float = 8.0
@export var explode_time: float = 15.0
@export var round_duration: float = 120.0 # 2 minutos de gritos.
@export var site_radius: float = 4.0
@export var transparent_color: Color = Color(1.0, 0.8, 0.1, 0.3)

# ── Variables Estáticas Globales ───────────────────────────────────────────
static var active_planted_site: BombSite = null
static var round_ended: bool = false
static var round_reset_timer: float = 0.0
static var round_time_remaining: float = 120.0
static var dropped_c4_position: Vector3 = Vector3.INF
static var dropped_c4_node: Node3D = null
const ROUND_RESET_DELAY: float = 10.0

# ── Diálogo de NPC's ───────────────────────────────────────────────────────
static var KILL_QUOTES: Array[String] = [
	"lol", "toma mango", "gg", "malisimo", "too much for zblock",
	"NO SCOPE", "wp", "a casa", "YIPPIE", "y la bomba"
]

static var DEATH_QUOTES: Array[String] = [
	"lag", "que fue", "tremendo aimbot", "???", "aimbot",
	"AAAAAAA", "wtf", "admin he doing it sideways", "ATRAS MRD"
]

# ── Variables ───────────────────────────────────────────────────────────────
var current_state: BombState = BombState.UNPLANTED
var state_timer: float = 0.0
var bomb_timer: float = 0.0
var planter_npc: Node3D = null
var defuser_npc: Node3D = null
var bomb_mesh: MeshInstance3D = null
var status_label: Label3D = null

# ── Init ─────────────────────────────────────────────────────────────────
# Atoré mitad de la lógica del modo de juego en todo este script.
func _ready() -> void:
	add_to_group("BombSite")
	round_time_remaining = round_duration
	_setup_transparent_visual()
	_setup_status_label()
	_setup_bomb_visual()

# ── Visuales debug ────────────────────────────────────────────────────────
# Zona de plantado y desarmado.
func _setup_transparent_visual() -> void:
	var mesh_node: MeshInstance3D = null
	for child in get_children():
		if child is MeshInstance3D:
			mesh_node = child
			break
	
	if mesh_node == null:
		mesh_node = MeshInstance3D.new()
		var box := BoxMesh.new()
		var col := find_child("*Collision*", true, false) as CollisionShape3D
		if col != null and col.shape is BoxShape3D:
			box.size = (col.shape as BoxShape3D).size
		else:
			box.size = Vector3(site_radius * 2.0, 1.5, site_radius * 2.0)
		mesh_node.mesh = box
		add_child(mesh_node)

	if mesh_node.mesh != null:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = transparent_color
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_node.material_override = mat

	mesh_node.visible = false

# Mini-HUD de estado.
func _setup_status_label() -> void:
	status_label = Label3D.new()
	status_label.text = "[ %s ]" % site_name
	status_label.pixel_size = 0.008
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.position = Vector3(0, 2.2, 0)
	status_label.modulate = Color(1, 1, 0)
	status_label.visible = false
	add_child(status_label)

# La bomba física 3D.
func _setup_bomb_visual() -> void:
	bomb_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.2, 0.25)
	bomb_mesh.mesh = box
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.15)
	bomb_mesh.material_override = mat
	bomb_mesh.position = Vector3(0, 0.1, 0)
	bomb_mesh.visible = false
	add_child(bomb_mesh)

# ── Lógica principal de la bomba. ──────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	# Temporizador de ronda y victoria Anti-Terrorista por timeout.
	if not round_ended and active_planted_site == null:
		if self == get_tree().get_first_node_in_group("BombSite"):
			round_time_remaining -= delta
			if round_time_remaining <= 0.0:
				current_state = BombState.TIMEOUT
				CSHUD.play_bomb_cue("ctwin")
				start_round_end("GANAN LOS ANTI-TERRORISTAS (TIEMPO AGOTADO)")

	# Chequeo de victoria por eliminación de bando contrario (optimizado a 4 veces por segundo)
	if not round_ended:
		if self == get_tree().get_first_node_in_group("BombSite"):
			state_timer += delta
			if state_timer >= 0.25:
				_check_team_elimination_win()

	# Si la ronda terminó, manejar el conteo de 10s para reiniciar
	if round_ended:
		if self == get_tree().get_first_node_in_group("BombSite"):
			round_reset_timer -= delta
			if round_reset_timer <= 0.0:
				trigger_round_reset()

	# Actualizar HUD (reloj de ronda y estado de los sitios)
	if self == get_tree().get_first_node_in_group("BombSite"):
		_update_hud_display()

	# State Machine.
	match current_state:
		BombState.UNPLANTED:
			pass
			
		BombState.PLANTING:
			if planter_npc == null or not is_instance_valid(planter_npc) or not is_npc_in_site(planter_npc) or _is_npc_dead(planter_npc):
				current_state = BombState.UNPLANTED
				state_timer = 0.0
				return
			
			state_timer += delta
			if state_timer >= plant_time:
				current_state = BombState.PLANTED
				CSHUD.play_bomb_cue("bombpl")
				active_planted_site = self
				bomb_timer = explode_time
				state_timer = 0.0
				bomb_mesh.visible = true
				
		BombState.PLANTED:
			bomb_timer -= delta
			if bomb_timer <= 0.0:
				current_state = BombState.EXPLODED
				CSHUD.play_bomb_cue("terwin")
				start_round_end("LA BOMBA EXPLOTÓ EN %s. GANAN LOS TERRORISTAS." % site_name)
				
		BombState.DEFUSING:
			bomb_timer -= delta
			if defuser_npc == null or not is_instance_valid(defuser_npc) or not is_npc_in_site(defuser_npc) or _is_npc_dead(defuser_npc):
				current_state = BombState.PLANTED
				state_timer = 0.0
				return
				
			state_timer += delta
			if state_timer >= defuse_time:
				current_state = BombState.DEFUSED
				bomb_mesh.visible = false
				CSHUD.play_bomb_cue("bombdef")
				start_round_end("¡BOMBA DESACTIVADA EN %s! GANAN LOS ANTI-TERRORISTAS." % site_name)
			elif bomb_timer <= 0.0:
				current_state = BombState.EXPLODED
				CSHUD.play_bomb_cue("terwin")
				start_round_end("LA BOMBA EXPLOTÓ EN %s. GANAN LOS TERRORISTAS." % site_name)

# ── HUD ──────────────────────────────────────────────────────────────────────
# Información visual para CSHUD.gd. Temporizador y estados de los sitios.
func _update_hud_display() -> void:
	var mins := int(maxf(0.0, round_time_remaining)) / 60
	var secs := int(maxf(0.0, round_time_remaining)) % 60
	var time_str := "%02d:%02d" % [mins, secs]
	
	if active_planted_site != null:
		time_str = "💣 %.1fs" % maxf(0.0, active_planted_site.bomb_timer)
	elif round_ended:
		time_str = "REINICIANDO... (%.1fs)" % maxf(0.0, round_reset_timer)
		
	var site_a: BombSite = null
	var site_b: BombSite = null
	var sites: Array = get_tree().get_nodes_in_group("BombSite")
	for s in sites:
		if s is BombSite:
			if s.site_name.to_upper().contains("A"):
				site_a = s
			elif s.site_name.to_upper().contains("B"):
				site_b = s
				
	var status_a := "LIBRE"
	var state_val_a := 0
	if site_a != null:
		state_val_a = site_a.current_state
		status_a = _get_status_string(site_a.current_state)
		
	var status_b := "LIBRE"
	var state_val_b := 0
	if site_b != null:
		state_val_b = site_b.current_state
		status_b = _get_status_string(site_b.current_state)
		
	CSHUD.update_match_status(time_str, status_a, status_b, state_val_a, state_val_b)

# ── HUDStatus ────────────────────────────────────────────────────────────────
# Compilación de los estados posibles a String para CSHUD.
func _get_status_string(state: int) -> String:
	match state:
		0: return "LIBRE"
		1: return "PLANTANDO..."
		2: return "PLANTADA 💣"
		3: return "DESACTIVANDO..."
		4: return "DETONADA"
		5: return "DESACTIVADA"
		6: return "TIEMPO"
	return "LIBRE"

# ── Check de muerte ────────────────────────────────────────────────────────────────
static func _is_npc_dead(npc: Node3D) -> bool:
	if npc == null or not is_instance_valid(npc): return true
	if not "current_state" in npc: return false
	var cs: int = npc.current_state
	# NPCTT: State.DEAD_FROZEN == 5, NPCCT: State.DEAD_FROZEN == 4
	# Usar has_method("set_c4_carrier") para distinguir TT de CT
	if npc.has_method("set_c4_carrier"):
		return cs == 5 # NPCTT DEAD_FROZEN
	else:
		return cs == 4 # NPCCT DEAD_FROZEN

# ── Check de proximidad ────────────────────────────────────────────────────────────────
# Verifica si un NPC está dentro del radio del sitio.	
func is_npc_in_site(npc: Node3D) -> bool:
	if npc == null: return false
	var dist_xz := Vector2(npc.global_position.x - global_position.x, npc.global_position.z - global_position.z).length()
	return dist_xz <= site_radius

# ── Plantación del C4 ────────────────────────────────────────────────────────────────
func start_planting(tt: Node3D) -> bool:
	if current_state == BombState.UNPLANTED and active_planted_site == null and not round_ended:
		planter_npc = tt
		current_state = BombState.PLANTING
		state_timer = 0.0
		return true
	return false

# ── Desactivación del C4 ──────────────────────────────────────────────────────────
func start_defusing(ct: Node3D) -> bool:
	if current_state == BombState.PLANTED and not round_ended:
		defuser_npc = ct
		current_state = BombState.DEFUSING
		state_timer = 0.0
		return true
	return false

# ── Verificación de plantación ───────────────────────────────────────────────────
func is_planted() -> bool:
	return current_state == BombState.PLANTED or current_state == BombState.DEFUSING

# ── Fin de ronda ────────────────────────────────────────────────────────────────
func start_round_end(_msg: String = "") -> void:
	if not round_ended:
		round_ended = true
		round_reset_timer = ROUND_RESET_DELAY

# ── Killfeed y Chat CS ─────────────────────────────────────────────────────
static func log_kill(killer: Node3D, victim: Node3D, weapon_emoji: String = "🔫") -> void:
	var killer_name: String = str(killer.get("gametag")) if (killer != null and "gametag" in killer and killer.get("gametag") != "") else (str(killer.name) if killer != null else "Desconocido")
	var victim_name: String = str(victim.get("gametag")) if (victim != null and "gametag" in victim and victim.get("gametag") != "") else (str(victim.name) if victim != null else "Desconocido")
	var killer_is_ct: bool = (killer != null and killer.is_in_group("CT"))
	var victim_is_ct: bool = (victim != null and victim.is_in_group("CT"))
	
	# Killfeed
	CSHUD.post_kill(killer_name, victim_name, weapon_emoji, killer_is_ct)
	
	# Mensajes del chat
	if randf() < 0.65:
		var quote_k: String = KILL_QUOTES[randi() % KILL_QUOTES.size()]
		CSHUD.post_chat(killer_name, quote_k, killer_is_ct)
	if randf() < 0.45:
		var quote_v: String = DEATH_QUOTES[randi() % DEATH_QUOTES.size()]
		CSHUD.post_chat(victim_name, quote_v, victim_is_ct)

	var first_site = killer.get_tree().get_first_node_in_group("BombSite")
	if first_site and first_site.has_method("_check_team_elimination_win"):
		first_site._check_team_elimination_win()

func _check_team_elimination_win() -> void:
	var cts: Array = get_tree().get_nodes_in_group("CT")
	var tts: Array = get_tree().get_nodes_in_group("TT")
	
	var alive_cts := 0
	for ct in cts:
		if not _is_npc_dead(ct):
			alive_cts += 1
			
	var alive_tts := 0
	for tt in tts:
		if not _is_npc_dead(tt):
			alive_tts += 1

	if cts.size() > 0 and alive_cts == 0:
		CSHUD.play_bomb_cue("terwin")
		start_round_end("GANAN LOS TERRORISTAS (TODOS LOS CT FUERON ELIMINADOS)")
	elif tts.size() > 0 and alive_tts == 0 and active_planted_site == null:
		CSHUD.play_bomb_cue("ctwin")
		start_round_end("GANAN LOS ANTI-TERRORISTAS (TODOS LOS TT FUERON ELIMINADOS)")

# ── Reseteo de Ronda ───────────────────────────────────────────────────────
func reset_site() -> void:
	current_state = BombState.UNPLANTED
	state_timer = 0.0
	bomb_timer = 0.0
	planter_npc = null
	defuser_npc = null
	if bomb_mesh != null:
		bomb_mesh.visible = false

func trigger_round_reset() -> void:
	round_ended = false
	active_planted_site = null
	round_time_remaining = round_duration
	remove_dropped_c4()
	
	# Resetear todos los sites
	var sites: Array = get_tree().get_nodes_in_group("BombSite")
	for s in sites:
		if s is BombSite:
			(s as BombSite).reset_site()

	# Llamar a respawn_all en todos los spawners si existen
	var map_node := get_tree().current_scene.find_child("Mapa", true, false)
	if map_node:
		var ct_spawner = map_node.find_child("CT", true, false)
		if ct_spawner and ct_spawner.has_method("respawn_all"):
			ct_spawner.call("respawn_all")
		var tt_spawner = map_node.find_child("TT", true, false)
		if tt_spawner and tt_spawner.has_method("respawn_all"):
			tt_spawner.call("respawn_all")
			
	# Resetear o reposicionar CTs existentes si no usan spawner dinámico
	var cts: Array = get_tree().get_nodes_in_group("CT")
	for ct in cts:
		if ct.has_method("respawn_to_base"):
			ct.call("respawn_to_base")
			
	# Resetear o reposicionar TTs existentes y asignar C4 a cada uno
	var tts: Array = get_tree().get_nodes_in_group("TT")
	for tt in tts:
		if tt.has_method("respawn_to_base"):
			tt.call("respawn_to_base")
		if "has_c4" in tt:
			tt.has_c4 = true

# ── C4 Caído ──────────────────────────────────────────────────────────────
static func drop_c4(pos: Vector3, tree: SceneTree) -> void:
	dropped_c4_position = pos
	
	if dropped_c4_node == null or not is_instance_valid(dropped_c4_node):
		dropped_c4_node = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.4, 0.25, 0.3)
		(dropped_c4_node as MeshInstance3D).mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.3, 0.1)
		(dropped_c4_node as MeshInstance3D).material_override = mat
		tree.current_scene.add_child(dropped_c4_node)
		
	dropped_c4_node.global_position = pos + Vector3(0, 0.15, 0)
	dropped_c4_node.visible = true

static func remove_dropped_c4() -> void:
	dropped_c4_position = Vector3.INF
	if dropped_c4_node != null and is_instance_valid(dropped_c4_node):
		dropped_c4_node.visible = false
