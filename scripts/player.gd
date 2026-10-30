class_name Player
extends Actor

@export var PLAYER_SPEED: float = 150 #150
@export var dodgeDuration: float = 0.25 # Seconds
@export var DODGE_SPEED: float = 400 # Speed DURIGN dod40
@export var shipIntroSpeed: float = 160.0
@export var shipSwapSpeed: float = 240.0
@export var PLAYER_SHOTS_PER_SEC: float = 6.0 # How many shots per second
@export var PLAYER_HEALTH_MAX: int = 3
@export var MULTISHOT_CHARGE_MAX: float = 20.0 #20 in number of objects killed
@export var MULTISHOT_SHOT_AMOUNT: float = 8.0 #8
@export var BULLET_PENETRATION: float = 3.0 #3, Bullet pen amount for special projectile

# Dodging variables
var isDodging: bool = false
var dodgeTimer: float = 0.0
var isInvincible: bool = false
var health: int = 3
var fireTimer: float = 0.0
var fireRate: float = 1.0 / 6.0
var multishotCharge: float = 0.0
var superUnlocked: bool = true
var gunProjectileSpeed: float = -1.0
var superProjectileSpeed: float = -1.0
var droneCount: int = 0
var _drones: Array = []
var asset: String = "assets/images/Ship.png"
var lastAimDevice: String = "mouse" # Default to mouse aiming
var controlsEnabled: bool = true
var swapPhase: int = 0
var swapTarget: int = 0
var swapHome := Vector2.ZERO
var swapRestoreControls: bool = true
var _prev_mouse := Vector2.ZERO


var _trail_scene: PackedScene
var _shot_scene: PackedScene
var _super_scene: PackedScene
var _drone_scene: PackedScene


func _ready() -> void:
	_trail_scene = Main.scene("res://scenes/dodge_trail.tscn")
	_shot_scene = Main.scene("res://scenes/player_projectile.tscn")
	_super_scene = Main.scene("res://scenes/super_projectile.tscn")
	_drone_scene = Main.scene("res://scenes/drone.tscn")
	fireRate = 1.0 / PLAYER_SHOTS_PER_SEC
	health = PLAYER_HEALTH_MAX

func apply_asset(assetID: int = 0) -> void:
	match assetID:
		0:
			asset = "assets/images/Ship.png"
		1:
			asset = "assets/images/Ship2.png"
		2:
			asset = "assets/images/Ship3.png"
		3:
			asset = "assets/images/Ship4.png"
		4:
			asset = "assets/images/Ship5.png"
		5:
			asset = "assets/images/Ship6.png"
		_:
			asset = "assets/images/Ship.png"
	use_graphic(asset) #Dimensions for placeholder


func begin_swap(asset_id: int) -> void:
	swapTarget = asset_id
	if swapPhase == 0:
		swapHome = get_midpoint()
		swapRestoreControls = controlsEnabled
		controlsEnabled = false
	swapPhase = 1


func update(elapsed: float) -> void:
	if not exists:
		return

	var move := TouchControls.move_vector
	if move == Vector2.ZERO:
		move = _stick_vector("move_left", "move_right", "move_up", "move_down")
	if move == Vector2.ZERO:
		move = Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	var moveX: float = move.x
	var moveY: float = move.y

	# Apply final movement
	if controlsEnabled:
		position.x += moveX * PLAYER_SPEED * elapsed
		position.y += moveY * PLAYER_SPEED * elapsed

	aim()

	if isDodging:
		dodgeTimer += elapsed
		# Dodge trail!
		var trail: Sprite2D = _trail_scene.instantiate()
		trail.texture = sprite.texture
		trail.scale = sprite.scale
		trail.rotation_degrees = angle
		trail.position = get_midpoint()
		PlayState.current.actors.add_child(trail)
		# Kill trail
		var timer := PlayState.current.get_tree().create_timer(0.2)
		timer.timeout.connect(trail.queue_free)

		# Move forward in the direction ship facing currently
		var angleRad := deg_to_rad(angle - 90.0)
		position.x += cos(angleRad) * DODGE_SPEED * elapsed
		position.y += sin(angleRad) * DODGE_SPEED * elapsed

		# Dodge ending
		if dodgeTimer >= dodgeDuration:
			isDodging = false
			isInvincible = false

	super.update(elapsed)
	#Prevents the player from going offscreen
	if controlsEnabled:
		position.x = clampf(position.x, 0, Main.WIDTH - width())
		position.y = clampf(position.y, 0, Main.HEIGHT - height())


