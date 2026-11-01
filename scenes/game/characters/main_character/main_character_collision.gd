extends Node2D
## Collision handler.
##
## Calls hit() on anything the character slides into that supports a
## parameterless hit().

@export var character: CharacterBody2D


func _ready():
	if not character:
		set_process(false)


func _process(_delta):
	for i in character.get_slide_collision_count():
		var collision = character.get_slide_collision(i)
		var collider = collision.get_collider()
		# Only bodies with an argument-less hit() react to being bumped; the
		# player's damage entry point, hit(value), takes an amount instead.
		if collider and collider.has_method("hit") and collider.get_method_argument_count("hit") == 0:
			collider.hit()
