class_name PromptButton
extends Button

@export_custom(PROPERTY_HINT_INPUT_NAME, "show_builtin,loose_mode") var prompt_action: StringName = &"ui_cancel":
	set(value):
		prompt_action = value
		if is_node_ready():
			_refresh_prompt()

var _caption: String = ""
var _row: HBoxContainer
var _icon: TextureRect
var _label: Label


func _ready() -> void:
	add_to_group("prompt_buttons")
	_caption = text
	text = ""
	_row = HBoxContainer.new()
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 4)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(20, 20)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.visible = false
	_label = Label.new()
	_label.text = _caption
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_icon)
	_row.add_child(_label)
	add_child(_row)
	ControllerIcons.input_type_changed.connect(func(_type, _controller): _refresh_prompt())
	_refresh_prompt()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW or what == NOTIFICATION_THEME_CHANGED:
		_sync_caption_style()


func _refresh_prompt() -> void:
	if _icon == null:
		return
	var tex: Texture2D = null
	if not Main.using_touch and prompt_action != &"" and InputMap.has_action(prompt_action):
		var pad := ControllerIcons.get_last_input_type() == ControllerIcons.InputType.CONTROLLER
		var type := ControllerIcons.InputType.CONTROLLER if pad else ControllerIcons.InputType.KEYBOARD_MOUSE
		if _has_events(pad):
			tex = ControllerIcons.parse_path(str(prompt_action), type) as Texture2D
	_icon.texture = tex
	_icon.visible = tex != null
	_sync_caption_style()


func _has_events(pad: bool) -> bool:
	for ev in InputMap.action_get_events(prompt_action):
		var is_pad := ev is InputEventJoypadButton or ev is InputEventJoypadMotion
		if is_pad == pad:
			return true
	return false


func _sync_caption_style() -> void:
	if _label == null:
		return
	var color_name := "font_color"
	if disabled:
		color_name = "font_disabled_color"
	elif button_pressed:
		color_name = "font_pressed_color"
	elif has_focus():
		color_name = "font_focus_color"
	elif is_hovered():
		color_name = "font_hover_color"
	_label.add_theme_color_override("font_color", get_theme_color(color_name))
	_label.add_theme_font_override("font", get_theme_font("font"))
	_label.add_theme_font_size_override("font_size", get_theme_font_size("font_size"))
