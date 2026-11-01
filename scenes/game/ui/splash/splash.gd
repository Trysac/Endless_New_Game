extends Node2D
## Splash screen: shows the studio card, then the art credit, then the title screen.
##
## Any key skips straight to the title screen.


@onready var _studio_animation: AnimationPlayer = $AnimationPlayerStudio
@onready var _pixel_frog_animation: AnimationPlayer = $AnimationPixelFrog

# Scene loaded when the splash sequence ends.
var _path_map_scene = "res://scenes/game/levels/rooms/init/init.tscn"


func _ready():
	# Hide the in-game HUD while the splash is shown.
	HealthDashboard.visible = false
	_studio_animation.play("do_splash")


func _input(event):
	if event is InputEventKey and event.pressed:
		_go_title_screen()


func _go_title_screen():
	set_process_input(false)
	SceneTransition.change_scene(_path_map_scene)


func _on_studio_animation_finished(_anim_name):
	_pixel_frog_animation.play("do_splash")


func _on_pixel_frog_animation_finished(_anim_name):
	_go_title_screen()
