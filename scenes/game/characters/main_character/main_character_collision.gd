extends Node2D
## Collision handler.
##
## Calls hit() on anything the character slides into that supports it.

@export var character: CharacterBody2D


func _ready():
	if not character:
		set_process(false)


func _process(_delta):
	for i in character.get_slide_collision_count():
		var collision = character.get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.has_method("hit"):
			collider.hit()
