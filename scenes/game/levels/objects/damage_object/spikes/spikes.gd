extends Node
## Spikes.
##
## Damages the player on contact and again on every timer tick while they stay on them.


var _player_script: Node2D # Player movement script, set while the player is on the spikes

@onready var _timer = $Timer


func _on_area_body_entered(body):
	if body.is_in_group("player"):
		_player_script = body.get_node("MainCharacterMovement")
		_player_script.hit(2)
		_timer.start()


func _on_area_body_exited(body):
	_player_script = null


func _on_timer_timeout():
	if not _player_script:
		return
	if HealthDashboard.life <= 0:
		return
	_player_script.hit(2)
	_timer.start()
