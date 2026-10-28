class_name PlayState
extends Node2D

var _player_scene: PackedScene
var _asteroid_scene: PackedScene
var _enemy_scene: PackedScene
var _enemy_projectile_scene: PackedScene
var _boss_scene: PackedScene
var _pause_scene: PackedScene
var _flash_scene: PackedScene

static var current: PlayState

@onready var actors: Node2D = $Actors
@onready var backdrop: Sprite2D = $Backdrop
@onready var backdrop2: Sprite2D = $Backdrop2
@onready var scoreText: Label = $HUD/UI/ScoreText
@onready var multiplierText: Label = $HUD/UI/MultiplierText
@onready var multishotText: Label = $HUD/UI/MultishotText
@onready var healthText: Label = $HUD/UI/HealthText
@onready var gameOverText: Label = $HUD/UI/GameOverText
@onready var gameWonText: Label = $HUD/UI/GameWonText
@onready var waveText: Label = $HUD/UI/WaveText
@onready var controlsText: RichTextLabel = $HUD/UI/ControlsText

var ship: Player # So Boss.hx can use it
var _restarting: bool = false
var _restart_shown: bool = false
var asteroid: Array = []
var projectiles: Array = []
var enemyProjectiles: Array = [] # Public so boss can fire projectiles in Boss.hx
var specialProjectiles: Array = [] # Separate special projectiles
var enemy: Array = []

var isgameOver: bool = false
@export var DEATH_ANIMATION_DURATION: float = 0.4 # To play animation, number of frames/Frame rate

# Score tracking variables
var asteroidHits: int = 0
var enemyHits: int = 0
var accuracyBonus: float = 0.0
var score: float = 0.0

static var MULTIPLIER: int = 1 #Set the multiplier to 1; Set to static to be accessible from Enemy.hx
static var multiplierTimer: float = 0.0
@export var MULTIPLIER_MAX: int = 10
@export var MULTIPLIER_DECAY: float = 1.0 # seconds per decay

# Variables for the multi-shot cooldown
var blinkTimer: float = 0.0

# Variables for asteroid
@export var ASTEROID_AMOUNT: int = 8

# Variables for enemies
@export var ENEMY_AMOUNT: int = 4
@export var ENEMY_SHOT_DELAY: float = 1.0 # Shot delay is randomized between -ve and +ve of this value
@export var ENEMY_INACCURACY: float = 2.0 # randomly btw + and - angle
var shotDelay: float = 0.0
var _shotClock: float = 0.0
var _shotInterval: float = 3.0

var boss: Boss
var _wave_hide: float = 0.0

@export var bgScrollSpeed: float = 50.0


func _ready() -> void:
	current = self
	_scroll_backdrop(0.0)
	create()


func _exit_tree() -> void:
	if current == self:
		current = null


func create() -> void:
	_player_scene = Main.scene("res://scenes/player.tscn")
	_asteroid_scene = Main.scene("res://scenes/asteroid.tscn")
	_enemy_scene = Main.scene("res://scenes/enemy.tscn")
	_enemy_projectile_scene = Main.scene("res://scenes/enemy_projectile.tscn")
	_boss_scene = Main.scene("res://scenes/boss.tscn")
	_pause_scene = Main.scene("res://scenes/pause.tscn")
	_flash_scene = Main.scene("res://scenes/flash.tscn")
	MULTIPLIER = 1
	multiplierTimer = 0.0

	Main.current.play_music("assets/music/LevelMusic.mp3", 0.25)

	# Ship select from save file
	var ship_asset: int = 0 # Default to 0
	var saved = OptionsState.ship_choice()
	if saved != null:
		ship_asset = int(saved)

	# Spawn in player
	ship = _player_scene.instantiate() as Player
	ship.apply_asset(ship_asset)
	actors.add_child(ship)
	# Moved player spawn to bottom of the screen
	ship.position.x = Main.WIDTH / 2.0 - (ship.width() / 2.0)
	ship.position.y = Main.HEIGHT
	ship.controlsEnabled = false

	#create a timer that shoots an enemy projectile every 3 seconds
	shotDelay = randf_range(-ENEMY_SHOT_DELAY, ENEMY_SHOT_DELAY) + 3.0
	_shotInterval = shotDelay
	_shotClock = _shotInterval

	begin_mode()
	ControllerIcons.input_type_changed.connect(func(_type, _controller): _refresh_prompt())
	updateScoreText()
	updateHealthText()
	updateMultishotText()


