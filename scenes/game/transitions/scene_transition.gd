extends CanvasLayer
## Scene changer with a dissolve transition.


@onready var animation: AnimationPlayer = $AnimationPlayer


func _ready():
	visible = false
	self.process_mode = Node.PROCESS_MODE_ALWAYS


# Changes to the scene at `target` behind a dissolve, then shows or hides the main menu.
func change_scene(target: String, show_menu = false):
	visible = true
	animation.play("dissolve")
	await animation.animation_finished
	MainMenu.show_menu(show_menu)
	# A new level: forget the previous level's checkpoint.
	Progress.enter_level(target)
	get_tree().change_scene_to_file(target)
	animation.play_backwards("dissolve")
	await animation.animation_finished
	animation.stop()
	visible = false


# Reloads the current level after a death. The player comes back at the
# level's respawn point (its start or last checkpoint) with full health and
# the counters it had there; see Progress.
func reload_scene():
	HealthDashboard.visible = true
	Progress.prepare_respawn()
	get_tree().reload_current_scene()
