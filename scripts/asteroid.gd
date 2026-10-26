class_name Asteroid
extends Actor

@export var ASTEROID_SPEED: int = 100 #Default value
var drift: float = 50.0


func _ready() -> void:
	use_graphic("assets/images/Asteroid.png", 32, 32)
	reset_position()


func reset_position() -> void:
	position.x = randf_range(0, Main.WIDTH - width())
	position.y = -height() # Start just above the screen
	velocity.x = randf_range(-drift, drift) # Slight horizontal drift
	velocity.y = ASTEROID_SPEED


func update(elapsed: float) -> void:
	velocity.y = ASTEROID_SPEED
	velocity.x = randf_range(-drift, drift)
	super.update(elapsed)
	if position.y > Main.HEIGHT:
		reset_position()


func play_death() -> void:
	var frames: Array = []
	var count: int = sprite.hframes
	for i in range(1, count):
		frames.append(i)
	if frames.is_empty():
		frames = [0]
	play_frames(frames, 24.0)
