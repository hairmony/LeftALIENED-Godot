class_name Drone
extends Actor

@export var speed: float = 180.0
@export var followSpeed: float = 6.0
@export var turnSpeed: float = 360.0
@export var fireRate: float = 4.0
@export var shotDelay: float = 0.2 # Shot delay is randomized between -ve and +ve of this value
@export var inaccuracy: float = 2.0 # randomly btw + and - angle
@export var targetRange: float = 200.0
@export var projectileSpeed: float = 275.0
@export var behind: float = 28.0

var _shot_scene: PackedScene

var slot: int = 0
var slotCount: int = 1
var arriving: bool = true
var departing: bool = false
var _fireTimer: float = 0.0
var _shotWait: float = 0.0


func _ready() -> void:
	_shot_scene = Main.scene("res://scenes/drone_projectile.tscn")
	sprite = get_node("Sprite") as Sprite2D
	_pivot_sprite()
	_fireTimer = float(slot) * 0.15
	_shotWait = _next_wait()


func follow(ship: Player, elapsed: float) -> void:
	var count := maxi(slotCount, 1)
	var aim := deg_to_rad(ship.angle - 90.0)
	var orbit := aim + PI * 0.5 + float(slot) * TAU / float(count)
	var goal := ship.get_midpoint() + Vector2(cos(orbit), sin(orbit)) * behind
	if departing:
		return
	if arriving:
		velocity = Vector2.ZERO
		var to_goal := goal - get_midpoint()
		var intro := ship.shipIntroSpeed * elapsed
		if to_goal.length() <= intro:
			position = goal - frame_size() * 0.5
			arriving = false
		else:
			position = get_midpoint() + to_goal.normalized() * intro - frame_size() * 0.5
		if to_goal.length() > 1.0:
			_turn_toward(rad_to_deg(atan2(to_goal.y, to_goal.x)) + 90.0, elapsed)
		return
	var gap := goal - get_midpoint()
	var desired := gap * followSpeed
	if desired.length() > speed:
		desired = desired.normalized() * speed
	var t := 1.0 - exp(-followSpeed * elapsed)
	velocity = velocity.lerp(desired, t)
	position += velocity * elapsed
	var play := PlayState.current
	var target := _nearest_target(play)
	if target != null:
		var aim_at := target.get_midpoint() - get_midpoint()
		_turn_toward(rad_to_deg(atan2(aim_at.y, aim_at.x)) + 90.0, elapsed)
	else:
		_turn_toward(ship.angle, elapsed)
	_shoot(ship, elapsed, play, target)


func fly_away(ship: Player, elapsed: float) -> void:
	departing = true
	arriving = false
	visible = true
	exists = true
	alive = true
	position.y -= ship.shipSwapSpeed * elapsed
	if position.y + height() < 0.0:
		visible = false
		exists = false
		alive = false
		departing = false


func _nearest_target(play: PlayState) -> Actor:
	if play == null:
		return null
	var best: Actor = null
	var best_dist := targetRange * targetRange
	var mid := get_midpoint()
	for a in play.asteroid:
		if a == null or not a.alive or not a.exists or a.isDead:
			continue
		var dist := mid.distance_squared_to(a.get_midpoint())
		if dist <= best_dist:
			best_dist = dist
			best = a
	return best


func _shoot(ship: Player, elapsed: float, play: PlayState, target: Actor) -> void:
	if PauseState.isPaused or not ship.alive or not ship.exists or fireRate <= 0.0 or target == null or play == null:
		return
	_fireTimer += elapsed
	if _fireTimer < _shotWait:
		return
	_fireTimer = 0.0
	_shotWait = _next_wait()
	var mid := get_midpoint()
	var aim_at := target.get_midpoint() - mid
	var angle_deg := rad_to_deg(atan2(aim_at.y, aim_at.x))
	angle_deg += randf_range(-inaccuracy, inaccuracy)
	var angle_rad := deg_to_rad(angle_deg)
	var shot := _shot_scene.instantiate() as Projectile
	shot.speed = projectileSpeed
	shot.setup(mid.x + cos(angle_rad) * 8.0, mid.y + sin(angle_rad) * 8.0, angle_deg)
	play.projectiles.append(shot)
	play.actors.add_child(shot)
	Main.current.play_sound("assets/sounds/ShootPlayer.ogg", 0.25)


func _turn_toward(target_deg: float, elapsed: float) -> void:
	var diff := wrapf(target_deg - angle, -180.0, 180.0)
	var step := turnSpeed * elapsed
	if absf(diff) <= step:
		set_angle(target_deg)
	else:
		set_angle(angle + signf(diff) * step)


func _next_wait() -> float:
	if fireRate <= 0.0:
		return 999.0
	var base := 1.0 / fireRate
	return maxf(base + randf_range(-shotDelay, shotDelay), base)
