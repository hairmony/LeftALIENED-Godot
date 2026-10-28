class_name MenuState
extends Node2D


@onready var rulesText: Label = $UI/RulesText
@onready var creditsPanel: ColorRect = $UI/CreditsPanel
@onready var creditsText: Label = $UI/CreditsClip/CreditsText
@onready var playButton: Button = $UI/PlayButton # Position it vertically in the middle
@onready var classicButton: Button = $UI/ClassicButton
@onready var endlessButton: Button = $UI/EndlessButton
@onready var optionsButton: Button = $UI/OptionsButton # Align it with the playButton, underneath
@onready var rulesButton: Button = $UI/RulesButton # Add 10px padding
@onready var creditsButton: Button = $UI/CreditsButton
@onready var closeButton: Button = $UI/CloseButton # Add 10px padding
@onready var titleLogo: Sprite2D = $TitleLogo
@onready var backdrop: Sprite2D = $Backdrop
@onready var backdrop2: Sprite2D = $Backdrop2

@export var creditsScrollSpeed: float = 30.0 # pixels per second
var creditsActive: bool = false
@export var menuBgScrollSpeed: float = 20.0
var _leaving: bool = false
var _modes_open: bool = false

static var padding: float = 10.0

var _buttons: Array[Button] = []


func _ready() -> void:
	Main.current.play_music("assets/music/MenuMusic.mp3", 0.25)
	_buttons = [playButton, classicButton, endlessButton, optionsButton, rulesButton, creditsButton, closeButton]
	_place_backdrop()


func _process(elapsed: float) -> void:
	var tile_h: float = backdrop.texture.get_height() * backdrop.scale.y
	Main.bg_y = fmod(Main.bg_y + menuBgScrollSpeed * elapsed, tile_h)
	_place_backdrop()

	if creditsActive:
		creditsText.position.y -= creditsScrollSpeed * elapsed
		if creditsText.position.y + creditsText.size.y < 0:
			creditsText.position.y = creditsPanel.size.y

	if _leaving:
		var dx: float = 450.0 * elapsed
		titleLogo.position.x -= dx
		for b in _buttons:
			b.position.x -= dx
		var logo_right: float = titleLogo.position.x + titleLogo.texture.get_width() * titleLogo.scale.x
		if playButton.offset_right < 0.0 and logo_right < 0.0:
			_leaving = false
			Main.current.change_state("play")


func _place_backdrop() -> void:
	backdrop.position.y = Main.bg_y
	backdrop2.position.y = Main.bg_y - backdrop.texture.get_height() * backdrop.scale.y


func closeGame() -> void:
	get_tree().quit()


func clickPlay() -> void:
	if _leaving:
		return
	_modes_open = not _modes_open
	_show_modes()


func clickClassic() -> void:
	_begin_play(false)


func clickEndless() -> void:
	_begin_play(true)


func _begin_play(endless: bool) -> void:
	if _leaving:
		return
	Main.endless = endless
	_leaving = true
	for b in _buttons:
		b.disabled = true


func _show_modes() -> void:
	classicButton.visible = _modes_open
	endlessButton.visible = _modes_open


#Options menu
func optionsMenu() -> void:
	if _leaving:
		return
	_show_menu(false)
	var options := Main.scene("res://scenes/options.tscn").instantiate() as OptionsState
	if options == null:
		_show_menu(true)
		return
	options.on_closed = _on_options_closed
	add_child(options)


func _on_options_closed() -> void:
	if is_inside_tree():
		_show_menu(true)


func _show_menu(show_menu: bool) -> void:
	titleLogo.visible = show_menu
	for b in _buttons:
		b.visible = show_menu
		b.disabled = not show_menu
	if show_menu:
		_show_modes()
		if Main.using_controller:
			optionsButton.grab_focus()
	if not show_menu:
		rulesText.visible = false
		creditsText.visible = false
		creditsPanel.visible = false
		creditsActive = false


func controlsMenu() -> void:
	if _leaving:
		return
	_show_menu(false)
	var controls := Main.scene("res://scenes/controls.tscn").instantiate() as ControlsState
	controls.on_closed = _on_controls_closed
	add_child(controls)


func _on_controls_closed() -> void:
	if is_inside_tree():
		_show_menu(true)
		if Main.using_controller:
			rulesButton.grab_focus()


func showCredits() -> void:
	_show_menu(false)
	var credits := Main.scene("res://scenes/credits.tscn").instantiate()
	credits.on_closed = _on_options_closed
	add_child(credits)
