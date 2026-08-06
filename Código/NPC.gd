extends CharacterBody3D

# Esta es la mamada que más me costó, y aún así
# no me gusta cómo quedó

@onready var audio = $Steps
@onready var talk = $Talk # Las voces en loquendo
var nav_map_ready := false
var SPEED = 4.0
var agent: NavigationAgent3D
var destination_timer := 0.0
var destination_interval := 35.0
const ARRIVAL_THRESHOLD := 0.3
enum State { WALKING, WAITING }
var current_state = State.WALKING
var wait_timer := 0.0
const WAIT_TIME := 3.0
var spawned = false

# Pre-carga de recursos
@onready var dialog_scene = preload("res://Escenas/Nodos/DialogBobbl.tscn")
var speech_streams = []
var speech_paths = ["res://Audio/NPCs/BonitoLugar.wav","res://Audio/NPCs/Buenas.wav",
"res://Audio/NPCs/Eh.wav","res://Audio/NPCs/Where.wav",
"res://Audio/NPCs/Bien.wav","res://Audio/NPCs/Caminar.wav"]

@onready var sprite_3d: Sprite3D = $Sprite3D
@onready var sombra: Sprite3D = $Sombra
@onready var collision_node: CollisionShape3D = $CollisionShape3D

# Variables para detección de colisión
var stuck_timer := 0.0
const STUCK_TIME_THRESHOLD := 0.5
var last_position := Vector3.ZERO
var position_check_timer := 0.0
const POSITION_CHECK_INTERVAL := 0.2

func _ready() -> void:
	aplicar_skin_aleatoria()
	# Cargar streams una sola vez
	for path in speech_paths:
		speech_streams.append(load(path))

	# Buscar el sol automáticamente para la sombra
	var sun = get_tree().root.find_child("LaLuh", true, false)
	if sun and sombra:
		sombra.target_node = sun
		
	agent = $NavigationAgent3D # Chinga tu madre
	agent.target_desired_distance = 0.5
	agent.path_desired_distance = 0.5
	agent.avoidance_enabled = false
	call_deferred("setup_navigation")

# A partir de acá me quería cortar la mano
func setup_navigation():
	await get_tree().create_timer(0.5).timeout
	
	var nav_region = get_node("../NavigationRegion3D")
	if nav_region and nav_region.get_navigation_map().is_valid():
		nav_map_ready = true
		
		var nav_map = agent.get_navigation_map()
		var closest_point = NavigationServer3D.map_get_closest_point(nav_map, global_position)
		global_position = closest_point + Vector3(0, 0.05, 0)
		last_position = global_position
		
		await get_tree().process_frame
		set_random_destination()

func set_random_destination() -> void:
	if not nav_map_ready: return
	
	var radius = 50.0
	for attempt in 10:
		var random_pos = global_position + Vector3(
			randf_range(-radius, radius), 0, randf_range(-radius, radius)
		)
		
		var nav_map = agent.get_navigation_map()
		var target = NavigationServer3D.map_get_closest_point(nav_map, random_pos)
		
		if global_position.distance_to(target) > 30.0:
			agent.target_position = target
			current_state = State.WALKING
			spawned = true
			destination_timer = 0.0
			stuck_timer = 0.0
			return

func start_waiting() -> void:
	# Espera antes de generar una nueva ruta
	current_state = State.WAITING
	wait_timer = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	stuck_timer = 0.0

func check_if_stuck(delta: float) -> bool:
	# Check para ver si al hijo de perra se le atravesó alguien o se quedó atorado
	if not spawned or current_state != State.WALKING:
		return false
	
	position_check_timer += delta
	
	if position_check_timer >= POSITION_CHECK_INTERVAL:
		var moved_distance = global_position.distance_to(last_position)
		
		if moved_distance < 0.1 and velocity.length() > 0.5:
			stuck_timer += position_check_timer
		else:
			stuck_timer = 0.0
		
		last_position = global_position
		position_check_timer = 0.0
	
	return stuck_timer >= STUCK_TIME_THRESHOLD

