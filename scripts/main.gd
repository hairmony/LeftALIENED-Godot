class_name Main
extends Node2D

const WIDTH: int = 640
const HEIGHT: int = 360
const SAVE_PATH: String = "user://LeftAliened.cfg"

static var current: Main
static var bg_y: float = 0.0
static var endless: bool = false
static var using_controller: bool = false
static var using_touch: bool = false
static var pad: int = -1

@export var mouse_idle_hide_seconds: float = 2.0
var _mouse_idle: float = 0.0
var _nav_lock_until: int = 0
var _touch_until: int = 0
var _pad: int = -1

var music_volume: float = 1.0
var sfx_volume: float = 1.0
var state: Node
var _pending_state: String = ""
var _swap_queued: bool = false

var music: AudioStreamPlayer
var music_base: float = 1.0
var _music_fade: Tween
var _fade_callback: bool = false
var _audio_cache := {}


func _ready() -> void:
	var win := get_window()
	win.size_changed.connect(_fit_screen)
	_fit_screen()
	call_deferred("_fit_screen")
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
	_choose_pad()
	Input.joy_connection_changed.connect(func(_device, _connected): _choose_pad())
	using_touch = OS.has_feature("mobile")
	ControlsState.load_bindings()
	RunStats.load_run()
	change_state("menu")


func _fit_screen() -> void:
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_size = Vector2i(WIDTH, HEIGHT)


func _bind_ui_joypad(action: String, button: JoyButton) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == button:
			return
	var joy := InputEventJoypadButton.new()
	joy.button_index = button
	InputMap.action_add_event(action, joy)


func _process(delta: float) -> void:
	if _play_hides_cursor():
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and mouse_idle_hide_seconds > 0.0:
		_mouse_idle += delta
		if _mouse_idle >= mouse_idle_hide_seconds:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if using_controller and not ControlsState.listening:
		_ensure_button_focus()


func _choose_pad() -> void:
	var pads := Input.get_connected_joypads()
	var sony := -1
	var plain := -1
	for id in pads:
		var info := Input.get_joy_info(id)
		var vendor := int(info.get("vendor_id", 0))
		var joy_name := Input.get_joy_name(id).to_lower()
		if vendor == 0x054C or "dualsense" in joy_name or "dualshock" in joy_name or "ps5" in joy_name or "sony" in joy_name:
			sony = id
		elif "xinput" in joy_name or "xbox 360" in joy_name:
			continue
		elif plain < 0:
			plain = id
	if sony >= 0:
		_pad = sony
	elif plain >= 0:
		_pad = plain
	elif pads.size() > 0:
		_pad = pads[0]
	else:
		_pad = -1
	pad = _pad


