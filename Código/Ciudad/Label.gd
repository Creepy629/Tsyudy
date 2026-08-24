extends SubViewportContainer
@onready var label: Label = $SubViewport/Label

func _on_timer_timeout() -> void:
	label.text = ""