func _pads() -> Array:
	if Main.pad >= 0:
		return [Main.pad]
	return Input.get_connected_joypads()


func _stick_vector(left: String, right: String, up: String, down: String) -> Vector2:
	var best := Vector2.ZERO
	for pad in _pads():
		var joy := Vector2(
			_joy_action_axis(pad, right) - _joy_action_axis(pad, left),
			_joy_action_axis(pad, down) - _joy_action_axis(pad, up)
		)
		if joy.length() > best.length():
			best = joy
	if best.length() < 0.15:
		return Vector2.ZERO
	return best.limit_length(1.0)


func _joy_action_axis(pad: int, action: String) -> float:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion:
			var motion := ev as InputEventJoypadMotion
			var raw := Input.get_joy_axis(pad, motion.axis)
			if motion.axis_value < 0.0:
				return clampf(-raw, 0.0, 1.0)
			return clampf(raw, 0.0, 1.0)
	return 0.0


func aim() -> void:
	# --- Aiming Logic ---

	# Check for active Gamepad aiming
	var aim := _stick_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if aim == Vector2.ZERO:
		aim = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if TouchControls.aim_vector.length() > 0.05:
		aim = TouchControls.aim_vector
	if aim != Vector2.ZERO:
		# Actively aiming with gamepad
		set_angle(rad_to_deg(atan2(aim.y, aim.x)) + 90.0)
		lastAimDevice = "gamepad" # Set last device
		if TouchControls.aim_vector.length() > 0.05:
			_prev_mouse = get_viewport().get_mouse_position()
			return

	var mouse_position := get_viewport().get_mouse_position()
	var mouse_delta := mouse_position - _prev_mouse
	_prev_mouse = mouse_position

	# Check for active Mouse aiming (if the mouse moved)
	if mouse_delta != Vector2.ZERO:
		# If mouse moved, update last device
		lastAimDevice = "mouse"

	# Check if mouse moved
	if lastAimDevice == "mouse":
		# If mouse was last, always aim at cursor
		var center := get_midpoint()
		var dx: float = mouse_position.x - center.x
		var dy: float = mouse_position.y - center.y
		set_angle(rad_to_deg(atan2(dy, dx)) + 90.0)
	elif lastAimDevice == "gamepad":
		# If gamepad was last, the angle was already set when it moved.
		pass


func fly_and_move(elapsed: float) -> void:
	if swapPhase != 0:
		advance_swap(elapsed)
		aim()
	elif not controlsEnabled:
		position.y -= shipIntroSpeed * elapsed
		if position.y <= Main.HEIGHT - 50.0:
			position.y = Main.HEIGHT - 50.0
			controlsEnabled = true
		aim()
	else:
		update(elapsed)
	if swapPhase == 0:
		update_drones(elapsed)


func advance_swap(elapsed: float) -> void:
	if swapPhase == 1:
		position.y -= shipSwapSpeed * elapsed
		if position.y + height() < 0.0:
			apply_asset(swapTarget)
			position = Vector2(swapHome.x - width() * 0.5, Main.HEIGHT)
			swapPhase = 2
	elif swapPhase == 2:
		position.y -= shipSwapSpeed * elapsed
		if get_midpoint().y <= swapHome.y:
			position = swapHome - frame_size() * 0.5
			swapPhase = 0
			controlsEnabled = swapRestoreControls


