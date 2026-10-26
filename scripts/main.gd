class_name Main
extends Node2D

const WIDTH: int = 640
const HEIGHT: int = 360
const SAVE_PATH: String = "user://LeftAliened.cfg"

const MENU_SCENE := preload("res://scenes/menu.tscn")
const CLASSIC_SCENE := preload("res://scenes/classic.tscn")
const ENDLESS_SCENE := preload("res://scenes/endless.tscn")

static var current: Main
static var bg_y: float = 0.0
static var endless: bool = false
static var using_controller: bool = false

var music_volume: float = 1.0
var sfx_volume: float = 1.0
var state: Node

var music: AudioStreamPlayer
var music_base: float = 1.0
var _music_fade: Tween
var _fade_callback: bool = false
var _audio_cache := {}


func _ready() -> void:
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_size = Vector2i(WIDTH, HEIGHT)
	current = self
	var saved_music = OptionsState.music_choice()
	if saved_music != null:
		music_volume = clampf(float(saved_music), 0.0, 1.0)
	var saved_sfx = OptionsState.sfx_choice()
	if saved_sfx != null:
		sfx_volume = clampf(float(saved_sfx), 0.0, 1.0)
	var saved_window = OptionsState.window_mode()
	if saved_window != null:
		var saved_mode := int(saved_window)
		if saved_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or saved_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)
	_apply_bus("Music", music_volume)
	_apply_bus("SFX", sfx_volume)
	_bind_ui_joypad("ui_accept", JOY_BUTTON_A)
	_bind_ui_joypad("ui_cancel", JOY_BUTTON_B)
	change_state("menu")


func _bind_ui_joypad(action: String, button: JoyButton) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == button:
			return
	var joy := InputEventJoypadButton.new()
	joy.button_index = button
	InputMap.action_add_event(action, joy)


func _input(event: InputEvent) -> void:
	var was_controller := using_controller
	if event is InputEventJoypadButton and event.pressed:
		using_controller = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= 0.5:
		using_controller = true
	elif (event is InputEventKey and event.pressed and not event.is_echo()) or (event is InputEventMouseButton and event.pressed) or (event is InputEventMouseMotion and event.relative.length() > 0.0):
		using_controller = false
	if using_controller != was_controller:
		if using_controller:
			focus_ui()
		else:
			get_viewport().gui_release_focus()
		return
	if not using_controller or event.is_echo() or not event.is_pressed():
		return
	if event.is_action("ui_accept"):
		var focus := get_viewport().gui_get_focus_owner()
		if focus is BaseButton:
			var button := focus as BaseButton
			if button.disabled or not button.is_visible_in_tree():
				return
			if button.toggle_mode:
				button.set_pressed(not button.button_pressed)
			else:
				button.pressed.emit()
			get_viewport().set_input_as_handled()
	elif event.is_action("ui_cancel"):
		var back := _top_button(self, ["BackButton", "CloseButton", "ContinueButton"])
		if back == null or back.disabled or not back.is_visible_in_tree():
			return
		back.pressed.emit()
		get_viewport().set_input_as_handled()


func focus_ui() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner is Control and (owner as Control).is_visible_in_tree() and (owner as Control).focus_mode != Control.FOCUS_NONE:
		return
	for name in ["SuperButton", "GunsButton", "DroneButton", "ShipButton", "ContinueButton", "BackButton", "PlayButton"]:
		var button := _top_button(self, [name])
		if button != null:
			button.grab_focus()
			return


func _top_button(node: Node, names: Array) -> Button:
	for i in range(node.get_child_count() - 1, -1, -1):
		var found := _top_button(node.get_child(i), names)
		if found != null:
			return found
	if node is Button and names.has(node.name) and node.visible and not (node as Button).disabled:
		return node as Button
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen") and not event.is_echo():
		var on := DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)
		OptionsState.save_window_mode(mode)
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if current == self:
		current = null


func change_state(which: String) -> void:
	if state:
		state.queue_free()
		state = null
	var packed: PackedScene = MENU_SCENE
	if which == "play":
		packed = ENDLESS_SCENE if endless else CLASSIC_SCENE
	state = packed.instantiate()
	add_child(state)


func load_audio(path: String) -> AudioStream:
	if path == "":
		return null
	if _audio_cache.has(path):
		return _audio_cache[path]
	var res_path := path if path.begins_with("res://") else "res://" + path
	var stream := load(res_path) as AudioStream
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
	player.bus = "SFX"
	player.stream = stream
	player.volume_db = _db(vol)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


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
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
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


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus("Music", music_volume)


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus("SFX", sfx_volume)


func _apply_music_volume() -> void:
	music.volume_db = _db(music_base)


func _apply_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, _db(linear))


func _db(linear: float) -> float:
	if linear <= 0.0001:
		return -80.0
	return linear_to_db(linear)
