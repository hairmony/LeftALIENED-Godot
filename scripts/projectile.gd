class_name Projectile
extends Actor

@export var speed: float = 275.0 #275 Projectile speed in pixel per sec
@export var angleOffset: float = 90.0

@export var bulletPenetration: float = 0.0 # How many things it can survive hitting


func setup(X: float, Y: float, Angle: float) -> void:
	if sprite == null:
		sprite = get_node("Sprite") as Sprite2D
	_pivot_sprite()
	position = Vector2(X, Y)
	position.x -= width() / 2.0
	position.y -= height() / 2.0

	set_angle(Angle + angleOffset)

	# Set velocity and angle of projectile based on ship
	var rad := deg_to_rad(Angle)
	velocity.x = cos(rad) * speed
	velocity.y = sin(rad) * speed


func update(elapsed: float) -> void:
	super.update(elapsed)
	if not exists:
		return
	if not is_on_screen():
		kill()
		exists = false
		visible = false