func _repeat_nav(event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return false
	if not event.is_pressed() or event.is_echo():
		return false
	if not (event.is_action("ui_up") or event.is_action("ui_down") or event.is_action("ui_left") or event.is_action("ui_right")):
		return false
	var now := Time.get_ticks_msec()
	if now < _nav_lock_until:
		get_viewport().set_input_as_handled()
		return true
	_nav_lock_until = now + 50
	return false


func _foreign_pad(event: InputEvent) -> bool:
	if _pad < 0:
		return false
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return event.device >= 0 and event.device != _pad
	return false


func _play_hides_cursor() -> bool:
	return PlayState.current != null and not PauseState.isPaused and OptionsState.hides_play_cursor()


func _show_mouse() -> void:
	if _play_hides_cursor():
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		return
	_mouse_idle = 0.0
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if (event is InputEventMouseMotion and event.relative.length() > 0.0) or (event is InputEventMouseButton and event.pressed):
		_show_mouse()
	if _foreign_pad(event):
		get_viewport().set_input_as_handled()
		return
	if not _option_popup_visible() and _repeat_nav(event):
		return
	if ControlsState.listening:
		return
	var was_controller := using_controller
	var was_touch := using_touch
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		using_controller = false
		using_touch = true
		_touch_until = Time.get_ticks_msec() + 300
	elif event is InputEventJoypadButton and event.pressed:
		using_controller = true
		using_touch = false
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= 0.5:
		using_controller = true
		using_touch = false
	elif event is InputEventKey and event.pressed and not event.is_echo():
		using_controller = false
		using_touch = false
	elif (event is InputEventMouseButton and event.pressed) or (event is InputEventMouseMotion and event.relative.length() > 0.0):
		if event.device < 0 or Time.get_ticks_msec() < _touch_until:
			using_controller = false
			using_touch = true
		else:
			using_controller = false
			using_touch = false
	if using_controller != was_controller:
		if using_controller:
			focus_ui()
		else:
			get_viewport().gui_release_focus()
	if using_touch != was_touch:
		ControllerIcons.refresh()
	if event.is_echo() or not event.is_pressed():
		return
	var prompt := _prompt_for_event(event)
	if prompt != null:
		prompt.pressed.emit()
		get_viewport().set_input_as_handled()
		return
	if event.is_action("ui_cancel"):
		if _option_popup_visible():
			return
		var back := _top_button(self, ["BackButton", "CloseButton", "ContinueButton"])
		if back == null or back.disabled or not back.is_visible_in_tree():
			return
		back.pressed.emit()
		get_viewport().set_input_as_handled()
		return
	if not using_controller:
		return
	if event.is_action("ui_accept"):
		var focus := get_viewport().gui_get_focus_owner()
		if focus is OptionButton:
			return
		if focus is BaseButton:
			var button := focus as BaseButton
			if button.disabled or not button.is_visible_in_tree():
				return
			if button.toggle_mode:
				button.set_pressed(not button.button_pressed)
				if button.get_class() == "Button":
					button.pressed.emit()
			else:
				button.pressed.emit()
			get_viewport().set_input_as_handled()


func focus_ui() -> void:
	_ensure_button_focus()


func _keeps_controller_focus(owner: Control) -> bool:
	if owner == null or not owner.is_visible_in_tree() or owner.focus_mode == Control.FOCUS_NONE:
		return false
	if owner is BaseButton:
		return not (owner as BaseButton).disabled
	if owner is Tree:
		return true
	return owner is Range


func _option_popup_visible() -> bool:
	return _find_option_popup(self)


func _find_option_popup(node: Node) -> bool:
	if node is OptionButton:
		var popup := (node as OptionButton).get_popup()
		if popup != null and popup.visible:
			return true
	for child in node.get_children():
		if _find_option_popup(child):
			return true
	return false


func _ensure_button_focus() -> void:
	if _option_popup_visible():
		return
	var owner := get_viewport().gui_get_focus_owner()
	if _keeps_controller_focus(owner):
		return
	var button := _first_button(self)
	if button != null:
		button.grab_focus()


func _first_button(node: Node) -> Button:
	var best: Button = null
	if node is Button:
		var button := node as Button
		if button.is_visible_in_tree() and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			best = button
	for child in node.get_children():
		var found := _first_button(child)
		if found != null and (best == null or _is_before(found, best)):
			best = found
	return best


func _is_before(a: Control, b: Control) -> bool:
	var ap := a.get_global_rect().position
	var bp := b.get_global_rect().position
	if absf(ap.y - bp.y) > 4.0:
		return ap.y < bp.y
	return ap.x < bp.x


func _prompt_for_event(event: InputEvent) -> PromptButton:
	var best: PromptButton = null
	for node in get_tree().get_nodes_in_group("prompt_buttons"):
		var prompt := node as PromptButton
		if prompt == null or prompt.prompt_action == &"":
			continue
		if prompt.disabled or not prompt.is_visible_in_tree():
			continue
		if not InputMap.has_action(prompt.prompt_action):
			continue
		if event.is_action(prompt.prompt_action):
			best = prompt
	return best


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


static func scene(path: String) -> PackedScene:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene


func change_state(which: String) -> void:
	_pending_state = which
	if _swap_queued:
		return
	_swap_queued = true
	call_deferred("_swap_state")


func _swap_state() -> void:
	_swap_queued = false
	var which := _pending_state
	if state:
		var old := state
		state = null
		old.free()
	var path := "res://scenes/menu.tscn"
	if which == "play":
		path = "res://scenes/endless.tscn" if endless else "res://scenes/classic.tscn"
	scene("res://scenes/ui_button.tscn")
	if which == "play":
		scene("res://scenes/play.tscn")
	state = scene(path).instantiate()
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
