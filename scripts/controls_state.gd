class_name ControlsState
extends Control

const SAVE_PATH: String = "user://LeftAliened.cfg"
const ACTIONS: Array[String] = [
	"move_left", "move_right", "move_up", "move_down",
	"aim_left", "aim_right", "aim_up", "aim_down",
	"shoot", "dodge", "super", "restart"
]
const NAMES: Array[String] = [
	"Move Left", "Move Right", "Move Up", "Move Down",
	"Aim Left", "Aim Right", "Aim Up", "Aim Down",
	"Shoot", "Dodge", "Super", "Restart"
]

static var listening: bool = false
static var _listener: ControlsState

var on_closed := Callable()
var _listen_action: String = ""
var _listen_index: int = -1
var _buttons: Dictionary = {}
var _right_drag: bool = false
var _right_drag_y: float = 0.0
var _scroll_carry: float = 0.0
var _focus_lock_until: int = 0
var _stick_armed: bool = false
var _ui_button: PackedScene

@onready var rows: VBoxContainer = $Margin/Scroll/Rows
@onready var scroll: ScrollContainer = $Margin/Scroll


func _back_button() -> Button:
	var ui := get_parent()
	if ui != null:
		ui = ui.get_parent()
	if ui != null:
		return ui.get_node_or_null("BackButton") as Button
	return null


func _reset_button() -> Button:
	var ui := get_parent()
	if ui != null:
		ui = ui.get_parent()
	if ui != null:
		return ui.get_node_or_null("ResetButton") as Button
	return null


static func load_bindings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		var changed := false
		if cf.has_section("controls"):
			cf.erase_section("controls")
			changed = true
		if cf.has_section("control_defaults"):
			cf.erase_section("control_defaults")
			changed = true
		if changed:
			cf.save(SAVE_PATH)
	GuideControls.install()


static func action_events(action: String) -> Array:
	var row: Array = [null, null, null, null]
	if not InputMap.has_action(action):
		return row
	var kbm := 0
	var pad := 0
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey or ev is InputEventMouseButton:
			if kbm < 2:
				row[kbm] = ev
				kbm += 1
		elif ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			if pad < 2:
				row[2 + pad] = ev
				pad += 1
	return row


static func _write_action(action: String, row: Array) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for ev in row:
		if ev != null:
			InputMap.action_add_event(action, ev)


static func _encode(ev: InputEvent) -> String:
	if ev == null:
		return "-"
	if ev is InputEventKey:
		return "key:%d" % (ev as InputEventKey).physical_keycode
	if ev is InputEventMouseButton:
		return "mouse:%d" % (ev as InputEventMouseButton).button_index
	if ev is InputEventJoypadButton:
		return "joy:%d" % (ev as InputEventJoypadButton).button_index
	if ev is InputEventJoypadMotion:
		var motion := ev as InputEventJoypadMotion
		return "axis:%d:%d" % [motion.axis, 1 if motion.axis_value >= 0.0 else -1]
	return "-"


func _ready() -> void:
	_listener = self
	_ui_button = Main.scene("res://scenes/ui_button.tscn")
	load_bindings()
	for i in ACTIONS.size():
		_add_row(ACTIONS[i], NAMES[i])
	scroll.follow_focus = false
	ControllerIcons.input_type_changed.connect(func(_type, _controller): _refresh())


func _exit_tree() -> void:
	if _listener == self:
		_listener = null
	listening = false
	GuideControls.cancel()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if listening:
		_scroll_carry = 0.0
		_poll_stick_bind()
		return
	var axis := ui_scroll_axis()
	var scroll := _current_scroll()
	if scroll == null or absf(axis) < 0.01:
		_scroll_carry = 0.0
		return
	_scroll_carry += axis * 200.0 * delta
	var step := int(_scroll_carry)
	if step == 0:
		return
	_scroll_carry -= float(step)
	scroll.scroll_vertical += step


func _current_scroll() -> ScrollContainer:
	return scroll


static func ui_scroll_axis() -> float:
	var joy := _joy_scroll_axis()
	if absf(joy) >= 0.15:
		return clampf(joy, -1.0, 1.0)
	return Input.get_axis("ui_text_scroll_up", "ui_text_scroll_down")


static func _joy_scroll_axis() -> float:
	var value := 0.0
	for device in Input.get_connected_joypads():
		value += _joy_action_axis("ui_text_scroll_down", device)
		value -= _joy_action_axis("ui_text_scroll_up", device)
	return value


