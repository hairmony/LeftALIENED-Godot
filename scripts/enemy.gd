class_name Enemy
extends Actor

@export var ENEMY_SPEED: int = 55 #Default value

var initX: float #used to track the inital x coordinate of the enemy
var spawnSide: int # Tracks if it spawned on left = 0 or right = 1


func _ready() -> void:
	use_graphic("assets/images/Enemy.png", 32, 32)

	spawnSide = randi_range(0, 1)
	if spawnSide == 0:
		position.x = -32 # off-screen left
		velocity.x = ENEMY_SPEED # move right
	else:
		position.x = Main.WIDTH # off-screen right
		velocity.x = -ENEMY_SPEED # move left

	initX = position.x # Saves initial position
	position.y = randf_range(0.0, 1.0) * (Main.HEIGHT - 32)
	set_angle(180)


func update(elapsed: float) -> void:
	super.update(elapsed)
	# When enemy goes off the opposite side it spawn, bring back to spawn
	if position.x + width() < 0 or position.x > Main.WIDTH:
		# respawn on same side it originally came from
		position.y = randf_range(0.0, 1.0) * (Main.HEIGHT - 32)
		if spawnSide == 0:
			position.x = Main.WIDTH
			velocity.x = -ENEMY_SPEED
		else:
			position.x = -32
			velocity.x = ENEMY_SPEED


func play_death() -> void:
	var frames: Array = []
	for i in range(1, sprite.hframes):
		frames.append(i)
	if frames.is_empty():
		frames = [0]
	play_frames(frames, 24.0)
