extends RigidBody2D
## Breakable box.
##
## Plays a hit animation when struck, then swaps itself for the destroyed
## pieces, which fly away from the attacker, and frees itself.


@onready var _animated_sprite = $AnimatedSprite2D
@onready var _box_destroyed = $BoxDestroyed
var _do_animation = false # True once the box has been hit


func _ready():
	_animated_sprite.play("idle")
	# Keep the destroyed pieces out of the tree until the box breaks.
	_box_destroyed.get_parent().remove_child(_box_destroyed)


func _on_animated_sprite_2d_animation_finished():
	if _animated_sprite.get_animation() == 'hit':
		_animated_sprite.visible = false
		self.set_deferred("collision_layer", 2)
		self.add_child(_box_destroyed)
		await get_tree().create_timer(3).timeout
		queue_free()


func do_animation():
	_animated_sprite.play("hit")


func _on_area_2d_area_entered(area):
	if area.is_in_group("hit"):
		_collided(area)
	elif area.is_in_group("die"):
		_collided(area)


func _collided(area):
	# Pieces fly away from the attacker.
	if global_position.x < area.global_position.x:
		set_direction(false)
	else:
		set_direction(true)

	if not _do_animation:
		_do_animation = true
		do_animation()


func set_direction(left):
	for child in _box_destroyed.get_children():
		var speed = abs(child.linear_velocity.x)
		if left:
			child.linear_velocity.x = speed
		else:
			child.linear_velocity.x = - speed
