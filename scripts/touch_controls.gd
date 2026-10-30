class_name TouchControls
extends CanvasLayer

static var move_vector: Vector2 = Vector2.ZERO
static var aim_vector: Vector2 = Vector2.ZERO
static var aiming: bool = false
static var touching: int = 0
static var deadzone: float = 0.08

@export_range(0.0, 1.0, 0.01) var stick_deadzone: float = 0.08
@export_range(0.0, 1.0, 0.01) var fire_threshold: float = 0.01

var _touches: Dictionary = {}

@onready var move_stick: Control = $UI/MoveZone
@onready var aim_stick: Control = $UI/AimZone
@onready var super_button: Button = $UI/Actions/SuperButton


func _ready() -> void:
	deadzone = stick_deadzone
	visible = DisplayServer.is_touchscreen_available()
	move_stick.changed.connect(_apply_move)
	aim_stick.changed.connect(_apply_aim)


func _process(_elapsed: float) -> void:
	deadzone = stick_deadzone
	var show: bool = DisplayServer.is_touchscreen_available()
	if PauseState.isPaused or (PlayState.current != null and (PlayState.current.choosing_upgrade() or PlayState.current.gameOverText.visible)):
		show = false
	if visible != show:
		visible = show
		if not show:
			_release_all()
	_update_super()


func _exit_tree() -> void:
	_release_all()


func _apply_move(vector: Vector2) -> void:
	vector = _digital(vector)
	move_vector = vector
	_axis("move_left", "move_right", vector.x)
	_axis("move_up", "move_down", vector.y)


func _apply_aim(vector: Vector2) -> void:
	aiming = aim_stick.dragging
	vector = _digital(vector)
	aim_vector = vector
	_axis("aim_left", "aim_right", vector.x)
	_axis("aim_up", "aim_down", vector.y)


func _digital(vector: Vector2) -> Vector2:
	if vector.length() < stick_deadzone:
		return Vector2.ZERO
	return vector.normalized()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = true
		else:
			_touches.erase(event.index)
		touching = _touches.size()
		if aim_vector.length() < fire_threshold:
			Input.action_release("shoot")


func _update_super() -> void:
	var ready := false
	if PlayState.current != null and PlayState.current.ship != null:
		var ship := PlayState.current.ship
		ready = ship.superUnlocked and ship.controlsEnabled and ship.multishotCharge >= ship.MULTISHOT_CHARGE_MAX
	super_button.disabled = not ready


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
	if value <= -stick_deadzone:
		Input.action_release(positive)
		Input.action_press(negative, 1.0)
	elif value >= stick_deadzone:
		Input.action_release(negative)
		Input.action_press(positive, 1.0)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


func _release_all() -> void:
	move_vector = Vector2.ZERO
	aim_vector = Vector2.ZERO
	aiming = false
	_touches.clear()
	touching = 0
	for action in ["move_left", "move_right", "move_up", "move_down", "aim_left", "aim_right", "aim_up", "aim_down", "dodge", "super", "pause"]:
		Input.action_release(action)
