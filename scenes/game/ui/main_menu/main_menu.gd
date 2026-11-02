extends Node2D
## Main menu.
##
## Start/continue, best score, fullscreen, volume sliders, language and the
## controls screen.
## The pause action (Escape / Start) toggles it once the game has started;
## while open it pauses the game. Every option can be reached with a gamepad.


# Level loaded by the start button
const PATH_LEVEL_1 = "res://scenes/game/levels/rooms/scene_1/scene_1.tscn"
# Languages offered by the selector: locale and its name in that language
const LANGUAGES = [["en", "English"], ["es", "Español"]]


# Direction of each cloud layer's ping-pong animation
var _parallax_1_normal = true
var _parallax_2_normal = false
var _started = false # True once the first level has been loaded

@onready var _anim_water = $Main/World/Background/AnimWater
@onready var _anim_ship = $Main/World/Ship/Ship
@onready var _anim_flag = $Main/World/Ship/Flag
@onready var _parallax_1 = $Main/ParallaxBackground/Parallax1
@onready var _parallax_2 = $Main/ParallaxBackground/Parallax2
@onready var _button = $Main/CanvasLayer/Options/Init/Button/Button
@onready var _slider_ambient = $Main/CanvasLayer/Options/Sounds/Sliders/Ambient/Slider/SliderAmbient
@onready var _slider_effects = $Main/CanvasLayer/Options/Sounds/Sliders/Effects/Slider/SliderEffects
@onready var _main = $Main
@onready var _game_controls = $Main/GameControls
@onready var _language = $Main/CanvasLayer/Options/Controls/Language
@onready var _show_controls = $Main/CanvasLayer/Options/Controls/ShowControls
@onready var _controls_list = $Main/GameControls/Background/Texts/List
@onready var _best_score = $Main/CanvasLayer/Options/Init/BestScore


func _ready():
	visible = true
	# Keep running while the tree is paused.
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	HealthDashboard.visible = false
	_anim_water.play()
	_anim_ship.play()
	_anim_flag.play()
	_parallax_1.play("parallax1")
	_parallax_2.play_backwards("parallax1")
	# Apply the sliders' initial volumes.
	_on_slider_ambient_value_changed(_slider_ambient.value)
	_on_slider_effects_value_changed(_slider_effects.value)
	_setup_language_selector()
	_refresh_best_score()
	Progress.best_score_changed.connect(func(_score): _refresh_best_score())
	Settings.locale_changed.connect(func(_locale): _refresh_best_score())
	_toggle_show()
	_game_controls.visible = false

func _unhandled_input(event):
	if not event.is_action_pressed("pause"):
		return
	if _game_controls.visible:
		# Back out of the controls screen first.
		_on_close_controls_pressed()
		get_viewport().set_input_as_handled()
	elif _started:
		_toggle_show()
		get_viewport().set_input_as_handled()


# Ping-pong the cloud layers forever.
func _on_parallax_1_animation_finished(_anim_name):
	if _parallax_1_normal:
		_parallax_1.play_backwards("parallax1")
		_parallax_1_normal = false
	else:
		_parallax_1.play("parallax1")
		_parallax_1_normal = true


func _on_parallax_2_animation_finished(_anim_name):
	if _parallax_2_normal:
		_parallax_2.play_backwards("parallax1")
		_parallax_2_normal = false
	else:
		_parallax_2.play("parallax1")
		_parallax_2_normal = true


# Shows or hides the menu: mounts its nodes, pauses the game and toggles
# the current level's camera.
func _toggle_show():
	visible = not visible
	HealthDashboard.visible = not visible
	if visible:
		self.add_child(_main)
	else:
		self.remove_child(_main)
	
	get_tree().paused = visible
	
	# Toggle the current level's camera, if it has one.
	var current_scene = get_tree().current_scene
	if current_scene:
		var camera = current_scene.find_child("Camera2D")
		if camera:
			camera.enabled = not visible
	if _started:
		_button.text = "MENU_CONTINUE"
	if visible:
		# Let keyboard and gamepad players navigate the menu right away.
		_button.call_deferred("grab_focus")


func _on_check_button_toggled(button_pressed):
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


# Start button: loads level 1 the first time, then just closes the menu.
func _on_button_pressed():
	if _started:
		_toggle_show()
	else:
		Progress.start_run()
		SceneTransition.change_scene(PATH_LEVEL_1)
		_started = true


# Shows the saved best score.
func _refresh_best_score():
	_best_score.text = tr("MENU_BEST_SCORE") % Progress.best_score


func _on_slider_ambient_value_changed(value):
	var bus = AudioServer.get_bus_index("Ambient")
	AudioServer.set_bus_volume_db(bus, linear_to_db(value))


func _on_slider_effects_value_changed(value):
	var bus = AudioServer.get_bus_index("Effects")
	AudioServer.set_bus_volume_db(bus, linear_to_db(value))


## Starts a new run from the first level, as the play button does.
func start_run():
	_on_button_pressed()


## Ends the current run: the pause action stops opening the menu and the
## start button offers a new game instead of "Continue".
func end_run():
	_started = false
	_button.text = "MENU_PLAY"


func show_menu(_show: bool):
	if _show:
		if not visible:
			_toggle_show()
	else:
		if visible:
			_toggle_show()


func _on_show_controls_pressed():
	_game_controls.visible = not _game_controls.visible
	if _game_controls.visible:
		_controls_list.focus_first()


func _on_close_controls_pressed():
	_game_controls.visible = false
	_show_controls.grab_focus()


# Fills the language selector and selects the current language.
func _setup_language_selector():
	_language.clear()
	for language in LANGUAGES:
		_language.add_item(language[1])
	_select_current_language()
	_language.item_selected.connect(_on_language_selected)
	# Follow language changes made elsewhere (e.g. loaded settings).
	Settings.locale_changed.connect(func(_locale): _select_current_language())


func _select_current_language():
	var locale = TranslationServer.get_locale()
	for i in LANGUAGES.size():
		if locale.begins_with(LANGUAGES[i][0]):
			_language.select(i)
			return


func _on_language_selected(index: int):
	Settings.set_locale(LANGUAGES[index][0])
