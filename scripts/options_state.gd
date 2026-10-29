class_name OptionsState
extends Node2D

@onready var tabs: TabContainer = $UI/Tabs
@onready var gameplayTab: Button = $UI/GameplayTab
@onready var controlsTab: Button = $UI/ControlsTab
@onready var videoTab: Button = $UI/VideoTab
@onready var audioTab: Button = $UI/AudioTab
@onready var shipPreview: Sprite2D = $UI/Tabs/Gameplay/List/Preview/ShipPreview
@onready var shipPreviewBG: ColorRect = $UI/Tabs/Gameplay/List/Preview/ShipPreviewBG
@onready var shipButton: OptionButton = $UI/Tabs/Gameplay/List/ShipButton
@onready var musicSlider: HSlider = $UI/Tabs/Audio/List/MusicRow/MusicWrap/MusicSlider
@onready var sfxSlider: HSlider = $UI/Tabs/Audio/List/SfxRow/SfxWrap/SfxSlider
@onready var musicBar: ProgressBar = $UI/Tabs/Audio/List/MusicRow/MusicWrap/MusicBar
@onready var sfxBar: ProgressBar = $UI/Tabs/Audio/List/SfxRow/SfxWrap/SfxBar
@onready var fullscreenToggle: CheckButton = $UI/Tabs/Video/List/WindowRow/FullscreenToggle
@onready var resetButton: Button = $UI/ResetButton
@onready var backButton: Button = $UI/BackButton
@onready var controls_page: ControlsState = $UI/Tabs/Controls

var _tab_group := ButtonGroup.new()

var start_tab: String = "Gameplay"

var _window_lock: bool = false

var currentShipNumber: int = 0
var on_closed := Callable()

@export var SHIP_MAX: int = 6
@export var padding: int = 10
const SHIP_NAMES: Array[String] = [
	"Guardian", "Odyssey", "Beyonder", "Turncoat", "Developer", "Thankless"
]


const SAVE_PATH: String = "user://LeftAliened.cfg"


static func ship_choice() -> Variant:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return null
	if not cf.has_section_key("data", "shipChoice"):
		return null
	return cf.get_value("data", "shipChoice")


static func save_ship_choice(n: int) -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("data", "shipChoice", n)
	cf.save(SAVE_PATH)


static func _saved_level(key: String) -> Variant:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return null
	if cf.has_section_key("data", key):
		return cf.get_value("data", key)
	if cf.has_section_key("data", "volume"):
		return cf.get_value("data", "volume")
	return null


static func music_choice() -> Variant:
	return _saved_level("music")


static func sfx_choice() -> Variant:
	return _saved_level("sfx")


static func save_music(v: float) -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("data", "music", v)
	cf.save(SAVE_PATH)


static func save_sfx(v: float) -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("data", "sfx", v)
	cf.save(SAVE_PATH)


static func window_mode() -> Variant:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return null
	if not cf.has_section_key("data", "windowMode"):
		return null
	return cf.get_value("data", "windowMode")


static func save_window_mode(mode: int) -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("data", "windowMode", mode)
	cf.save(SAVE_PATH)


func _ready() -> void:
	musicSlider.value = Main.current.music_volume
	sfxSlider.value = Main.current.sfx_volume
	musicBar.value = musicSlider.value
	sfxBar.value = sfxSlider.value
	_sync_window_toggles()
	_fill_ship_options()
	updateShipButtonText()
	shipPreview.texture = Actor.load_texture(previewShip())
	# **These lines keep the ship centered inside its background**
	shipPreview.position = shipPreviewBG.position + shipPreviewBG.size / 2.0
	_tab_group.allow_unpress = false
	for b in _tab_buttons():
		b.button_group = _tab_group
	_bind_slider_focus(musicSlider, musicBar)
	_bind_slider_focus(sfxSlider, sfxBar)
	musicSlider.focus_neighbor_bottom = musicSlider.get_path_to(sfxSlider)
	sfxSlider.focus_neighbor_top = sfxSlider.get_path_to(musicSlider)
	sfxSlider.focus_neighbor_bottom = sfxSlider.get_path_to(backButton)
	tabs.tab_changed.connect(_on_tab_changed)
	open_tab(start_tab)
	_on_tab_changed(tabs.current_tab)
	call_deferred("_focus_current_tab")


func _tab_buttons() -> Array[Button]:
	return [gameplayTab, controlsTab, videoTab, audioTab]


func _bind_slider_focus(slider: Slider, bar: ProgressBar) -> void:
	slider.focus_mode = Control.FOCUS_ALL
	var ring := Panel.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_theme_stylebox_override("panel", backButton.get_theme_stylebox("focus"))
	ring.visible = false
	bar.add_child(ring)
	slider.focus_entered.connect(func() -> void: ring.visible = true)
	slider.focus_exited.connect(func() -> void: ring.visible = false)


