class_name ClassicState
extends PlayState

var currentWave: int = -1
var enemiesToSpawn: int = 0
var asteroidsToSpawn: int = 0
var isSpawning: bool = false

@export_group("Classic")
@export var FINAL_WAVE: int = 12
@export var SPAWN_RATE: float = 0.5 #0.5
@export var SECTOR_FLASH_SPEED: float = 6.0
@export var SECTOR_CLEAR_TIME: float = 5.0
@export var SECTOR_FADE_TIME: float = 1.5

var _enemiesLeft: int = 0
var _asteroidsLeft: int = 0
var _enemySpawnAcc: float = 0.0
var _asteroidSpawnAcc: float = 0.0
var _spawnClear: float = 0.0
var _sector_won: bool = false
var _sector_time: float = 0.0
var _sector_fading: bool = false



func begin_mode() -> void:
	startWave()


func on_boss_cleared() -> void:
	if currentWave == FINAL_WAVE:
		gameWonText.visible = true
		isgameOver = true
		ship.isInvincible = true
		_sector_won = true
		_sector_time = 0.0
	else:
		isWaveComplete()


func tick_mode(_elapsed: float) -> void:
	if _enemiesLeft > 0: # for some reason FlxTimer loops inf times if the value is 0
		_enemySpawnAcc += _elapsed
		while _enemiesLeft > 0 and _enemySpawnAcc >= SPAWN_RATE:
			_enemySpawnAcc -= SPAWN_RATE
			_enemiesLeft -= 1
			_spawn_enemy()
	# Add asteroids staggered
	if _asteroidsLeft > 0: # for some reason FlxTimer loops inf times if the value is 0
		_asteroidSpawnAcc += _elapsed
		while _asteroidsLeft > 0 and _asteroidSpawnAcc >= SPAWN_RATE:
			_asteroidSpawnAcc -= SPAWN_RATE
			_asteroidsLeft -= 1
			_spawn_asteroid()
	if isSpawning and _spawnClear > 0.0:
		_spawnClear -= _elapsed
		if _spawnClear <= 0.0:
			isSpawning = false
	if _sector_won:
		_sector_time += _elapsed
		var wave := sin(_sector_time * SECTOR_FLASH_SPEED)
		gameWonText.modulate.a = 0.2 + 0.8 * (wave * 0.5 + 0.5)
		if not _sector_fading and _sector_time >= SECTOR_CLEAR_TIME:
			_sector_fading = true
			_fade_to_credits()


func debug_skip() -> void:
	startWave()


func startWave() -> void:
	if isgameOver:
		return
	currentWave += 1
	isSpawning = true
	# Flash wave text on screen
	waveText.visible = true
	_wave_hide = 2.0

	enemiesToSpawn = 0
	asteroidsToSpawn = 0

	if currentWave == 0:
		enemiesToSpawn = 0
		asteroidsToSpawn = 12
		waveText.text = "The only one LEFT."
	if currentWave == 1:
		enemiesToSpawn = 2
		asteroidsToSpawn = 10
		waveText.text = "Wave " + str(currentWave)
	elif currentWave == 2:
		enemiesToSpawn = 4
		asteroidsToSpawn = 12
		waveText.text = "Wave " + str(currentWave)
	elif currentWave == 3:
		enemiesToSpawn = 6
		asteroidsToSpawn = 12
		waveText.text = "Wave " + str(currentWave)
	elif currentWave == 4:
		enemiesToSpawn = 12
		asteroidsToSpawn = 12
		waveText.text = "Wave " + str(currentWave)
	elif currentWave == 5: # Boss phase 1
		enemiesToSpawn = 16
		asteroidsToSpawn = 16
		waveText.text = "Wave " + str(currentWave)
	elif currentWave == 6:
		enemiesToSpawn = 0
		asteroidsToSpawn = 12
		waveText.text = "Enemy Leader Inbound..."
		spawnBoss(0, 1)
	elif currentWave == 7:
		enemiesToSpawn = 16
		asteroidsToSpawn = 24
		waveText.text = "Wave " + str(currentWave - 1) # Don't count BOSS as a wave
	elif currentWave == 8:
		enemiesToSpawn = 24
		asteroidsToSpawn = 24
		waveText.text = "Wave " + str(currentWave - 1)
	elif currentWave == 9:
		enemiesToSpawn = 32
		asteroidsToSpawn = 12
		waveText.text = "Wave " + str(currentWave - 1)
	elif currentWave == 10:
		enemiesToSpawn = 48
		asteroidsToSpawn = 12
		waveText.text = "Wave " + str(currentWave - 1)
	elif currentWave == 11:
		enemiesToSpawn = 80
		asteroidsToSpawn = 0
		waveText.text = "Enemy Territory!"
	elif currentWave == FINAL_WAVE: # Boss Wave
		enemiesToSpawn = 0
		asteroidsToSpawn = 12
		waveText.text = "Enemy Leader Awakened..."
		spawnBoss(0, 0)

	# Spawn enemies and asteroids
	_enemiesLeft = enemiesToSpawn
	_asteroidsLeft = asteroidsToSpawn
	_enemySpawnAcc = 0.0
	_asteroidSpawnAcc = 0.0
	# Calculating the total spawn time to spawn in everything
	var enemySpawnDuration := SPAWN_RATE * enemiesToSpawn
	var asteroidSpawnDuration := SPAWN_RATE * asteroidsToSpawn
	var totalSpawnTime := maxf(enemySpawnDuration, asteroidSpawnDuration)
	if totalSpawnTime > 0.0:
		_spawnClear = totalSpawnTime + 0.1
	else:
		# If nothing is spawning (like a boss wave), set the flag immediately.
		isSpawning = false
		_spawnClear = 0.0


func spawnBoss(assetID: int = 0, bossType: int = 0) -> void:
	boss = _boss_scene.instantiate() as Boss
	boss.setup(0, -100, assetID, bossType) # Slightly off the top of the screen
	actors.add_child(boss)
	boss.position.x = (Main.WIDTH - boss.width()) / 2.0
	var tw := create_tween()
	tw.tween_property(boss, "position:y", 50.0, 2.0) # Tweening exists!


func _fade_to_credits() -> void:
	var credits := Main.scene("res://scenes/credits.tscn").instantiate() as Control
	credits.set("play_music_on_ready", false)
	credits.modulate.a = 0.0
	credits.set("on_closed", func() -> void:
		Main.current.change_state("menu")
	)
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.add_child(credits)
	Main.current.add_child(layer)
	Main.current.fade_music_then("assets/music/CreditsMusic.mp3", 0.25)
	var tw := create_tween()
	tw.tween_property(credits, "modulate:a", 1.0, maxf(SECTOR_FADE_TIME, 0.0))
	tw.tween_callback(func() -> void:
		if Main.current != null and Main.current.state == self:
			Main.current.state = null
		queue_free()
	)


func isWaveComplete() -> void:
	if isSpawning or isgameOver:
		return
	var isEnemiesDead: bool = (enemiesToSpawn == 0) or (_count_living(enemy) == 0)
	var isAsteroidsDead: bool = (asteroidsToSpawn == 0) or (_count_living(asteroid) <= 4)
	if ship.alive and isEnemiesDead and isAsteroidsDead and (boss == null or not boss.alive):
		startWave()
