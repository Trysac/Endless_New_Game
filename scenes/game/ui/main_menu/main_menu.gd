extends Node2D
## Main menu.
##
## Start/continue, fullscreen, volume sliders and the controls screen.
## Escape toggles it once the game has started; while open it pauses the game.


# Level loaded by the start button
const PATH_LEVEL_1 = "res://scenes/game/levels/rooms/scene_1/scene_1.tscn"


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
	_toggle_show()
	_game_controls.visible = false

func _unhandled_input(event):
	if event.is_action_released("ui_cancel") and _started:
		_toggle_show()


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
	
	# Levels name their root node "Main".
	var main_node = get_tree().get_root().get_node("Main")
	if main_node:
		var camera = main_node.find_child("Camera2D")
		if camera:
			camera.enabled = not visible
	if _started:
		_button.text = "Continuar"


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
		SceneTransition.change_scene(PATH_LEVEL_1)
		_started = true


func _on_slider_ambient_value_changed(value):
	var bus = AudioServer.get_bus_index("Ambient")
	AudioServer.set_bus_volume_db(bus, linear_to_db(value))


func _on_slider_effects_value_changed(value):
	var bus = AudioServer.get_bus_index("Effects")
	AudioServer.set_bus_volume_db(bus, linear_to_db(value))


func show_menu(_show: bool):
	if _show:
		if not visible:
			_toggle_show()
	else:
		if visible:
			_toggle_show()


func _on_show_controls_pressed():
	_game_controls.visible = not _game_controls.visible


func _on_close_controls_pressed():
	_game_controls.visible = false
