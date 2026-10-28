class_name PauseState
extends Node

static var isPaused: bool = false

var _armed: bool = false
var _options: OptionsState
var _controls: ControlsState


func _ready() -> void:
	isPaused = true
	if Main.using_controller:
		($Layer/UI/ContinueButton as Button).grab_focus()


func _exit_tree() -> void:
	isPaused = false
	_set_play_hud(true)


func _process(_elapsed: float) -> void:
	if not _armed:
		_armed = true
		return
	# So you can also toggle with Esc key
	if Input.is_action_just_pressed("pause"):
		if is_instance_valid(_controls):
			_controls.backToMenu()
		elif is_instance_valid(_options):
			_options.backToMenu()
		else:
			onContinue()


func onContinue() -> void:
	isPaused = not isPaused
	queue_free()


func onOptions() -> void:
	if is_instance_valid(_options):
		return
	_show_pause(false)
	var packed := load("res://scenes/options.tscn") as PackedScene
	var options := packed.instantiate() as OptionsState
	if options == null:
		_show_pause(true)
		return
	_set_play_hud(false)
	options.on_closed = _on_options_closed
	_options = options
	$Layer.add_child(options)


func _on_options_closed() -> void:
	_options = null
	if is_inside_tree():
		_set_play_hud(true)
		_show_pause(true)
		if Main.using_controller:
			($Layer/UI/OptionsButton as Button).grab_focus()


func onControls() -> void:
	if is_instance_valid(_controls):
		return
	_show_pause(false)
	var packed := load("res://scenes/controls.tscn") as PackedScene
	var controls := packed.instantiate() as ControlsState
	if controls == null:
		_show_pause(true)
		return
	_set_play_hud(false)
	controls.on_closed = _on_controls_closed
	_controls = controls
	$Layer.add_child(controls)


func _on_controls_closed() -> void:
	_controls = null
	if is_inside_tree():
		_set_play_hud(true)
		_show_pause(true)
		if Main.using_controller:
			($Layer/UI/HowToPlayButton as Button).grab_focus()


func _show_pause(show_pause: bool) -> void:
	$Layer/UI.visible = show_pause


func _set_play_hud(show_hud: bool) -> void:
	var play := get_parent()
	if play != null and play.has_node("HUD"):
		play.get_node("HUD").visible = show_hud


func onRestart() -> void:
	isPaused = false
	Main.current.change_state("play")


func onExit() -> void:
	isPaused = false
	Main.current.play_music("", 1.0)
	Main.current.change_state("menu") #Run time bug
