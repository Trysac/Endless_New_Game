extends RigidBody2D
## Cannonball.
##
## Stops and explodes on impact, damaging the player if it hits them.


@onready var _ball_animation = $AnimatedSprite2D


func _on_body_entered(body):
	# Ignore the cannon that fired it.
	if body.is_in_group("cannon"):
		return

	self.set_deferred("freeze", true)
	self.set_deferred("sleeping", true)
	self.set_deferred("linear_velocity.x", 0)
	self.set_deferred("linear_velocity.y", 0)
	self.set_deferred("gravity_scale", 0)
	self.collision_mask = 0
	self.collision_layer = 0
	_ball_animation.play("explosion")
	GameFeel.shake(3.0, 0.2)
	GameFeel.burst(global_position, Color(1, 0.7, 0.35), 12, 110.0)
	if body.is_in_group("player"):
		var _move_script = body.get_node("MainCharacterMovement")
		_move_script.hit(10, false, global_position)
