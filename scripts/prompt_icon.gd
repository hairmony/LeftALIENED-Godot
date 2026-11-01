class_name PromptIcon
extends TextureRect

@export_custom(PROPERTY_HINT_INPUT_NAME, "show_builtin,loose_mode") var prompt_action: StringName = &"":
	set(value):
		prompt_action = value
		if is_node_ready():
			_refresh_prompt()


func _ready() -> void:
	custom_minimum_size = Vector2(20, 20)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ControllerIcons.input_type_changed.connect(func(_type, _controller): _refresh_prompt())
	_refresh_prompt()


func _refresh_prompt() -> void:
	var tex: Texture2D = null
	if not Main.using_touch and prompt_action != &"" and InputMap.has_action(prompt_action):
		var pad := ControllerIcons.get_last_input_type() == ControllerIcons.InputType.CONTROLLER
		var ev := ControlsState._first_event(str(prompt_action), pad)
		if ev == null:
			ev = ControlsState._first_event(str(prompt_action), not pad)
		tex = ControlsState.icon_for(ev)
	texture = tex
	visible = tex != null
