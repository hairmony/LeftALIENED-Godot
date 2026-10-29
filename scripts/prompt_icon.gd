class_name PromptIcon
extends TextureRect

@export_custom(PROPERTY_HINT_INPUT_NAME, "show_builtin,loose_mode") var prompt_action: StringName = &"":
	set(value):
		prompt_action = value
		if is_node_ready():
			_refresh_prompt()


func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ControllerIcons.input_type_changed.connect(func(_type, _controller): _refresh_prompt())
	_refresh_prompt()


func _refresh_prompt() -> void:
	var tex: Texture2D = null
	if prompt_action != &"" and InputMap.has_action(prompt_action):
		var pad := ControllerIcons.get_last_input_type() == ControllerIcons.InputType.CONTROLLER
		var type := ControllerIcons.InputType.CONTROLLER if pad else ControllerIcons.InputType.KEYBOARD_MOUSE
		if _has_events(pad):
			tex = ControllerIcons.parse_path(str(prompt_action), type) as Texture2D
	texture = tex
	visible = tex != null


func _has_events(pad: bool) -> bool:
	for ev in InputMap.action_get_events(prompt_action):
		var is_pad := ev is InputEventJoypadButton or ev is InputEventJoypadMotion
		if is_pad == pad:
			return true
	return false