func check_player_collision() -> bool:
	# Check de colisión específica con el jugador
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider and (collider.name == "Jugador" or collider.name == "NPC"):
			var dialog = dialog_scene.instantiate()
			var random_index = randi() % speech_streams.size()
			
			add_child(dialog)
			dialog.global_position = global_position + Vector3(0, 1.5, 0)
			
			talk.stream = speech_streams[random_index]
			talk.play()
			return true
	
	return false

func aplicar_skin_aleatoria():
	var skins = [
		# Aquí puedes añadir cualquier spritesheet que tenga 12 x 8
		# sprites de mismas dimensiones entre sí
		{
			"tex": preload("res://Texturas/Personajes/chrSheet.png"),
			"altura": 2.0,
			"escala": Vector3(4.836, 4.836, 4.836),
			"pos_y": -0.45
		},
		{
			"tex": preload("res://Texturas/Personajes/Starman_sheet.png"),
			"altura": 2.3,
			"escala": Vector3(6.2868, 6.2868, 4.836),
			"pos_y": 0.02
		},
		{
			"tex": preload("res://Texturas/Personajes/Sans_sheet_low.png"),
			"altura": 2.0,
			"escala": Vector3(4.836, 4.836, 4.836),
			"pos_y": -0.131
		}
	]
	
	var skin = skins.pick_random()
	
	# Aplicar textura
	if sprite_3d: sprite_3d.texture = skin.tex
	if sombra: sombra.texture = skin.tex
	
	# Aplicar escala y posición
	if sprite_3d:
		sprite_3d.scale = skin.escala
		sprite_3d.position.y = skin.pos_y
	
	# Aplicar colisión única
	if collision_node:
		collision_node.shape = collision_node.shape.duplicate()
		collision_node.shape.height = skin.altura

func _physics_process(delta: float) -> void:
	if not nav_map_ready: return
	
	# Gravedad
	if not is_on_floor():
		velocity.y += -ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	else:
		velocity.y = 0.0
	
	# Manejar estado de espera
	if current_state == State.WAITING:
		wait_timer += delta
		velocity.x = 0.0
		velocity.z = 0.0
		
		# Detener audio cuando está esperando
		if audio.playing:
			audio.stop()
		
		if wait_timer >= WAIT_TIME:
			set_random_destination()
			destination_interval = randf_range(8.0, 15.0)
		
		move_and_slide()
		return
	
	# Verificar colisión con jugador
	if check_player_collision():
		start_waiting()
		return
	
	# Verificar si está atascado
	if check_if_stuck(delta):
		start_waiting()
		return
	
	# Estado caminando - Timer de destino (timeout)
	destination_timer += delta
	if destination_timer >= destination_interval:
		start_waiting()
		return
	
	# Verificar si llegó al destino
	if agent.is_navigation_finished():
		start_waiting()
		return
	
	# Movimiento hacia el siguiente punto
	var next_pos = agent.get_next_path_position()
	var current_2d = Vector2(global_position.x, global_position.z)
	var target_2d = Vector2(next_pos.x, next_pos.z)
	var distance = current_2d.distance_to(target_2d)
	
	var is_moving = false  # Declarar antes de usarla
	
	if distance > ARRIVAL_THRESHOLD:
		var direction = (target_2d - current_2d).normalized()
		velocity.x = direction.x * SPEED
		velocity.z = direction.y * SPEED
		is_moving = true
		
		# Rotación suave
		if direction.length_squared() > 0.01:
			var target_rotation = atan2(-direction.x, direction.y)
			rotation.y = lerp_angle(rotation.y, target_rotation, delta * 8.0)
	else:
		# Frenar suavemente
		velocity.x = lerp(velocity.x, 0.0, delta * 8.0)
		velocity.z = lerp(velocity.z, 0.0, delta * 8.0)
		is_moving = false
	
	# Control de audio de pasos
	if is_moving and is_on_floor():
		if not audio.playing:
			audio.play()
	else:
		if audio.playing:
			audio.stop()
	
	audio.pitch_scale = 1.5 if SPEED > 6 else 1.05
	
	move_and_slide()
