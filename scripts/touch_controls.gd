class_name TouchControls
extends CanvasLayer

static var aim_vector: Vector2 = Vector2.ZERO

@onready var move_stick: Control = $UI/MoveZone
@onready var aim_stick: Control = $UI/AimZone


func _ready() -> void:
	visible = DisplayServer.is_touchscreen_available()
	move_stick.changed.connect(_apply_move)
	aim_stick.changed.connect(_apply_aim)


func _process(_elapsed: float) -> void:
	var show: bool = DisplayServer.is_touchscreen_available()
	if PauseState.isPaused or (PlayState.current != null and (PlayState.current.choosing_upgrade() or PlayState.current.gameOverText.visible)):
		show = false
	if visible != show:
		visible = show
		if not show:
			_release_all()


func _exit_tree() -> void:
	_release_all()


func _apply_move(vector: Vector2) -> void:
	_axis("move_left", "move_right", vector.x)
	_axis("move_up", "move_down", vector.y)


func _apply_aim(vector: Vector2) -> void:
	aim_vector = vector
	_axis("aim_left", "aim_right", vector.x)
	_axis("aim_up", "aim_down", vector.y)


func _on_super_down() -> void:
	Input.action_press("super")
	Input.action_release("super")


func _on_dodge_down() -> void:
	Input.action_press("dodge")


func _on_dodge_up() -> void:
	Input.action_release("dodge")


func _on_pause_down() -> void:
	Input.action_press("pause")
	Input.action_release("pause")


func _axis(negative: String, positive: String, value: float) -> void:
	if value <= -0.08:
		Input.action_release(positive)
		Input.action_press(negative, -value)
	elif value >= 0.08:
		Input.action_release(negative)
		Input.action_press(positive, value)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


func _release_all() -> void:
	aim_vector = Vector2.ZERO
	for action in ["move_left", "move_right", "move_up", "move_down", "aim_left", "aim_right", "aim_up", "aim_down", "dodge", "super", "pause"]:
		Input.action_release(action)
