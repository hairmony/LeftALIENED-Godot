class_name EndlessState
extends PlayState

var _enemyInterval: float = 1.5
var _asteroidInterval: float = 0.8
var _maxEnemies: int = 8
var _maxAsteroids: int = 12
var _enemySpeed: int = 55
var _asteroidSpeed: int = 100
var _asteroidDrift: float = 50.0
var _endlessEnemyAcc: float = 0.0
var _endlessAsteroidAcc: float = 0.0
var _rampAcc: float = 0.0
var _time: float = 0.0

var _xp: float = 0.0
var _xpGoal: float = 50.0
var _level: int = 0
var _pending: int = 0

@onready var timerText: Label = $HUD/UI/TimerText
@onready var xpBar: ColorRect = $HUD/UI/XpBar
@onready var xpFill: ColorRect = $HUD/UI/XpBar/Fill
@onready var xpLevel: Label = $HUD/UI/XpLevel
@onready var xpCount: Label = $HUD/UI/XpCount
@onready var levelUp: Control = $HUD/UI/LevelUp
@onready var superButton: Button = $HUD/UI/LevelUp/SuperButton
@onready var gunsButton: Button = $HUD/UI/LevelUp/GunsButton
@onready var droneButton: Button = $HUD/UI/LevelUp/DroneButton


func begin_mode() -> void:
	waveText.visible = true
	waveText.text = "Nothing LEFT to prove."
	_wave_hide = 2.0
	_enemyInterval = ENDLESS_ENEMY_INTERVAL
	_asteroidInterval = ENDLESS_ASTEROID_INTERVAL
	_maxEnemies = ENDLESS_MAX_ENEMIES
	_maxAsteroids = ENDLESS_MAX_ASTEROIDS
	_enemySpeed = ENDLESS_ENEMY_SPEED
	_asteroidSpeed = ENDLESS_ASTEROID_SPEED
	_asteroidDrift = ENDLESS_ASTEROID_DRIFT
	_endlessEnemyAcc = 0.0
	_endlessAsteroidAcc = 0.0
	_rampAcc = 0.0
	_time = 0.0
	_xp = 0.0
	_level = 0
	_xpGoal = _xp_goal()
	_pending = 0
	levelUp.visible = false
	timerText.visible = true
	timerText.text = "0:00"
	xpBar.visible = true
	xpLevel.visible = true
	xpCount.visible = true
	ship.superUnlocked = false
	ship.multishotCharge = 0.0
	ship.PLAYER_HEALTH_MAX = ENDLESS_ARMOR_START
	ship.health = ENDLESS_ARMOR_START
	ship.gunProjectileSpeed = _scene_speed(Player.PLAYER_PROJECTILE_SCENE)
	ship.superProjectileSpeed = _scene_speed(Player.SUPER_PROJECTILE_SCENE)
	_draw_xp()
	_apply_caps()
	updateHealthText()
	updateMultishotText()


func choosing_upgrade() -> bool:
	if _pending < 1 or ship == null or not ship.alive or isgameOver:
		return false
	_refresh_choices()
	return _pending > 0


func on_kill() -> void:
	_xp += 1
	while _xpGoal > 0.0 and _xp >= _xpGoal:
		_xp -= _xpGoal
		_level += 1
		_xpGoal = _xp_goal()
		_grant_armor()
		_pending += 1
	_draw_xp()


