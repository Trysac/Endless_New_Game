extends RigidBody2D
## Thrown bomb.
##
## Explodes three seconds after being thrown.

var _bomb_effect = preload("res://scenes/game/levels/objects/damage_object/bomb/bomb_explosion.tscn")

@onready var _animation = $BombAnimation


func _ready():
	await get_tree().create_timer(3).timeout
	_animation.play("idle")
	# Spawn the explosion slightly above the bomb, then remove the bomb.
	var _pos = position
	var bomb_scene = _bomb_effect.instantiate()
	bomb_scene.position = _pos
	bomb_scene.position.y = _pos.y - 20
	get_parent().add_child(bomb_scene)
	queue_free()
