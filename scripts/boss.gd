class_name Boss
extends Actor

var _shot_scene: PackedScene

@export var BOSS_HP_MAX: int = 75

var hp: int = BOSS_HP_MAX # Amount of hits to kill it
@export var BOSS_CIRCLE_ATTACK_DELAY: float = 0.5 # Boss attacks every x seconds
@export var BOSS_CIRCLE_SHOT_AMOUNT: int = 12
@export var BOSS_WALL_ATTACK_DELAY: float = 0.75 # Gap between lines formed
@export var BOSS_WALL_SHOT_AMOUNT: int = 28
@export var BOSS_WALL_GAP_SIZE: int = 6
@export var BOSS_WALL_GAP_STEP: int = 3
@export var BOSS_WALL_MOVEMENT_SPEED: float = 150.0 # How fast the boss moves!

var patternAngle: float = 0.0
var bossType: int = 0
var _attack_wait: float = 0.0
var _attack_delay: float = 0.5

var lastGapPosition: int
var gapDirection: int = 1


var _set_up: bool = false

func _projectile() -> Projectile:
	if _shot_scene == null:
		_shot_scene = Main.scene("res://scenes/boss_projectile.tscn")
	return _shot_scene.instantiate() as Projectile


func setup(X: float = 0.0, Y: float = 0.0, assetID: int = 0, boss_type: int = 0) -> void:
	if _set_up:
		return
	_set_up = true
	hp = BOSS_HP_MAX
	bossType = boss_type
	position = Vector2(X, Y)
	lastGapPosition = randi_range(0, BOSS_WALL_SHOT_AMOUNT - BOSS_WALL_GAP_SIZE)

	if Main.current.music.playing:
		Main.current.fade_music_then("assets/music/BossMusic.mp3", 0.25)
	else:
		Main.current.play_music("assets/music/BossMusic.mp3", 0.25)

	var asset := "assets/images/Boss.png"
	match assetID:
		0:
			asset = "assets/images/Boss.png"
		1:
			asset = "assets/images/Boss2.png"
		_:
			asset = "assets/images/Boss.png"
	use_graphic(asset)

	# Boss attack pattern
	if bossType == 0:
		_attack_delay = BOSS_CIRCLE_ATTACK_DELAY
	else:
		_attack_delay = BOSS_WALL_ATTACK_DELAY
	_attack_wait = _attack_delay


# I have to do this for some reason
func update(elapsed: float) -> void:
	if not exists:
		return
	super.update(elapsed)
	if PauseState.isPaused:
		return

	if velocity.x != 0:
		var oldX := position.x
		position.x = clampf(position.x, 0, Main.WIDTH - width())
		# If boss hits boundary STOP
		if position.x != oldX:
			velocity.x = 0

	var play := PlayState.current
	if play == null or play.ship == null or not play.ship.alive:
		return
	_attack_wait -= elapsed
	if _attack_wait > 0.0:
		return
	if bossType == 0:
		fire_pattern_circle()
	else:
		fire_pattern_wall()


func fire_pattern_circle() -> void:
	if not alive or PauseState.isPaused: # This is how you pause the game!
		return

	Main.current.play_sound("assets/sounds/ShootEnemy.ogg", 0.4)

	var angleIncrement: float = 360.0 / BOSS_CIRCLE_SHOT_AMOUNT
	var spinAddtion: float = 0.0
	var shootDelayMultiplier: float = 1.0

	if hp <= BOSS_HP_MAX / 2.0:
		spinAddtion = -6.5
		shootDelayMultiplier = 0.75 # lower number is faster (its the percentage of DELAY)

	var play := PlayState.current
	if play != null:
		for i in BOSS_CIRCLE_SHOT_AMOUNT:
			var ang := patternAngle + (i * angleIncrement)
			var mid := get_midpoint()
			var p := _projectile()
			p.setup(mid.x, mid.y, ang)
			play.enemyProjectiles.append(p)
			play.actors.add_child(p)

	patternAngle += 2 + spinAddtion
	_attack_delay = BOSS_CIRCLE_ATTACK_DELAY * shootDelayMultiplier
	_attack_wait = _attack_delay


func fire_pattern_wall() -> void:
	if not alive or PauseState.isPaused:
		return

	Main.current.play_sound("assets/sounds/ShootEnemy.ogg", 0.4)

	var play := PlayState.current
	if play == null:
		return

	var bulletSpacing: float = float(Main.WIDTH) / BOSS_WALL_SHOT_AMOUNT
	var gapPosition: int = lastGapPosition + (gapDirection * BOSS_WALL_GAP_STEP)

	if gapPosition < 0:
		gapPosition = 0
		gapDirection = 1
	elif gapPosition > BOSS_WALL_SHOT_AMOUNT - BOSS_WALL_GAP_SIZE:
		gapPosition = BOSS_WALL_SHOT_AMOUNT - BOSS_WALL_GAP_SIZE
		gapDirection = -1

	lastGapPosition = gapPosition
	velocity.x = gapDirection * BOSS_WALL_MOVEMENT_SPEED

	for i in BOSS_WALL_SHOT_AMOUNT:
		# Picked gap
		if i >= gapPosition and i < gapPosition + BOSS_WALL_GAP_SIZE:
			continue
		var bulletX: float = i * bulletSpacing
		# Fire straight down (angle is 0 in a system where 0 is up)
		var p := _projectile()
		p.setup(bulletX, 0, 90)
		play.enemyProjectiles.append(p)
		play.actors.add_child(p)

	_attack_wait = BOSS_WALL_ATTACK_DELAY


# Override kill() to stop attack timer if boss died
func kill() -> void:
	super.kill()
	exists = false
	visible = false
	velocity = Vector2.ZERO
	_attack_wait = 99999.0
	if Main.current.music.playing:
		Main.current.fade_music_then("assets/music/LevelMusic.mp3", 0.25)
	else:
		Main.current.play_music("assets/music/LevelMusic.mp3", 0.25)
