extends Node

const width: int = 640
const height: int = 360
const SAVE_PATH: String = "user://LeftAliened.cfg"

var volume: float = 1.0
var bg_y: float = 0.0

var mouse_delta := Vector2.ZERO
var mouse_position := Vector2.ZERO

var _prev_mouse := Vector2.ZERO

var _tex_cache := {}
var _audio_cache := {}

var music: AudioStreamPlayer
var music_base: float = 1.0
var _music_fade: Tween
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	process_priority = -100
	music = AudioStreamPlayer.new()
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)


func _process(_delta: float) -> void:
	mouse_position = get_viewport().get_mouse_position()
	mouse_delta = mouse_position - _prev_mouse
	_prev_mouse = mouse_position


func randf_range(a: float, b: float) -> float:
	return rng.randf_range(a, b)


func randi_range(a: int, b: int) -> int:
	return rng.randi_range(a, b)


func load_texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var img := Image.new()
	var err := img.load(ProjectSettings.globalize_path(path))
	if err != OK and path.ends_with(".png"):
		err = img.load(ProjectSettings.globalize_path(path.trim_suffix(".png") + ".jpg"))
	if err != OK:
		img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 0, 1, 1))
		push_warning("Missing texture: " + path)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[path] = tex
	return tex


func load_audio(path: String) -> AudioStream:
	if path == "":
		return null
	if _audio_cache.has(path):
		return _audio_cache[path]
	var stream: AudioStream = AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(path))
	if stream == null:
		push_warning("Missing audio: " + path)
		return null
	_audio_cache[path] = stream
	return stream


func play_sound(path: String, vol: float = 1.0) -> void:
	var stream := load_audio(path)
	if stream == null:
		return
	stream = stream.duplicate()
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = stream
	player.volume_db = _db(vol * volume)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


var _fade_callback: bool = false

func play_music(path: String, vol: float) -> void:
	if _music_fade and not _fade_callback:
		_music_fade.kill()
	_music_fade = null
	if path == "":
		music.stop()
		music.stream = null
		music_base = 0.0
		return
	var stream := load_audio(path)
	if stream == null:
		return
	stream = stream.duplicate()
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	music.stream = stream
	music_base = vol
	_apply_music_volume()
	music.play()


func fade_music_then(path: String, vol: float) -> void:
	if music.stream == null or not music.playing:
		play_music(path, vol)
		return
	if _music_fade:
		_music_fade.kill()
	var start := music_base
	_music_fade = create_tween()
	_music_fade.tween_method(func(v: float) -> void:
		music_base = v
		_apply_music_volume()
	, start, 0.0, 1.0)
	_music_fade.tween_callback(func() -> void:
		_fade_callback = true
		play_music(path, vol)
		_fade_callback = false
	)


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_apply_music_volume()


func _apply_music_volume() -> void:
	music.volume_db = _db(music_base * volume)


func _db(linear: float) -> float:
	if linear <= 0.0001:
		return -80.0
	return linear_to_db(linear)


func ship_choice() -> Variant:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return null
	if not cf.has_section_key("data", "shipChoice"):
		return null
	return cf.get_value("data", "shipChoice")


func save_ship_choice(n: int) -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("data", "shipChoice", n)
	cf.save(SAVE_PATH)


func goto_named(which: String) -> void:
	var main := get_tree().root.get_node("Main")
	main.change_state(which)