static func _joy_action_axis(action: String, device: int) -> float:
	var best := 0.0
	for ev in InputMap.action_get_events(action):
		if ev is not InputEventJoypadMotion:
			continue
		var motion := ev as InputEventJoypadMotion
		if motion.device >= 0 and motion.device != device:
			continue
		var raw := Input.get_joy_axis(device, motion.axis)
		if motion.axis_value < 0.0:
			raw = -raw
		if raw > best:
			best = raw
	return best


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not listening and _right_scroll(event):
		return
	if not listening and _move_focus(event):
		return
	if not listening or GuideControls.detecting():
		return
	var bound := _event_for_slot(event, _listen_index)
	if bound == null:
		if _blocks_while_listening(event):
			get_viewport().set_input_as_handled()
		return
	_set_slot(_listen_action, _listen_index, bound)
	_stop_listen()
	get_viewport().set_input_as_handled()


func _move_focus(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	var step := Vector2i.ZERO
	if event.is_action("ui_up"):
		step = Vector2i.UP
	elif event.is_action("ui_down"):
		step = Vector2i.DOWN
	elif event.is_action("ui_left"):
		step = Vector2i.LEFT
	elif event.is_action("ui_right"):
		step = Vector2i.RIGHT
	else:
		return false
	var now := Time.get_ticks_msec()
	if now < _focus_lock_until:
		get_viewport().set_input_as_handled()
		return true
	_focus_lock_until = now + 50
	var owner := get_viewport().gui_get_focus_owner()
	var slot := _find_slot(owner)
	var back := _back_button()
	var reset := _reset_button()
	if slot.x < 0:
		if owner == back and step == Vector2i.RIGHT and reset != null and reset.visible:
			reset.grab_focus()
		elif owner == reset and step == Vector2i.LEFT and back != null:
			back.grab_focus()
		elif owner == back and step == Vector2i.UP:
			_focus_slot(ACTIONS.size() - 1, 0)
		elif owner == reset and step == Vector2i.UP:
			_focus_slot(ACTIONS.size() - 1, 0)
		elif owner == null:
			_focus_slot(0, 0)
	else:
		var row := int(slot.x) + step.y
		var col := int(slot.y) + step.x
		if row < 0:
			pass
		elif row >= ACTIONS.size():
			if reset != null and reset.visible:
				reset.grab_focus()
			elif back != null:
				back.grab_focus()
		else:
			_focus_slot(row, clampi(col, 0, 2))
	get_viewport().set_input_as_handled()
	return true


func _find_slot(owner: Control) -> Vector2i:
	if owner == null:
		return Vector2i(-1, -1)
	for row in ACTIONS.size():
		var buttons: Array = _buttons[ACTIONS[row]]
		for i in buttons.size():
			if buttons[i] == owner:
				return Vector2i(row, i)
	return Vector2i(-1, -1)


func _focus_slot(row: int, column: int) -> void:
	var buttons: Array = _buttons[ACTIONS[row]]
	var index := clampi(column, 0, buttons.size() - 1)
	var button := buttons[index] as Button
	button.grab_focus()
	scroll.ensure_control_visible(button)


func _blocks_while_listening(event: InputEvent) -> bool:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		return true
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		return true
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) >= 0.5:
		return true
	return false


func _stop_listen() -> void:
	listening = false
	_listen_index = -1
	_stick_armed = false
	_set_menu_locked(false)
	_refresh()


func _options_state() -> OptionsState:
	var n := get_parent()
	while n != null:
		if n is OptionsState:
			return n
		n = n.get_parent()
	return null


func _set_menu_locked(locked: bool) -> void:
	var back := _back_button()
	var reset := _reset_button()
	if back != null:
		back.disabled = locked
	if reset != null:
		reset.disabled = locked
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP
	var outer := get_parent() as TabContainer
	if outer != null:
		outer.mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP
	var options := _options_state()
	if options != null:
		options.set_tabs_locked(locked)
	for action in _buttons:
		var buttons: Array = _buttons[action]
		for i in buttons.size():
			var button := buttons[i] as Button
			var current: bool = locked and str(action) == _listen_action and i == _listen_index
			button.disabled = locked and not current


func _right_scroll(event: InputEvent) -> bool:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and scroll.get_global_rect().has_point(event.global_position):
			_right_drag = true
			_right_drag_y = event.global_position.y
			get_viewport().set_input_as_handled()
			return true
		_right_drag = false
	elif event is InputEventMouseMotion and _right_drag:
		scroll.scroll_vertical += int(_right_drag_y - event.global_position.y)
		_right_drag_y = event.global_position.y
		get_viewport().set_input_as_handled()
		return true
	return false