func choosing_upgrade() -> bool:
	return false


func _process(elapsed: float) -> void:
	if choosing_upgrade():
		return

	if Input.is_action_just_pressed("pause"):
		if not _pause_open():
			pausemenu()

	if PauseState.isPaused:
		if ship != null and ship.swapPhase != 0:
			ship.advance_swap(elapsed)
			if ship.exists:
				ship.aim()
		return

	_scroll_backdrop(elapsed)
	_tick_spawns(elapsed)

	for p in projectiles:
		if p.exists:
			p.update(elapsed)
	for p in specialProjectiles:
		if p.exists:
			p.update(elapsed)
	if ship.exists:
		ship.fly_and_move(elapsed)
	elif ship.drones_departing():
		ship.update_drones(elapsed)
	for e in enemy:
		if e.exists:
			e.update(elapsed)
	for a in asteroid:
		if a.exists:
			a.update(elapsed)
	for p in enemyProjectiles:
		if p.exists:
			p.update(elapsed)
	if boss != null and boss.exists:
		boss.update(elapsed)

	_shotClock -= elapsed
	if _shotClock <= 0.0:
		enemyShot()
		_shotClock += _shotInterval

	multiplierText.text = str(MULTIPLIER) + "x"
	multiplierText.visible = MULTIPLIER > 1
	var score_width := scoreText.get_theme_font("font").get_string_size(scoreText.text, HORIZONTAL_ALIGNMENT_LEFT, -1, scoreText.get_theme_font_size("font_size")).x
	multiplierText.offset_left = scoreText.offset_left + score_width + 8.0
	multiplierText.offset_right = multiplierText.offset_left + 80.0
	var combo_span := float(maxi(MULTIPLIER_MAX - 1, 1))
	var combo_color := Color.WHITE.lerp(Color(0.807843, 0.098039, 0.129412), clampf((float(MULTIPLIER) - 1.0) / combo_span, 0.0, 1.0))
	scoreText.modulate = combo_color
	multiplierText.modulate = combo_color

	# controlsText will blink when visible
	if controlsText.visible:
		blinkTimer += elapsed # increment every frame
		controlsText.modulate.a = 0.3 + 0.7 * (sin(blinkTimer * 6.0) * 0.5 + 0.5)
	else:
		controlsText.modulate.a = 1.0
		blinkTimer = 0.0

	# Debug controls
	if Input.is_action_just_pressed("debug_kill"): # press . kill all enemies
		for e in enemy:
			e.kill() # Kill all enemies
			e.exists = false
		for a in asteroid:
			a.kill()
			a.exists = false
		if boss != null and boss.alive:
			boss.kill() # Kill all bosses
		isWaveComplete()

	if Input.is_action_just_pressed("debug_respawn"): # Press , respawn
		_restart_shown = false
		controlsText.text = _super_prompt()
		ship.position = Vector2(Main.WIDTH / 2.0 - (ship.width() / 2.0), Main.HEIGHT - 50)
		ship.alive = true
		ship.exists = true
		ship.visible = true
		ship.health = ship.PLAYER_HEALTH_MAX
		updateHealthText()
		gameOverText.visible = false

	if Input.is_action_just_pressed("debug_god"): # Press / for God mode
		ship.isInvincible = not ship.isInvincible

	if Input.is_action_just_pressed("debug_skip"): # Press F4 to skip wave
		debug_skip()

	# Handle multiplier countdown
	if MULTIPLIER > 1:
		multiplierTimer += elapsed # increment timer
		if multiplierTimer >= MULTIPLIER_DECAY:
			MULTIPLIER -= 1
			multiplierTimer = 0.0

	# Reset button
	if Input.is_action_just_pressed("restart"):
		_restart()

	# Only run gameplay updates if NOT paused
	if ship.alive:
		ship.combat(elapsed)

	# Player collision
	_overlap(asteroid, [ship], collidePlayer)
	_overlap(enemy, [ship], collidePlayer)
	_overlap(enemyProjectiles, [ship], collidePlayer) #Check for collision between enemy projectile and player
	# Projectile collision
	_overlap(asteroid, projectiles, collideProjectile) # Check for collisions between asteroids, projectiles
	_overlap(enemy, projectiles, collideProjectile) # For when enemy is added
	_overlap(enemyProjectiles, specialProjectiles, collideProjectile)
	# Special Projectile collision
	_overlap(asteroid, specialProjectiles, collideProjectile) # Check for collisions between asteroids, projectiles
	_overlap(enemy, specialProjectiles, collideProjectile) # For when enemy is added

	# Boss collision
	if boss != null and boss.alive:
		_overlap([boss], projectiles, collideBoss)
		_overlap([boss], specialProjectiles, collideBoss)
		_overlap([boss], [ship], collidePlayer)

	_purge(projectiles)
	_purge(specialProjectiles)
	_purge(enemyProjectiles)
	_purge(asteroid)
	_purge(enemy)


