extends Node

signal hitstop_triggered(duration_sec: float)
var _hitstop_end_time := 0.0
var _in_hitstop := false

func trigger(duration_sec: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var new_end := now + duration_sec
	if not _in_hitstop or new_end > _hitstop_end_time:
		_hitstop_end_time = new_end
	_in_hitstop = true
	Engine.time_scale = 0.0
	hitstop_triggered.emit(duration_sec)

func _process(_delta: float) -> void:
	if _in_hitstop and Time.get_ticks_msec() / 1000.0 >= _hitstop_end_time:
		Engine.time_scale = 1.0
		_in_hitstop = false
