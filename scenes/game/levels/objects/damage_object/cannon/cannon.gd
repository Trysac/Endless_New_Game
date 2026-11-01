extends RigidBody2D
## Cannon.
##
## Fires a cannonball in a loop: the ball spawns on frame 3 of the fire
## animation and is removed one second after the animation ends.


@onready var _cannon_animation = $AnimatedSprite2D
@onready var _animated_sprite_effects = $AnimatedSprite2DEffects
var new_ball: RigidBody2D


func _ready():
	fire()


func fire():
	_cannon_animation.play("fire")


func _on_animated_sprite_2d_frame_changed():
	if _cannon_animation.frame == 3:
		var ball = "scenes/game/levels/objects/damage_object/cannon/cannon_ball.tscn"
		new_ball = load(ball).instantiate()
		new_ball.position.x = -20
		self.add_child(new_ball)
		_animated_sprite_effects.play("fire_effect")


func _on_animated_sprite_2d_animation_finished():
	if _cannon_animation.get_animation() == 'fire':
		await get_tree().create_timer(1).timeout
		new_ball.queue_free()
		fire()
