extends Control

signal changed(vector: Vector2)

var index: int = -1
var origin: Vector2 = Vector2.ZERO
var knob: Vector2 = Vector2.ZERO
var dragging: bool = false
@export var radius: float = 46.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and index < 0:
			index = event.index
			dragging = true
			origin = event.position
			knob = origin
			_emit()
		elif not event.pressed and event.index == index:
			_end()
	elif event is InputEventScreenDrag and event.index == index:
		var delta: Vector2 = event.position - origin
		delta = delta.limit_length(radius)
		knob = origin + delta
		_emit()
	else:
		return
	accept_event()


func _emit() -> void:
	var vector := Vector2.ZERO
	if dragging:
		vector = (knob - origin) / radius
	changed.emit(vector)


func _end() -> void:
	index = -1
	dragging = false
	changed.emit(Vector2.ZERO)