func _pick_super() -> void:
	if _pending < 1 or not _super_open():
		return
	if not ship.superUnlocked:
		ship.superUnlocked = true
		ship.multishotCharge = 0.0
		ship.MULTISHOT_CHARGE_MAX = ENDLESS_SUPER_CHARGE_START
		ship.MULTISHOT_SHOT_AMOUNT = ENDLESS_SUPER_SHOTS_START
		ship.BULLET_PENETRATION = ENDLESS_SUPER_PEN_START
		_apply_caps()
		updateMultishotText()
		_spent_choice()
		return
	if ENDLESS_SUPER_CHARGE_MIN < 0.0:
		ship.MULTISHOT_CHARGE_MAX -= ENDLESS_SUPER_CHARGE_RAMP
	else:
		ship.MULTISHOT_CHARGE_MAX = maxf(ENDLESS_SUPER_CHARGE_MIN, ship.MULTISHOT_CHARGE_MAX - ENDLESS_SUPER_CHARGE_RAMP)
	if ship.multishotCharge > ship.MULTISHOT_CHARGE_MAX:
		ship.multishotCharge = ship.MULTISHOT_CHARGE_MAX
	ship.MULTISHOT_SHOT_AMOUNT = _limit_float(ship.MULTISHOT_SHOT_AMOUNT + ENDLESS_SUPER_SHOTS_RAMP, ENDLESS_SUPER_SHOTS_CAP)
	ship.BULLET_PENETRATION = _limit_float(ship.BULLET_PENETRATION + ENDLESS_SUPER_PEN_RAMP, ENDLESS_SUPER_PEN_CAP)
	updateMultishotText()
	_spent_choice()


func _pick_guns() -> void:
	if _pending < 1 or not _guns_open():
		return
	ship.PLAYER_SHOTS_PER_SEC = _limit_float(ship.PLAYER_SHOTS_PER_SEC + ENDLESS_GUNS_RAMP, ENDLESS_GUNS_CAP)
	if ship.PLAYER_SHOTS_PER_SEC > 0.0:
		ship.fireRate = 1.0 / ship.PLAYER_SHOTS_PER_SEC
	ship.gunProjectileSpeed = _limit_float(ship.gunProjectileSpeed + ENDLESS_GUNS_SPEED_RAMP, ENDLESS_GUNS_SPEED_CAP)
	ship.superProjectileSpeed = _limit_float(ship.superProjectileSpeed + ENDLESS_GUNS_SPEED_RAMP, ENDLESS_GUNS_SPEED_CAP)
	_spent_choice()


func _pick_drone() -> void:
	if _pending < 1 or not _drone_open():
		return
	ship.droneCount = _limit_int(ship.droneCount + ENDLESS_DRONE_AMOUNT, ENDLESS_DRONE_CAP)
	_spent_choice()


func _grant_armor() -> void:
	if ship == null or ENDLESS_ARMOR_AMOUNT <= 0:
		return
	if ship.health < ship.PLAYER_HEALTH_MAX:
		ship.health = mini(ship.health + ENDLESS_ARMOR_AMOUNT, ship.PLAYER_HEALTH_MAX)
	else:
		ship.PLAYER_HEALTH_MAX = _limit_int(ship.PLAYER_HEALTH_MAX + ENDLESS_ARMOR_AMOUNT, ENDLESS_ARMOR_CAP)
		ship.health = ship.PLAYER_HEALTH_MAX
	updateHealthText()


func _spent_choice() -> void:
	_pending -= 1
	if _pending < 1:
		levelUp.visible = false
		_release_menu_focus()
	else:
		_refresh_choices()


func _refresh_choices() -> void:
	_apply_caps()
	var super_open := _super_open()
	var guns_open := _guns_open()
	var drone_open := _drone_open()
	if not super_open and not guns_open and not drone_open:
		_pending = 0
		levelUp.visible = false
		_release_menu_focus()
		return
	levelUp.visible = true
	_set_choice(superButton, super_open)
	_set_choice(gunsButton, guns_open)
	_set_choice(droneButton, drone_open)
	if Main.using_controller:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != superButton and focused != gunsButton and focused != droneButton:
			for choice in [superButton, gunsButton, droneButton]:
				if not choice.disabled:
					choice.grab_focus()
					break


func _release_menu_focus() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.gui_release_focus()


func _set_choice(button: Button, open: bool) -> void:
	button.disabled = not open
	button.focus_mode = Control.FOCUS_ALL if open else Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	button.modulate = Color.WHITE if open else Color(0.35, 0.35, 0.35, 1)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		if open:
			button.remove_theme_color_override(key)
		else:
			button.add_theme_color_override(key, Color(0.45, 0.45, 0.45, 1))


