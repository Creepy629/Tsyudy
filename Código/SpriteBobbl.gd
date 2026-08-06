extends Sprite3D

@export var anim_speed := 12.0
@export var lifetime := 3.0

var anim_frame := 0
var frame_timer := 0.0
var selected_row := 0
var timer := 0.0

func _ready() -> void:
	# Seleccionar aleatoriamente una de las 3 filas (vframes)
	selected_row = randi_range(0, 2)
	
	# Configurar el sprite
	hframes = 16
	vframes = 3
	
	# Iniciar en el primer frame de la fila seleccionada
	frame = selected_row * hframes

func _process(delta: float) -> void:
	# Actualizar el timer de vida
	timer += delta
	
	# Destruir la escena después del tiempo de vida
	if timer >= lifetime:
		queue_free()
		return
	
	# Animar el sprite
	frame_timer += delta * anim_speed
	anim_frame = int(frame_timer) % hframes
	
	# Calcular el frame actual: fila seleccionada * columnas + frame actual
	frame = (selected_row * hframes) + anim_frame
