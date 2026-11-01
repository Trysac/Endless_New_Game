extends Area2D
## Death zone.
##
## Kills the player on contact.


func _on_body_entered(body):
	if body.is_in_group("player"):
		var _move_script = body.get_node("MainCharacterMovement")
		_move_script.hit(100, true)