func _super_open() -> bool:
	if not ship.superUnlocked:
		return true
	return _can_lower(ship.MULTISHOT_CHARGE_MAX, ENDLESS_SUPER_CHARGE_RAMP, ENDLESS_SUPER_CHARGE_MIN) \
		or _can_raise(ship.MULTISHOT_SHOT_AMOUNT, ENDLESS_SUPER_SHOTS_RAMP, ENDLESS_SUPER_SHOTS_CAP) \
		or _can_raise(ship.BULLET_PENETRATION, ENDLESS_SUPER_PEN_RAMP, ENDLESS_SUPER_PEN_CAP)


func _guns_open() -> bool:
	return _can_raise(ship.PLAYER_SHOTS_PER_SEC, ENDLESS_GUNS_RAMP, ENDLESS_GUNS_CAP) \
		or _can_raise(ship.gunProjectileSpeed, ENDLESS_GUNS_SPEED_RAMP, ENDLESS_GUNS_SPEED_CAP) \
		or _can_raise(ship.superProjectileSpeed, ENDLESS_GUNS_SPEED_RAMP, ENDLESS_GUNS_SPEED_CAP)


func _drone_open() -> bool:
	if ENDLESS_DRONE_AMOUNT <= 0:
		return false
	if ENDLESS_DRONE_CAP < 0:
		return true
	return ship.droneCount < ENDLESS_DRONE_CAP


func _scene_speed(packed: PackedScene) -> float:
	var node := packed.instantiate()
	var speed := 275.0
	if node is Projectile:
		speed = (node as Projectile).speed
	node.free()
	return speed


func _can_raise(current: float, ramp: float, cap: float) -> bool:
	if ramp <= 0.0:
		return false
	var next := current + ramp
	if cap >= 0.0:
		next = minf(next, cap)
	return next > current and not is_equal_approx(next, current)


func _can_lower(current: float, ramp: float, floor_value: float) -> bool:
	if ramp <= 0.0:
		return false
	var next := current - ramp
	if floor_value >= 0.0:
		next = maxf(next, floor_value)
	return next < current and not is_equal_approx(next, current)


func _apply_caps() -> void:
	if ship != null and ship.superUnlocked:
		ship.MULTISHOT_SHOT_AMOUNT = _limit_float(ship.MULTISHOT_SHOT_AMOUNT, ENDLESS_SUPER_SHOTS_CAP)
		ship.BULLET_PENETRATION = _limit_float(ship.BULLET_PENETRATION, ENDLESS_SUPER_PEN_CAP)
		if ENDLESS_SUPER_CHARGE_MIN >= 0.0 and ship.MULTISHOT_CHARGE_MAX < ENDLESS_SUPER_CHARGE_MIN:
			ship.MULTISHOT_CHARGE_MAX = ENDLESS_SUPER_CHARGE_MIN
	if ship != null:
		ship.PLAYER_SHOTS_PER_SEC = _limit_float(ship.PLAYER_SHOTS_PER_SEC, ENDLESS_GUNS_CAP)
		if ship.gunProjectileSpeed >= 0.0:
			ship.gunProjectileSpeed = _limit_float(ship.gunProjectileSpeed, ENDLESS_GUNS_SPEED_CAP)
		if ship.superProjectileSpeed >= 0.0:
			ship.superProjectileSpeed = _limit_float(ship.superProjectileSpeed, ENDLESS_GUNS_SPEED_CAP)
		if ship.PLAYER_SHOTS_PER_SEC > 0.0:
			ship.fireRate = 1.0 / ship.PLAYER_SHOTS_PER_SEC
		ship.PLAYER_HEALTH_MAX = _limit_int(ship.PLAYER_HEALTH_MAX, ENDLESS_ARMOR_CAP)
		if ship.health > ship.PLAYER_HEALTH_MAX:
			ship.health = ship.PLAYER_HEALTH_MAX
		ship.droneCount = _limit_int(ship.droneCount, ENDLESS_DRONE_CAP)
	_maxEnemies = _limit_int(_maxEnemies, ENDLESS_MAX_ENEMIES_CAP)
	_maxAsteroids = _limit_int(_maxAsteroids, ENDLESS_MAX_ASTEROIDS_CAP)
	_enemySpeed = _limit_int(_enemySpeed, ENDLESS_ENEMY_SPEED_CAP)
	_asteroidSpeed = _limit_int(_asteroidSpeed, ENDLESS_ASTEROID_SPEED_CAP)