func combat(elapsed: float) -> void:
	var play := PlayState.current
	fireTimer += elapsed
	# Default: shoot 1 projectile with LMB or hold LMB
	var stick_firing: bool = TouchControls.aiming
	var finger_down := TouchControls.touching > 0
	var shoot_held := Input.is_action_pressed("shoot") and not finger_down
	var shoot_tap := Input.is_action_just_pressed("shoot") and not finger_down
	var shooting: bool = (shoot_held or stick_firing) and fireTimer >= fireRate
	if shooting or shoot_tap:
		Main.current.play_sound("assets/sounds/ShootPlayer.ogg", 0.4)
		fireTimer = 0.0
		var angleDeg: float = angle - 90.0
		var angleRad: float = deg_to_rad(angleDeg)
		var offset: float = 10.0 # distance from center to tip
		var mid := get_midpoint()
		var spawnX: float = mid.x + cos(angleRad) * offset
		var spawnY: float = mid.y + sin(angleRad) * offset
		var p := _shot_scene.instantiate() as Projectile
		if gunProjectileSpeed >= 0.0:
			p.speed = gunProjectileSpeed
		p.setup(spawnX, spawnY, angleDeg)
		play.projectiles.append(p) # Add projectile to group
		play.actors.add_child(p)
		play.note_shot()

	# Multishot: shoot 8 projectiles in a circle
	if superUnlocked and controlsEnabled and Input.is_action_just_pressed("super") and multishotCharge >= MULTISHOT_CHARGE_MAX:
		Main.current.play_sound("assets/sounds/ShootSpecial.ogg", 0.4)
		# Reset the cooldown
		multishotCharge = 0
		var shot_count := int(floor(MULTISHOT_SHOT_AMOUNT))
		if shot_count > 0:
			play.controlsText.visible = false
			var angleIncrement: float = 0.0
			for _i in shot_count:
				# We use ship.angle here to base the shot direction on where the ship is facing
				var shot_mid := get_midpoint()
				var shot := _super_scene.instantiate() as Projectile
				if superProjectileSpeed >= 0.0:
					shot.speed = superProjectileSpeed
				shot.setup(shot_mid.x, shot_mid.y, angle + angleIncrement)
				shot.bulletPenetration = BULLET_PENETRATION
				play.specialProjectiles.append(shot) # Add projectile to group
				play.actors.add_child(shot)
				angleIncrement += 360.0 / float(shot_count)
			play.note_super(shot_count)
			play.updateMultishotText()

	var dodge_released: bool = controlsEnabled and Input.is_action_just_released("dodge")
	if dodge_released and not isDodging:
		Main.current.play_sound("assets/sounds/Dodge.ogg", 0.4)
		isDodging = true
		dodgeTimer = 0.0
		isInvincible = true # for collidePlayer function


func hurt() -> void:
	health -= 1


func update_drones(elapsed: float) -> void:
	_ensure_drones()
	if not alive or not exists:
		for d in _drones:
			(d as Drone).fly_away(self, elapsed)
		return
	var target_pool := Drone.build_target_pool(PlayState.current, get_midpoint())
	for d in _drones:
		var follower := d as Drone
		if follower.departing or not follower.exists:
			follower.departing = false
			follower.arriving = true
			follower.position = Vector2(get_midpoint().x - follower.width() * 0.5, Main.HEIGHT)
		follower.alive = true
		follower.exists = true
		follower.slotCount = droneCount
		follower.target_slot = follower.slot
		follower.target_pool = target_pool
		follower.follow(self, elapsed)
		follower.visible = true


func _ensure_drones() -> void:
	var play := PlayState.current
	if play == null:
		return
	while _drones.size() < droneCount:
		var follower := _drone_scene.instantiate() as Drone
		follower.slot = _drones.size()
		play.actors.add_child(follower)
		follower.position = Vector2(get_midpoint().x - follower.width() * 0.5, Main.HEIGHT)
		_drones.append(follower)
	while _drones.size() > droneCount:
		var extra: Node = _drones.pop_back()
		extra.queue_free()
	for i in _drones.size():
		var follower := _drones[i] as Drone
		follower.slot = i
		follower.slotCount = droneCount
		follower.target_slot = i


func drones_departing() -> bool:
	for d in _drones:
		if (d as Drone).departing:
			return true
	return false