# Pause menu variables
func pausemenu() -> void:
	var pause := _pause_scene.instantiate()
	add_child(pause)


func _pause_open() -> bool:
	for c in get_children():
		if c is PauseState:
			return true
	return false


func collidePlayer(object1: Actor, object2: Actor) -> void:
	if ship.isDodging or ship.isInvincible:
		return
	if object1 is Asteroid:
		var env := object1 as Asteroid
		if not env.isDead:
			# deduct player health once
			ship.hurt()
			ship.flash(Color(1, 0, 0), 0.1) # Red
		else:
			return
		updateHealthText()
		# handle player death
		if ship.health < 1:
			_lose()
		else:
			# Death animation
			env.isDead = true
			env.play_death()
			env.kill()
			Main.current.play_sound("assets/sounds/ExplodeAsteroid.ogg", 0.4)
			env.hide_after(0.15)
	elif object1 is Enemy:
		var e := object1 as Enemy
		if not e.isDead:
			ship.hurt()
			ship.flash(Color(1, 0, 0), DEATH_ANIMATION_DURATION) # Flash if player hit
		else:
			return
		updateHealthText()
		if ship.health < 1:
			_lose()
		else:
			e.isDead = true
			e.play_death()
			e.kill()
			Main.current.play_sound("assets/sounds/ExplodeEnemy.ogg", 0.4)
			e.hide_after(DEATH_ANIMATION_DURATION)
	elif object1 is Projectile:
		ship.hurt()
		ship.flash(Color(1, 0, 0), 0.1) # Flash if player hit
		updateHealthText()
		if ship.health < 1:
			_lose_silent()
		else:
			object1.kill() # projectiles just disappear, no animation
			object1.exists = false
			object1.visible = false


func _lose() -> void:
	camera_flash(Color(1, 0, 0), 2.0)
	ship.kill()
	ship.exists = false
	ship.visible = false
	ship.update_drones(0.0)
	Main.current.play_sound("assets/sounds/DeathEnemy2.ogg", 0.4)
	_show_restart()
	gameWonText.visible = false
	gameOverText.visible = true


func _lose_silent() -> void:
	camera_flash(Color(1, 0, 0), 2.0)
	ship.kill()
	ship.exists = false
	ship.visible = false
	ship.update_drones(0.0)
	_show_restart()
	gameWonText.visible = false
	gameOverText.visible = true


func _restart() -> void:
	if _restarting:
		return
	_restarting = true
	_restart_shown = false
	controlsText.text = _super_prompt()
	Main.current.change_state("play") # Reset with R key


func _refresh_prompt() -> void:
	if _restart_shown:
		controlsText.text = _restart_prompt()
	elif controlsText.visible:
		controlsText.text = _super_prompt()


