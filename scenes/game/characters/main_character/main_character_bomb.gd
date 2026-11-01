extends Node2D
## Bomb thrower.
##
## Listens for the throw-bomb action and spawns a bomb next to the character.


var _bomb = preload("res://scenes/game/levels/objects/damage_object/bomb/bomb.tscn")
var _move_script: Node2D


func _ready():
	HealthDashboard.add_bomb(2)
	_move_script = get_parent().get_node("MainCharacterMovement")


func _unhandled_input(event):
	var bomb_count = HealthDashboard.points["Bomb"]
	# Throw only if we have bombs and are not already throwing one.
	if event.is_action_released("throw_bomb") and not _move_script.bombing and bomb_count > 0:
		HealthDashboard.add_bomb(-1)
		var bomb_scene = _bomb.instantiate()
		var _character = get_parent()
		var _character_position = _character.position
		bomb_scene.position = _character_position
		# Throw it towards the side the character is facing, with a small offset.
		if _move_script.turn_side == "right":
			bomb_scene.linear_velocity.x = abs(bomb_scene.linear_velocity.x)
			bomb_scene.position.x = _character_position.x + 25
		else:
			bomb_scene.linear_velocity.x = - abs(bomb_scene.linear_velocity.x)
			bomb_scene.position.x = _character_position.x - 25

		get_parent().get_parent().add_child(bomb_scene)
