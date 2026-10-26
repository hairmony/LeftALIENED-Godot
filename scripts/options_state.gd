class_name OptionsState
extends Node2D

@onready var shipPreview: Sprite2D = $ShipPreview
@onready var shipPreviewBG: ColorRect = $UI/ShipPreviewBG
@onready var shipButton: Button = $UI/ShipButton
@onready var musicSlider: HSlider = $UI/MusicSlider
@onready var sfxSlider: HSlider = $UI/SfxSlider
@onready var musicBar: ProgressBar = $UI/MusicBar
@onready var sfxBar: ProgressBar = $UI/SfxBar
@onready var fullscreenToggle: CheckButton = $UI/WindowRow/FullscreenToggle

var _window_lock: bool = false

var currentShipNumber: int = 0
var on_closed := Callable()

@export var SHIP_MAX: int = 6
@export var padding: int = 10


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
	updateShipButtonText() # Set the initial text
	shipPreview.texture = Actor.load_texture(previewShip())
	# **These lines keep the ship centered inside its background**
	shipPreview.position = shipPreviewBG.position + shipPreviewBG.size / 2.0
	if Main.using_controller:
		shipButton.grab_focus()


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


func cycleShipChoice() -> void:
	currentShipNumber += 1
	if currentShipNumber >= SHIP_MAX:
		currentShipNumber = 0 # Wrap around to the first ship
	saveShipChoice()
	updateShipButtonText()
	shipPreview.texture = Actor.load_texture(previewShip())
	shipPreview.position = shipPreviewBG.position + shipPreviewBG.size / 2.0
	_apply_ship_now()


func _apply_ship_now() -> void:
	if PlayState.current == null or PlayState.current.ship == null:
		return
	var player := PlayState.current.ship
	if not player.alive or not player.visible:
		var mid := player.get_midpoint()
		player.apply_asset(currentShipNumber)
		player.position = mid - player.frame_size() * 0.5
		return
	player.begin_swap(currentShipNumber)


func saveShipChoice() -> void:
	save_ship_choice(currentShipNumber) # Immediately write the data to the file


func updateShipButtonText() -> void:
	var choice = ship_choice()
	var shipName := "Missingno"
	if choice != null:
		match int(choice):
			0:
				shipName = "Guardian"
			1:
				shipName = "Odyssey"
			2:
				shipName = "Beyonder"
			3:
				shipName = "Turncoat"
			4:
				shipName = "Developer"
			5:
				shipName = "Thankless"
			_:
				shipName = "Missingno"
		currentShipNumber = int(choice)
		shipButton.text = str(currentShipNumber + 1) + ": " + shipName
	else:
		shipButton.text = str(currentShipNumber + 1) + ": " + shipName
