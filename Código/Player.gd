extends CharacterBody3D

# Técnicamente es el mismo código que el de los NPCs
@onready var cam: Camera3D = $Pivote/Camera3D
@onready var audio = $AudioStreamPlayer3D

var SPEED = 5.0
const JUMP_VELOCITY = 5.5

func _physics_process(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Salto
	if Input.is_action_just_pressed("Salto") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Velocidad al correr
	if Input.is_action_pressed("Correr"):
		SPEED = 8.0
	else:
		SPEED = 5.0
	
	# Salir del juego
	if Input.is_action_just_pressed("Salir"):
		get_tree().quit()
	
	# Movimiento basado en la cámara
	# Si ves que está extraño el orden de las direcciones, no te
	# imaginas cómo están en la config del proyecto
	var input_dir := Input.get_vector("Izquierda", "Atras", "Frente", "Derecha")
	var camera_basis := cam.global_transform.basis
	var forward := -camera_basis.z.normalized()
	var right := camera_basis.x.normalized()
	var direction := (right * -input_dir.x + forward * -input_dir.y).normalized()
	
	# Aplicar velocidad
	if direction:
		velocity.x = lerp(velocity.x, direction.x * SPEED, delta * 10.0)
		velocity.z = lerp(velocity.z, direction.z * SPEED, delta * 10.0)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	# Rotación del personaje
	if direction.length() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		$CollisionShape3D.rotation.y = lerp_angle($CollisionShape3D.rotation.y, target_rotation, delta * 10.0)
	
	var is_moving = direction.length() > 0.01 and is_on_floor()
	
	if is_moving:
		if not audio.playing:
			audio.play()
	else:
		if audio.playing:
			audio.stop()
	audio.pitch_scale = 1.5 if SPEED > 6 else 1.05
	
	move_and_slide()
