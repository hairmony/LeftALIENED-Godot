extends Control

signal changed(vector: Vector2)

var index: int = -1
var origin: Vector2 = Vector2.ZERO
var knob: Vector2 = Vector2.ZERO
var dragging: bool = false
@export var radius: float = 18.75


func _ready() -> void:
	queue_redraw()


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
		if vector.length() >= TouchControls.deadzone:
			vector = vector.normalized()
		else:
			vector = Vector2.ZERO
	changed.emit(vector)
	queue_redraw()


func _end() -> void:
	index = -1
	dragging = false
	changed.emit(Vector2.ZERO)
	queue_redraw()


func _draw() -> void:
	var center := origin if dragging else size * 0.5
	var tip := knob if dragging else center
	var col := Color(1, 1, 1, 0.15)
	draw_circle(center, radius, col)
	draw_circle(tip, radius * 0.45, col)
