class_name PauseState
extends CanvasLayer

static var isPaused: bool = false

var _armed: bool = false
var _options: OptionsState


func _ready() -> void:
	isPaused = true
	if Main.using_controller:
		($UI/ContinueButton as Button).grab_focus()


func _exit_tree() -> void:
	isPaused = false


func _process(_elapsed: float) -> void:
	if not _armed:
		_armed = true
		return
	# So you can also toggle with Esc key
	if Input.is_action_just_pressed("pause"):
		if is_instance_valid(_options):
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
	options.on_closed = _on_options_closed
	_options = options
	add_child(options)


func _on_options_closed() -> void:
	_options = null
	if is_inside_tree():
		_show_pause(true)
		if Main.using_controller:
			($UI/OptionsButton as Button).grab_focus()


func showRules() -> void:
	var rules := $UI/RulesText as Label
	var show_rules: bool = not rules.visible
	rules.visible = show_rules
	($UI/RulesPanel as CanvasItem).visible = show_rules


func _show_pause(show_pause: bool) -> void:
	for c in $UI.get_children():
		if c.name == "Dim":
			continue
		if c.name == "RulesText" or c.name == "RulesPanel":
			if not show_pause:
				c.visible = false
			continue
		c.visible = show_pause


func onRestart() -> void:
	isPaused = false
	Main.current.change_state("play")


func onExit() -> void:
	isPaused = false
	Main.current.play_music("", 1.0)
	Main.current.change_state("menu") #Run time bug