func _super_prompt() -> String:
	return ControlsState.prompt_text("super", "to SUPER")


func _restart_prompt() -> String:
	return ControlsState.prompt_text("restart", "to Restart")


func _show_restart() -> void:
	_restart_shown = true
	controlsText.text = _restart_prompt()
	controlsText.visible = true
	controlsText.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if DisplayServer.is_touchscreen_available():
		controlsText.mouse_filter = Control.MOUSE_FILTER_STOP
		if not controlsText.gui_input.is_connected(_on_restart_input):
			controlsText.gui_input.connect(_on_restart_input)


func _on_restart_input(event: InputEvent) -> void:
	if not _restart_shown:
		return
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if tapped:
		_restart()


# Function handles projectile collision
func collideProjectile(object1: Actor, object2: Actor) -> void:
	var pointsAdd: int = 0
	if object1 is Asteroid:
		var env := object1 as Asteroid
		if not env.isDead:
			env.isDead = true
			env.play_death()
			Main.current.play_sound("assets/sounds/ExplodeAsteroid.ogg", 0.4)
			env.kill()
			env.hide_after(DEATH_ANIMATION_DURATION)
			pointsAdd = 200
			asteroidHits += 1
		else:
			return
	elif object1 is Enemy:
		var env := object1 as Enemy
		if not env.isDead:
			env.isDead = true
			env.play_death()
			Main.current.play_sound("assets/sounds/ExplodeEnemy.ogg", 0.4)
			env.kill()
			env.hide_after(DEATH_ANIMATION_DURATION)
			pointsAdd = 100
			enemyHits += 1
			updateMultiplier()
		else:
			return

	if object1 is Projectile:
		var p1 := object1 as Projectile
		if p1.bulletPenetration >= 1.0:
			p1.bulletPenetration -= 1.0
		else:
			p1.kill()
			p1.exists = false
			p1.visible = false
	if object2 is Projectile:
		var p2 := object2 as Projectile
		if p2.bulletPenetration >= 1.0:
			p2.bulletPenetration -= 1.0
		else:
			p2.kill()
			p2.exists = false
			p2.visible = false

	# Add to multishot charge when object is hit
	if ship.superUnlocked and ship.multishotCharge < ship.MULTISHOT_CHARGE_MAX:
		ship.multishotCharge += 1
		updateMultishotText() # Update the display

	var gained := pointsAdd * MULTIPLIER
	score += gained
	on_score(gained)
	# Update score
	updateScoreText()
	isWaveComplete()


func collideBoss(object1: Actor, object2: Actor) -> void:
	var the_boss := object1 as Boss
	var projectile := object2 as Projectile
	projectile.kill()
	projectile.exists = false
	projectile.visible = false
	the_boss.hp -= 1
	# This makes the boss flash when taking damage!
	the_boss.flash(Color(1, 0, 0), 0.1)
	if the_boss.hp <= 0:
		Main.current.play_sound("assets/sounds/DeathBoss.ogg", 0.4)
		camera_flash(Color(1, 1, 1), 1.0)
		the_boss.kill()
		var boss_points := 5000 * MULTIPLIER # Boss worth 5000 (?)
		score += boss_points
		on_score(boss_points)
		if ship.superUnlocked:
			ship.multishotCharge = ship.MULTISHOT_CHARGE_MAX # Boss fully recharges multishot charge
		updateMultishotText()
		updateScoreText()
		ship.health += 1
		updateHealthText()
		on_boss_cleared()


func on_score(_points: int) -> void:
	pass


func begin_mode() -> void:
	pass


func tick_mode(_elapsed: float) -> void:
	pass


func on_boss_cleared() -> void:
	isWaveComplete()


func prepare_enemy(_e: Enemy) -> void:
	pass


func prepare_asteroid(_a: Asteroid) -> void:
	pass


func _tick_spawns(elapsed: float) -> void:
	if _wave_hide > 0.0:
		_wave_hide -= elapsed
		if _wave_hide <= 0.0:
			waveText.visible = false
	tick_mode(elapsed)