func set_tabs_locked(locked: bool) -> void:
	for b in _tab_buttons():
		b.disabled = locked


func open_tab(tab_name: String) -> void:
	for i in tabs.get_tab_count():
		if tabs.get_tab_title(i) == tab_name:
			tabs.current_tab = i
			break
	_sync_tab_buttons()


func _sync_tab_buttons() -> void:
	var title := tabs.get_tab_title(tabs.current_tab)
	for b in _tab_buttons():
		b.set_pressed_no_signal(b.text == title)


func _on_tab_changed(_tab: int) -> void:
	_sync_tab_buttons()


func _focus_current_tab() -> void:
	if not Main.using_controller:
		return
	var title := tabs.get_tab_title(tabs.current_tab)
	if title == "Gameplay":
		shipButton.grab_focus()
	elif title == "Audio":
		musicSlider.grab_focus()
	elif title == "Video":
		fullscreenToggle.grab_focus()
	elif title == "Controls":
		controls_page._focus_slot(0, 0)


func step_tab(direction: int) -> void:
	tabs.current_tab = wrapi(tabs.current_tab + direction, 0, tabs.get_tab_count())
	_focus_current_tab()


func _unhandled_input(event: InputEvent) -> void:
	if ControlsState.listening or not event.is_pressed() or event.is_echo():
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


func resetTab() -> void:
	match tabs.get_tab_title(tabs.current_tab):
		"Gameplay":
			currentShipNumber = 0
			saveShipChoice()
			updateShipButtonText()
			shipPreview.texture = Actor.load_texture(previewShip())
			shipPreview.position = shipPreviewBG.position + shipPreviewBG.size / 2.0
			_apply_ship_now()
		"Controls":
			controls_page.resetBindings()
		"Video":
			_set_window_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"Audio":
			musicSlider.value = 1.0
			sfxSlider.value = 1.0
			setMusic(1.0)
			setSfx(1.0)


func setMusic(v: float) -> void:
	Main.current.set_music_volume(v)
	save_music(v)
	musicBar.value = v


func setSfx(v: float) -> void:
	Main.current.set_sfx_volume(v)
	save_sfx(v)
	sfxBar.value = v


func setFullscreen(on: bool) -> void:
	if _window_lock:
		return
	_set_window_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


func _set_window_mode(mode: DisplayServer.WindowMode) -> void:
	DisplayServer.window_set_mode(mode)
	save_window_mode(mode)
	_sync_window_toggles()


func _sync_window_toggles() -> void:
	_window_lock = true
	var mode := DisplayServer.window_get_mode()
	fullscreenToggle.set_pressed_no_signal(mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	_window_lock = false


func previewShip() -> String:
	var choice = ship_choice()
	return _ship_path(choice)


func _ship_path(choice) -> String:
	if choice == null:
		return "assets/images/Ship.png"
	match int(choice):
		0:
			return "assets/images/Ship.png"
		1:
			return "assets/images/Ship2.png"
		2:
			return "assets/images/Ship3.png"
		3:
			return "assets/images/Ship4.png"
		4:
			return "assets/images/Ship5.png"
		5:
			return "assets/images/Ship6.png"
		_:
			return "assets/images/Ship.png"


func backToMenu() -> void:
	var closed := on_closed
	on_closed = Callable()
	if closed.is_valid():
		closed.call()
	queue_free()


func _fill_ship_options() -> void:
	shipButton.clear()
	for i in SHIP_MAX:
		var n := "Missingno"
		if i < SHIP_NAMES.size():
			n = SHIP_NAMES[i]
		shipButton.add_item(n, i)


func selectShip(index: int) -> void:
	currentShipNumber = index
	saveShipChoice()
	shipPreview.texture = Actor.load_texture(previewShip())
	shipPreview.position = shipPreviewBG.position + shipPreviewBG.size / 2.0
	_apply_ship_now()


func _apply_ship_now() -> void:
	if PlayState.current == null or PlayState.current.ship == null:
		return
	var player := PlayState.current.ship
	# player.begin_swap(currentShipNumber)
	var mid := player.get_midpoint()
	player.apply_asset(currentShipNumber)
	player.position = mid - player.frame_size() * 0.5


func saveShipChoice() -> void:
	save_ship_choice(currentShipNumber) # Immediately write the data to the file


func updateShipButtonText() -> void:
	var choice = ship_choice()
	if choice != null:
		currentShipNumber = int(choice)
	currentShipNumber = clampi(currentShipNumber, 0, maxi(SHIP_MAX - 1, 0))
	shipButton.select(currentShipNumber)
