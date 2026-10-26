extends Control

signal changed(vector: Vector2)

var index: int = -1
var origin: Vector2 = Vector2.ZERO
var knob: Vector2 = Vector2.ZERO
var dragging: bool = false
const RADIUS: float = 46.0


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
		delta = delta.limit_length(RADIUS)
		knob = origin + delta
		_emit()
	else:
		return
	accept_event()
	queue_redraw()


func _emit() -> void:
	var vector := Vector2.ZERO
	if dragging:
		vector = (knob - origin) / RADIUS
	changed.emit(vector)


func _end() -> void:
	index = -1
	dragging = false
	changed.emit(Vector2.ZERO)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	if dragging:
		center = origin
	draw_arc(center, RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.35), 2.0)
	var knob_at := center
	if dragging:
		knob_at = knob
	draw_circle(knob_at, 16.0, Color(0.807843, 0.098039, 0.129412, 0.8))
