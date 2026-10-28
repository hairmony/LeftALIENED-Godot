class_name GuideControls
extends RefCounted

static var context: GUIDEMappingContext
static var remapper: GUIDERemapper
static var _items: Dictionary = {}
static var _pending_action: String = ""
static var _pending_index: int = -1
static var _detector: GUIDEInputDetector
static var _installed: bool = false
static var _in_callback: bool = false


static func ready() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	return tree != null and tree.root.has_node("GUIDE")


static func install() -> void:
	if _installed or not ready():
		return
	_installed = true
	context = GUIDEMappingContext.new()
	context.display_name = "Controls"
	_items.clear()
	for i in ControlsState.ACTIONS.size():
		var action_name := ControlsState.ACTIONS[i]
		var guide_action := GUIDEAction.new()
		guide_action.name = action_name
		guide_action.display_name = ControlsState.NAMES[i]
		guide_action.is_remappable = true
		guide_action.action_value_type = GUIDEAction.GUIDEActionValueType.BOOL
		var mapping := GUIDEActionMapping.new()
		mapping.action = guide_action
		var defaults: Array = ControlsState._defaults.get(action_name, [null, null, null, null])
		var saved: Array = ControlsState._slots.get(action_name, defaults)
		for slot in 4:
			var input_mapping := GUIDEInputMapping.new()
			input_mapping.is_remappable = true
			input_mapping.input = from_event(defaults[slot] if slot < defaults.size() else null)
			mapping.input_mappings.append(input_mapping)
		context.mappings.append(mapping)
		_items[action_name] = guide_action
	remapper = GUIDERemapper.new()
	remapper.initialize([context], GUIDERemappingConfig.new())
	for action_name in ControlsState.ACTIONS:
		var guide_action: GUIDEAction = _items[action_name]
		var defaults: Array = ControlsState._defaults.get(action_name, [null, null, null, null])
		var saved: Array = ControlsState._slots.get(action_name, defaults)
		var items := remapper.get_remappable_items(context, "", guide_action)
		for item in items:
			var current: InputEvent = saved[item.index] if item.index < saved.size() else null
			var original: InputEvent = defaults[item.index] if item.index < defaults.size() else null
			if _encode(current) != _encode(original):
				remapper.set_bound_input(item, from_event(current))
	var guide := (Engine.get_main_loop() as SceneTree).root.get_node("GUIDE")
	guide.enable_mapping_context(context)
	guide.set_remapping_config(remapper.get_mapping_config())
	if _detector == null:
		_detector = GUIDEInputDetector.new()
		_detector.detection_countdown_seconds = 0.0
		var escape := GUIDEInputKey.new()
		escape.key = KEY_ESCAPE
		_detector.abort_detection_on = [escape]
		guide.add_child(_detector)
		_detector.input_detected.connect(_on_detected)


static func begin(action: String, index: int) -> void:
	if _detector == null:
		return
	_pending_action = action
	_pending_index = index
	var devices: Array[GUIDEInput.DeviceType] = []
	if index < 2:
		devices.append(GUIDEInput.DeviceType.KEYBOARD)
		devices.append(GUIDEInput.DeviceType.MOUSE)
	else:
		devices.append(GUIDEInput.DeviceType.JOY)
	_detector.detect(GUIDEAction.GUIDEActionValueType.BOOL, devices)


static func detecting() -> bool:
	return _detector != null and _detector.is_detecting


static func cancel() -> void:
	if _in_callback:
		return
	_pending_action = ""
	_pending_index = -1
	if detecting():
		_detector.abort_detection()


static func restore_defaults() -> void:
	if remapper == null:
		return
	for action_name in _items:
		var items := remapper.get_remappable_items(context, "", _items[action_name])
		for item in items:
			remapper.restore_default_for(item)
	var guide := (Engine.get_main_loop() as SceneTree).root.get_node("GUIDE")
	guide.set_remapping_config(remapper.get_mapping_config())


static func _on_detected(input: GUIDEInput) -> void:
	var action := _pending_action
	var index := _pending_index
	_pending_action = ""
	_pending_index = -1
	_in_callback = true
	if action != "" and index >= 0:
		var event := to_event(input)
		if input != null and event != null:
			var guide_action: GUIDEAction = _items.get(action)
			var items := remapper.get_remappable_items(context, "", guide_action)
			var mine: GUIDERemapper.ConfigItem = null
			for item in items:
				if item.index == index:
					mine = item
					break
			if mine != null:
				for collision in remapper.get_input_collisions(mine, input):
					remapper.set_bound_input(collision, null)
				remapper.set_bound_input(mine, input)
				var guide := (Engine.get_main_loop() as SceneTree).root.get_node("GUIDE")
				guide.set_remapping_config(remapper.get_mapping_config())
		if ControlsState._listener != null:
			ControlsState._listener._on_guide_input(action, index, event)
	_in_callback = false


static func from_event(event: InputEvent) -> GUIDEInput:
	if event == null:
		return null
	if event is InputEventKey:
		var key := GUIDEInputKey.new()
		key.key = (event as InputEventKey).physical_keycode
		return key
	if event is InputEventMouseButton:
		var mouse := GUIDEInputMouseButton.new()
		mouse.button = (event as InputEventMouseButton).button_index
		return mouse
	if event is InputEventJoypadButton:
		var button := GUIDEInputJoyButton.new()
		button.button = (event as InputEventJoypadButton).button_index
		button.joy_index = -1
		return button
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var direction := GUIDEInputJoyDirection.new()
		direction.axis = motion.axis
		direction.joy_index = -1
		direction.actuation_threshold = 0.2
		direction.direction = GUIDEInputJoyDirection.Direction.NEGATIVE if motion.axis_value < 0.0 else GUIDEInputJoyDirection.Direction.POSITIVE
		return direction
	return null


static func to_event(input: GUIDEInput) -> InputEvent:
	if input == null:
		return null
	if input is GUIDEInputKey:
		var key := InputEventKey.new()
		key.physical_keycode = (input as GUIDEInputKey).key
		return key
	if input is GUIDEInputMouseButton:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = (input as GUIDEInputMouseButton).button
		return mouse
	if input is GUIDEInputJoyButton:
		var button := InputEventJoypadButton.new()
		button.button_index = (input as GUIDEInputJoyButton).button
		return button
	if input is GUIDEInputJoyDirection:
		var direction := input as GUIDEInputJoyDirection
		var motion := InputEventJoypadMotion.new()
		motion.axis = direction.axis
		motion.axis_value = -1.0 if direction.direction == GUIDEInputJoyDirection.Direction.NEGATIVE else 1.0
		return motion
	if input is GUIDEInputJoyAxis1D:
		var axis := InputEventJoypadMotion.new()
		axis.axis = (input as GUIDEInputJoyAxis1D).axis
		axis.axis_value = 1.0
		return axis
	return null


static func _encode(event: InputEvent) -> String:
	return ControlsState._encode(event)