func _add_row(action: String, title: String) -> void:
	var buttons: Array[Button] = []
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var label_box := MarginContainer.new()
	label_box.add_theme_constant_override("margin_left", 8)
	var label := Label.new()
	label.text = title
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label_box.add_child(label)
	row.add_child(label_box)
	var button_size := Vector2.ZERO
	for i in 3:
		var button := _ui_button.instantiate() as Button
		if button_size == Vector2.ZERO:
			button_size = Vector2(button.offset_right - button.offset_left, button.offset_bottom - button.offset_top)
			if button_size.x > 0.0 and button_size.y > 0.0:
				label_box.custom_minimum_size = button_size
		if button_size.x > 0.0 and button_size.y > 0.0:
			button.custom_minimum_size = button_size
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.clip_text = true
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.toggle_mode = true
		var icon_rect := TextureRect.new()
		icon_rect.name = "BindIcon"
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_preset(Control.PRESET_CENTER)
		icon_rect.offset_left = -10.0
		icon_rect.offset_top = -10.0
		icon_rect.offset_right = 10.0
		icon_rect.offset_bottom = 10.0
		icon_rect.visible = false
		button.add_child(icon_rect)
		button.pressed.connect(_begin_listen.bind(action, i))
		row.add_child(button)
		buttons.append(button)
	rows.add_child(row)
	_buttons[action] = buttons
	_refresh_row(action)


func _begin_listen(action: String, index: int) -> void:
	listening = true
	_listen_action = action
	_listen_index = index
	_set_menu_locked(true)
	_stick_armed = false
	_refresh()
	if GuideControls.ready() and index < 2:
		GuideControls.begin(action, index)


func _poll_stick_bind() -> void:
	if _listen_index < 2:
		return
	var held := -1
	var axis := -1
	var value := 0.0
	for device in Input.get_connected_joypads():
		for button in JOY_BUTTON_MAX:
			if Input.is_joy_button_pressed(device, button):
				held = button
		for i in JOY_AXIS_MAX:
			var raw := Input.get_joy_axis(device, i)
			if absf(raw) > absf(value):
				value = raw
				axis = i
	if not _stick_armed:
		if held < 0 and absf(value) < 0.35:
			_stick_armed = true
		return
	var action := _listen_action
	var index := _listen_index
	if held >= 0:
		var joy := InputEventJoypadButton.new()
		joy.button_index = held as JoyButton
		_set_slot(action, index, joy)
	elif axis >= 0 and absf(value) >= 0.65:
		var motion := InputEventJoypadMotion.new()
		motion.axis = axis as JoyAxis
		motion.axis_value = -1.0 if value < 0.0 else 1.0
		_set_slot(action, index, motion)
	else:
		return
	GuideControls.cancel()
	_stop_listen()


func _refresh() -> void:
	for action in ACTIONS:
		_refresh_row(action)


func _refresh_row(action: String) -> void:
	var buttons: Array = _buttons[action]
	var row: Array = action_events(action)
	for i in buttons.size():
		var button: Button = buttons[i]
		var icon_rect := button.get_node("BindIcon") as TextureRect
		button.icon = null
		button.set_pressed_no_signal(listening and action == _listen_action and i == _listen_index)
		if listening and action == _listen_action and i == _listen_index:
			button.text = "..."
			icon_rect.visible = false
		else:
			var icon := icon_for(row[i])
			icon_rect.texture = icon
			icon_rect.visible = icon != null
			button.text = "" if icon != null else _event_text(row[i])


func _set_slot(action: String, index: int, event: InputEvent) -> void:
	for other in ACTIONS:
		var row := action_events(other)
		var changed := false
		for i in 4:
			if row[i] != null and _events_match(row[i], event):
				row[i] = null
				changed = true
		if other == action:
			row[index] = event
			changed = true
		if changed:
			_write_action(other, row)


func _event_for_slot(event: InputEvent, index: int) -> InputEvent:
	var kbm: bool = index < 2
	if kbm and event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			_stop_listen()
			get_viewport().set_input_as_handled()
			return null
		var key := InputEventKey.new()
		key.physical_keycode = (event as InputEventKey).physical_keycode
		return key
	if kbm and event is InputEventMouseButton and event.pressed:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = (event as InputEventMouseButton).button_index
		return mouse
	if not kbm and event is InputEventJoypadButton and event.pressed:
		var joy := InputEventJoypadButton.new()
		joy.button_index = (event as InputEventJoypadButton).button_index
		return joy
	if not kbm and event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) >= 0.5:
		var axis := InputEventJoypadMotion.new()
		axis.axis = (event as InputEventJoypadMotion).axis
		axis.axis_value = 1.0 if (event as InputEventJoypadMotion).axis_value > 0.0 else -1.0
		return axis
	return null


