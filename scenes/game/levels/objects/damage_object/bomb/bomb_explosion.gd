extends AnimatedSprite2D
## Bomb explosion.
##
## Damages the player during its second frame and frees itself once its sound ends.


const BLAST_COLOR = Color(1, 0.62, 0.25)

@onready var _collision := $Area2D/DamageCollision


func _ready():
	GameFeel.shake(6.0, 0.35)
	GameFeel.burst(global_position, BLAST_COLOR, 24, 150.0)


func _on_audio_stream_player_finished():
	queue_free()


func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		var _move_script = body.get_node("MainCharacterMovement")
		_move_script.hit(10, false, global_position)


func _on_frame_changed():
	# The damage area is only active on frame 1.
	if frame == 1:
		_collision.disabled = false
	else:
		_collision.disabled = true
