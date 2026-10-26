class_name Actor
extends Node2D

var sprite: Sprite2D
var velocity := Vector2.ZERO
var alive: bool = true
var exists: bool = true
var isDead: bool = false
var angle: float = 0.0

var _anim_frames: Array = []
var _anim_time: float = 0.0
var _anim_playing: bool = false
var _exists_timer: float = -1.0
var _flash_time: float = 0.0


static var _tex_cache := {}

static func load_texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var res_path := path if path.begins_with("res://") else "res://" + path
	var tex := load(res_path) as Texture2D
	if tex == null and res_path.ends_with(".png"):
		tex = load(res_path.trim_suffix(".png") + ".jpg") as Texture2D
	if tex == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 0, 1, 1))
		tex = ImageTexture.create_from_image(img)
		push_warning("Missing texture: " + path)
	_tex_cache[path] = tex
	return tex


func use_graphic(path: String, frame_w: int = 0, frame_h: int = 0) -> void:
	if sprite == null:
		sprite = get_node("Sprite") as Sprite2D
	var res_path := "res://" + path
	if sprite.texture == null or sprite.texture.resource_path != res_path:
		sprite.texture = load_texture(path)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if frame_w > 0 and frame_h > 0 and sprite.texture != null:
		var tw: float = sprite.texture.get_width()
		var th: float = sprite.texture.get_height()
		if int(tw) % frame_w == 0 and int(th) % frame_h == 0:
			sprite.hframes = int(tw) / frame_w
			sprite.vframes = int(th) / frame_h
	sprite.centered = true
	_pivot_sprite()


func _pivot_sprite() -> void:
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.position = frame_size() * 0.5


func frame_size() -> Vector2:
	if sprite == null or sprite.texture == null:
		return Vector2(32, 32)
	return Vector2(
		float(sprite.texture.get_width()) / sprite.hframes,
		float(sprite.texture.get_height()) / sprite.vframes
	) * sprite.scale


func width() -> float:
	return frame_size().x


func height() -> float:
	return frame_size().y


func get_midpoint() -> Vector2:
	return position + frame_size() * 0.5


func rect() -> Rect2:
	return Rect2(position, frame_size())


func set_angle(deg: float) -> void:
	angle = deg
	if sprite:
		sprite.rotation_degrees = deg


func kill() -> void:
	alive = false


func play_frames(frames: Array, fps: float = 24.0) -> void:
	_anim_frames = frames
	_anim_fps = fps
	_anim_time = 0.0
	_anim_playing = frames.size() > 0
	if _anim_playing:
		sprite.frame = int(frames[0])


var _anim_fps: float = 24.0


func flash(color: Color, duration: float) -> void:
	if sprite:
		sprite.modulate = color
	_flash_time = duration


func hide_after(duration: float) -> void:
	exists = true
	visible = true
	_exists_timer = duration


func update(elapsed: float) -> void:
	if not exists:
		return
	position += velocity * elapsed
	if _anim_playing:
		_anim_time += elapsed
		var idx := int(_anim_time * _anim_fps)
		if idx >= _anim_frames.size():
			_anim_playing = false
			sprite.frame = int(_anim_frames[_anim_frames.size() - 1])
		else:
			sprite.frame = int(_anim_frames[idx])
	if _flash_time > 0.0:
		_flash_time -= elapsed
		if _flash_time <= 0.0 and sprite:
			sprite.modulate = Color.WHITE
	if _exists_timer > 0.0:
		_exists_timer -= elapsed
		if _exists_timer <= 0.0:
			exists = false
			visible = false


func is_on_screen() -> bool:
	var r := rect()
	return r.intersects(Rect2(0, 0, Main.WIDTH, Main.HEIGHT))
