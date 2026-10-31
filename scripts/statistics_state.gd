class_name StatisticsState
extends Node2D

var on_closed := Callable()
var start_tab: String = "Classic"

var _tab_group := ButtonGroup.new()
var _tab: String = "Classic"
var _scroll_carry: float = 0.0
var _v_bar: VScrollBar

@onready var classicTab: Button = $UI/ClassicTab
@onready var endlessTab: Button = $UI/EndlessTab
@onready var tree: Tree = $UI/Window/Margin/StatsTree
@onready var backButton: Button = $UI/BackButton
@onready var clearButton: Button = $UI/ClearButton


func _ready() -> void:
	tree.hide_root = true
	tree.hide_folding = false
	tree.columns = 1
	tree.select_mode = Tree.SELECT_ROW
	tree.focus_mode = Control.FOCUS_ALL
	tree.item_activated.connect(_toggle_selected)
	_tab_group.allow_unpress = false
	classicTab.button_group = _tab_group
	endlessTab.button_group = _tab_group
	if not clearButton.pressed.is_connected(clearStats):
		clearButton.pressed.connect(clearStats)
	if not classicTab.toggled.is_connected(_on_classic_toggled):
		classicTab.toggled.connect(_on_classic_toggled)
	if not endlessTab.toggled.is_connected(_on_endless_toggled):
		endlessTab.toggled.connect(_on_endless_toggled)
	for i in tree.get_child_count(true):
		var child := tree.get_child(i, true)
		if child is VScrollBar:
			_v_bar = child
			break
	RunStats.load_run()
	open_tab(start_tab)
	if Main.using_controller:
		tree.grab_focus()


func _on_classic_toggled(on: bool) -> void:
	if on:
		open_tab("Classic")


func _on_endless_toggled(on: bool) -> void:
	if on:
		open_tab("Endless")


func open_tab(tab_name: String) -> void:
	_tab = "Endless" if tab_name == "Endless" else "Classic"
	classicTab.set_pressed_no_signal(_tab == "Classic")
	endlessTab.set_pressed_no_signal(_tab == "Endless")
	_refresh()


func step_tab(direction: int) -> void:
	if direction < 0:
		open_tab("Classic" if _tab == "Endless" else "Endless")
	else:
		open_tab("Endless" if _tab == "Classic" else "Classic")


func _process(delta: float) -> void:
	var axis := ControlsState.ui_scroll_axis()
	if absf(axis) < 0.01:
		_scroll_carry = 0.0
		return
	_scroll_carry += axis * 200.0 * delta
	var step := int(_scroll_carry)
	if step == 0:
		return
	_scroll_carry -= float(step)
	if _v_bar != null:
		_v_bar.value += step


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var direction := 0
	if InputMap.has_action("ui_tab_prev") and event.is_action("ui_tab_prev"):
		direction = -1
	elif InputMap.has_action("ui_tab_next") and event.is_action("ui_tab_next"):
		direction = 1
	if direction == 0:
		return
	step_tab(direction)
	get_viewport().set_input_as_handled()


func _mode() -> String:
	return RunStats.mode_for_tab(_tab)


func _live() -> bool:
	if PlayState.current == null:
		return false
	return RunStats.mode_for_kind(PlayState.current._stats_kind) == _mode()


func _refresh() -> void:
	if _live():
		_fill(PlayState.current.stats_data())
	else:
		_fill(RunStats.snapshot(_mode()))


func _fill(data: Dictionary) -> void:
	tree.clear()
	var root := tree.create_item()
	var stages: Array = data.get("stages", [])
	var totals: Dictionary = data.get("totals", RunStats.empty_totals())
	var endless := _tab == "Endless"
	var noun := "Level" if endless else "Wave"
	if stages.is_empty():
		var empty := tree.create_item(root)
		empty.set_text(0, "No stats yet.")
		empty.set_selectable(0, false)
		return
	var total_item := tree.create_item(root)
	total_item.set_text(0, "Total")
	var avg := 0.0
	if not stages.is_empty():
		for row in stages:
			avg += float((row as Dictionary).get("time", 0.0))
		avg /= float(stages.size())
		_leaf(total_item, "Average time per %s" % noun.to_lower(), RunStats.format_duration(avg))
	_leaf(total_item, "Asteroids destroyed", str(int(totals.get("asteroids", 0))))
	_leaf(total_item, "Enemies defeated", str(int(totals.get("enemies", 0))))
	_leaf(total_item, "Shots fired", str(int(totals.get("shots", 0))))
	_leaf(total_item, "Super shots fired", str(int(totals.get("supers", 0))))
	if endless:
		_leaf(total_item, "Super level", str(int(totals.get("super_level", 0))))
		_leaf(total_item, "Guns level", str(int(totals.get("guns_level", 0))))
		_leaf(total_item, "Drone level", str(int(totals.get("drone_level", 0))))
	for i in stages.size():
		var row: Dictionary = stages[i]
		var wave := tree.create_item(total_item)
		wave.set_text(0, "%s %d" % [noun, i + 1])
		_leaf(wave, "Time", RunStats.format_duration(float(row.get("time", 0.0))))
		_leaf(wave, "Asteroids destroyed", str(int(row.get("asteroids", 0))))
		_leaf(wave, "Enemies defeated", str(int(row.get("enemies", 0))))
		_leaf(wave, "Shots fired", str(int(row.get("shots", 0))))
		_leaf(wave, "Super shots fired", str(int(row.get("supers", 0))))
		if endless:
			_leaf(wave, "Super level", str(int(row.get("super_level", 0))))
			_leaf(wave, "Guns level", str(int(row.get("guns_level", 0))))
			_leaf(wave, "Drone level", str(int(row.get("drone_level", 0))))
	_select_first()


func _select_first() -> void:
	var filled := tree.get_root()
	if filled == null:
		return
	var first := filled.get_first_child()
	if first == null or not first.is_selectable(0):
		return
	first.select(0)
	tree.scroll_to_item(first)


func _toggle_selected() -> void:
	var item := tree.get_selected()
	if item == null or item.get_first_child() == null:
		return
	item.collapsed = not item.collapsed


func _leaf(parent: TreeItem, label: String, value: String) -> void:
	var item := tree.create_item(parent)
	item.set_text(0, "%s: %s" % [label, value])


func clearStats() -> void:
	if _live():
		PlayState.current.clear_stats()
	else:
		RunStats.clear(_mode())
	_refresh()


func backToMenu() -> void:
	var closed := on_closed
	on_closed = Callable()
	if closed.is_valid():
		closed.call()
	queue_free()
