extends Node2D
## Door to another scene.
##
## Changes to the configured scene when the player touches it.


## Scene to load.
@export var _path_to_scene = ""

@onready var _area = $Area2D


func _ready():
	_area.body_entered.connect(_load_next_level)


func _load_next_level(body):
	if _path_to_scene != "" and body.is_in_group("player"):
		SceneTransition.change_scene(_path_to_scene)
