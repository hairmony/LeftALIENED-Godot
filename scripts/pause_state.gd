class_name PauseState
extends Node

static var isPaused: bool = false

var _armed: bool = false
var _options: OptionsState
var _stats: StatisticsState


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
		if is_instance_valid(_options):
			_options.backToMenu()
		elif is_instance_valid(_stats):
			_stats.backToMenu()
		else:
			onContinue()


func onContinue() -> void:
	isPaused = not isPaused
	queue_free()


func onOptions() -> void:
	_open_options("Gameplay")


func onStats() -> void:
	if is_instance_valid(_options) or is_instance_valid(_stats):
		return
	_show_pause(false)
	_set_play_hud(false)
	var packed := Main.scene("res://scenes/statistics.tscn")
	var stats := packed.instantiate() as StatisticsState
	if stats == null:
		_show_pause(true)
		_set_play_hud(true)
		return
	stats.start_tab = "Endless" if Main.endless else "Classic"
	stats.on_closed = _on_stats_closed
	_stats = stats
	$Layer.add_child(stats)


func _open_options(tab_name: String) -> void:
	if is_instance_valid(_options):
		return
	_show_pause(false)
	var packed := Main.scene("res://scenes/options.tscn")
	var options := packed.instantiate() as OptionsState
	if options == null:
		_show_pause(true)
		return
	_set_play_hud(false)
	options.start_tab = tab_name
	options.on_closed = _on_options_closed.bind(tab_name == "Controls")
	_options = options
	$Layer.add_child(options)


func _on_options_closed(from_controls: bool = false) -> void:
	_options = null
	if is_inside_tree():
		_set_play_hud(true)
		_show_pause(true)
		if Main.using_controller:
			var button_name := "HowToPlayButton" if from_controls else "OptionsButton"
			($Layer/UI.get_node(button_name) as Button).grab_focus()


func _on_stats_closed() -> void:
	_stats = null
	if is_inside_tree():
		_set_play_hud(true)
		_show_pause(true)
		if Main.using_controller:
			($Layer/UI/HowToPlayButton as Button).grab_focus()


func _show_pause(show_pause: bool) -> void:
	for child in $Layer/UI.get_children():
		if child.name == "Dim":
			child.visible = true
			continue
		child.visible = show_pause


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
