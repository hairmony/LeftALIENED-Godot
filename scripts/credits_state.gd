extends "res://addons/maaacks_credits_scene/examples/scenes/credits/scrolling_credits.gd"

var on_closed := Callable()
var play_music_on_ready: bool = true


func _ready() -> void:
	super._ready()
	if play_music_on_ready:
		Main.current.play_music("assets/music/CreditsMusic.mp3", 0.25)
	if Main.using_controller:
		($BackButton as Button).grab_focus()


func backToMenu() -> void:
	Main.current.play_music("assets/music/MenuMusic.mp3", 0.25)
	var closed := on_closed
	on_closed = Callable()
	if closed.is_valid():
		closed.call()
	var holder := get_parent()
	if holder is CanvasLayer and holder.get_parent() == Main.current:
		holder.queue_free()
	else:
		queue_free()