func _events_match(a: InputEvent, b: InputEvent) -> bool:
	return _encode(a) == _encode(b)


static func icon_for(ev: InputEvent) -> Texture2D:
	if ev == null:
		return null
	return ControllerIcons.parse_event(ev) as Texture2D


static func prompt_text(action: String, suffix: String) -> String:
	if Main.using_touch:
		return suffix
	var want_pad := ControllerIcons.get_last_input_type() == ControllerIcons.InputType.CONTROLLER
	var ev := _first_event(action, want_pad)
	if ev == null:
		ev = _first_event(action, not want_pad)
	var icon := icon_for(ev)
	if icon != null and icon.resource_path != "":
		return "[img=32]%s[/img] %s" % [icon.resource_path, suffix]
	var word := _event_text(ev) if ev != null else ""
	if word == "" or word == "-":
		return suffix
	return word + " " + suffix


static func _first_event(action: String, pad: bool) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for ev in InputMap.action_get_events(action):
		var is_pad := ev is InputEventJoypadButton or ev is InputEventJoypadMotion
		if is_pad == pad:
			return ev
	return null


static func primary_text(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey or ev is InputEventMouseButton:
			return _event_text(ev)
	return ""


static func _event_text(ev: InputEvent) -> String:
	if ev == null:
		return "-"
	if ev is InputEventKey:
		return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "Left Click"
			MOUSE_BUTTON_RIGHT:
				return "Right Click"
			MOUSE_BUTTON_MIDDLE:
				return "Middle Click"
			_:
				return "Mouse %d" % (ev as InputEventMouseButton).button_index
	if ev is InputEventJoypadButton:
		return _joy_button_text((ev as InputEventJoypadButton).button_index)
	if ev is InputEventJoypadMotion:
		return _joy_axis_text((ev as InputEventJoypadMotion).axis, (ev as InputEventJoypadMotion).axis_value >= 0.0)
	return "-"


static func _joy_button_text(index: int) -> String:
	match index:
		JOY_BUTTON_A:
			return "Cross"
		JOY_BUTTON_B:
			return "Circle"
		JOY_BUTTON_X:
			return "Square"
		JOY_BUTTON_Y:
			return "Triangle"
		JOY_BUTTON_LEFT_SHOULDER:
			return "L1"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "R1"
		JOY_BUTTON_LEFT_STICK:
			return "L3"
		JOY_BUTTON_RIGHT_STICK:
			return "R3"
		JOY_BUTTON_BACK:
			return "Back"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_DPAD_UP:
			return "D-Pad Up"
		JOY_BUTTON_DPAD_DOWN:
			return "D-Pad Down"
		JOY_BUTTON_DPAD_LEFT:
			return "D-Pad Left"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-Pad Right"
		_:
			return "Button %d" % index


static func _joy_axis_text(axis: int, positive: bool) -> String:
	match axis:
		JOY_AXIS_LEFT_X:
			return "L Stick Right" if positive else "L Stick Left"
		JOY_AXIS_LEFT_Y:
			return "L Stick Down" if positive else "L Stick Up"
		JOY_AXIS_RIGHT_X:
			return "R Stick Right" if positive else "R Stick Left"
		JOY_AXIS_RIGHT_Y:
			return "R Stick Down" if positive else "R Stick Up"
		JOY_AXIS_TRIGGER_LEFT:
			return "L2"
		JOY_AXIS_TRIGGER_RIGHT:
			return "R2"
		_:
			return "Axis %d" % axis


func backToMenu() -> void:
	_stop_listen()
	var closed := on_closed
	on_closed = Callable()
	if closed.is_valid():
		closed.call()
	queue_free()


func _on_guide_input(action: String, index: int, event: InputEvent) -> void:
	if event == null:
		_stop_listen()
		return
	_set_slot(action, index, event)
	_stop_listen()


func resetBindings() -> void:
	_stop_listen()
	InputMap.load_from_project_settings()
	if Main.current != null:
		Main.current._bind_ui_joypad("ui_accept", JOY_BUTTON_A)
		Main.current._bind_ui_joypad("ui_cancel", JOY_BUTTON_B)
	GuideControls.restore_defaults()
	_refresh()
