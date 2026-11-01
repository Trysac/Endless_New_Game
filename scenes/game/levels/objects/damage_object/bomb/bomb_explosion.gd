extends AnimatedSprite2D
## Bomb explosion.
##
## Damages the player during its second frame and frees itself once its sound ends.


@onready var _collision := $Area2D/DamageCollision


func _on_audio_stream_player_finished():
	queue_free()


func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		var _move_script = body.get_node("MainCharacterMovement")
		_move_script.hit(10)


func _on_frame_changed():
	# The damage area is only active on frame 1.
	if frame == 1:
		_collision.disabled = false
	else:
		_collision.disabled = true