func _xp_goal() -> float:
	return float(maxi(ceili(ENDLESS_XP_KILLS * pow(ENDLESS_XP_RAMP_PERCENT, float(_level))), 1))


func _draw_xp() -> void:
	var goal: float = maxf(_xpGoal, 1.0)
	xpFill.anchor_right = clampf(_xp / goal, 0.0, 1.0)
	xpFill.offset_right = 0.0
	xpLevel.text = "LVL " + str(_level)
	xpCount.text = str(int(_xp)) + "/" + str(int(goal))


func tick_mode(elapsed: float) -> void:
	if ship.alive:
		_time += elapsed
		var total := int(_time)
		timerText.text = "%d:%02d" % [total / 60, total % 60]
	if ENDLESS_RAMP_TIME > 0.0:
		_rampAcc += elapsed
		if _rampAcc >= ENDLESS_RAMP_TIME:
			_rampAcc = 0.0
			_apply_ramp()
	_endlessEnemyAcc += elapsed
	if _endlessEnemyAcc >= _enemyInterval:
		_endlessEnemyAcc = 0.0
		if _count_living(enemy) < _maxEnemies:
			_spawn_enemy()
	_endlessAsteroidAcc += elapsed
	if _endlessAsteroidAcc >= _asteroidInterval:
		_endlessAsteroidAcc = 0.0
		if _count_living(asteroid) < _maxAsteroids:
			_spawn_asteroid()


func _apply_ramp() -> void:
	_enemyInterval = maxf(ENDLESS_ENEMY_INTERVAL_MIN, _enemyInterval - ENDLESS_ENEMY_INTERVAL_RAMP)
	_asteroidInterval = maxf(ENDLESS_ASTEROID_INTERVAL_MIN, _asteroidInterval - ENDLESS_ASTEROID_INTERVAL_RAMP)
	_maxEnemies = _limit_int(_maxEnemies + ENDLESS_MAX_ENEMIES_RAMP, ENDLESS_MAX_ENEMIES_CAP)
	_maxAsteroids = _limit_int(_maxAsteroids + ENDLESS_MAX_ASTEROIDS_RAMP, ENDLESS_MAX_ASTEROIDS_CAP)
	_enemySpeed = _limit_int(_enemySpeed + ENDLESS_ENEMY_SPEED_RAMP, ENDLESS_ENEMY_SPEED_CAP)
	_asteroidSpeed = _limit_int(_asteroidSpeed + ENDLESS_ASTEROID_SPEED_RAMP, ENDLESS_ASTEROID_SPEED_CAP)
	for e in enemy:
		if e is Enemy and e.exists:
			var foe := e as Enemy
			var dir := signf(foe.velocity.x)
			if dir == 0.0:
				dir = 1.0
			foe.ENEMY_SPEED = _enemySpeed
			foe.velocity.x = dir * _enemySpeed
	for a in asteroid:
		if a is Asteroid and a.exists:
			var rock := a as Asteroid
			rock.ASTEROID_SPEED = _asteroidSpeed
			rock.drift = _asteroidDrift


func _limit_float(value: float, cap: float) -> float:
	if cap < 0.0:
		return value
	return minf(value, cap)


func _limit_int(value: int, cap: int) -> int:
	if cap < 0:
		return value
	return mini(value, cap)


func prepare_enemy(e: Enemy) -> void:
	e.ENEMY_SPEED = _enemySpeed


func prepare_asteroid(a: Asteroid) -> void:
	a.ASTEROID_SPEED = _asteroidSpeed
	a.drift = _asteroidDrift
