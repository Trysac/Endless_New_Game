extends Node
## Custom dialogue helper.
##
## Creates and shows dialogues using the game's own balloon scene.


var _path_custom_dialogue = "res://scenes/game/dialogues/balloon/balloon.tscn"
var _custom_dialogue: PackedScene


func _ready():
	_custom_dialogue = load(_path_custom_dialogue)


# Returns a new, not yet shown, balloon.
func create():
	var _dialog = _custom_dialogue.instantiate()
	return _dialog


# Adds the balloon to the current scene and starts it.
func show_dialogue(_dialog: Node, _resource: DialogueResource, _start = "start"):
	get_tree().current_scene.add_child(_dialog)
	_dialog.start(_resource, _start)


# Creates, shows and returns a balloon.
func create_and_show_dialogue(_resource: DialogueResource, _start = "start"):
	var _dialog = create()
	show_dialogue(_dialog, _resource, _start)
	return _dialog