func _spawn_enemy() -> void:
	var e := _enemy_scene.instantiate() as Enemy
	prepare_enemy(e)
	enemy.append(e)
	actors.add_child(e)


func _spawn_asteroid() -> void:
	var a := _asteroid_scene.instantiate() as Asteroid
	prepare_asteroid(a)
	asteroid.append(a)
	actors.add_child(a)


func isWaveComplete() -> void:
	pass


func debug_skip() -> void:
	pass


func updateMultishotText() -> void:
	if not ship.superUnlocked:
		multishotText.visible = false
		if not _restart_shown:
			controlsText.visible = false
		return
	multishotText.visible = true
	if ship.multishotCharge >= ship.MULTISHOT_CHARGE_MAX and not _restart_shown:
		controlsText.text = _super_prompt()
		controlsText.visible = true
	multishotText.text = "Super: " + str(int(ship.multishotCharge)) + "/" + str(int(ship.MULTISHOT_CHARGE_MAX))


func updateHealthText() -> void:
	healthText.text = "Armor: " + str(ship.health)


# Moved score calculation logic to collision function
func updateScoreText() -> float:
	if is_equal_approx(score, round(score)):
		scoreText.text = "XP: " + str(int(score))
	else:
		scoreText.text = "XP: " + str(score)
	return score


func updateMultiplier() -> void:
	# Increase multiplier, up to max
	if MULTIPLIER < MULTIPLIER_MAX:
		MULTIPLIER += 1
	multiplierTimer = 0.0


#I feel this can be optimized
func enemyShot() -> void:
	if PauseState.isPaused or ship == null or not ship.alive:
		return
	#Access all the enemy FlxGroup elements
	for i in enemy:
		var temp := i as Enemy #create a temporary Enemy object based of the inspected FlxGroup element
		if temp.alive:
			#get the midpoint of the temporary enemy
			var mid := temp.get_midpoint()
			var shipMid := ship.get_midpoint()
			#calculate the difference in position using getMidpoint for the enemy and player
			var dX: float = mid.x - shipMid.x
			var dY: float = mid.y - shipMid.y
			#calculate the angle in degrees; - 180 is used to reverse the calculated angle
			var targetAng: float = rad_to_deg(atan2(dY, dX)) - 180.0
			#Randomly adjust the shot by 2 degrees
			targetAng += randf_range(-ENEMY_INACCURACY, ENEMY_INACCURACY)
			#create a new projectile with the calulated data
			var ep := _enemy_projectile_scene.instantiate() as Projectile
			ep.setup(mid.x, mid.y, targetAng)
			Main.current.play_sound("assets/sounds/ShootEnemy.ogg", 0.4)
			enemyProjectiles.append(ep)
			actors.add_child(ep)
	#reroll shot delay
	shotDelay = randf_range(-ENEMY_SHOT_DELAY, ENEMY_SHOT_DELAY) + 3.0


func camera_flash(color: Color, duration: float) -> void:
	var rect: ColorRect = _flash_scene.instantiate()
	rect.color = color
	$HUD/UI.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, duration)
	tw.tween_callback(rect.queue_free)


func _count_living(group: Array) -> int:
	var n := 0
	for a in group:
		if a.alive and a.exists:
			n += 1
	return n


func _overlap(group_a: Array, group_b: Array, method: Callable) -> void:
	for a in group_a:
		if a == null or not a.exists:
			continue
		for b in group_b:
			if b == null or not b.exists or a == b:
				continue
			if a.rect().intersects(b.rect()):
				method.call(a, b)


func _purge(group: Array) -> void:
	for i in range(group.size() - 1, -1, -1):
		var a: Actor = group[i]
		if not a.exists:
			group.remove_at(i)
			a.queue_free()


func _scroll_backdrop(elapsed: float) -> void:
	var tile_h: float = backdrop.texture.get_height() * backdrop.scale.y
	Main.bg_y = fmod(Main.bg_y + bgScrollSpeed * elapsed, tile_h)
	backdrop.position.y = Main.bg_y
	backdrop2.position.y = Main.bg_y - tile_h
