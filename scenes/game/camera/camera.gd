extends Camera2D
## Level camera.
##
## Smoothly follows the main character.


## Character to follow.
@export var character: CharacterBody2D


func _ready():
	# Without a character there is nothing to follow.
	if not character:
		set_physics_process(false)
		return
	position = character.position


func _physics_process(delta):
	# Stop following once the character has been freed (it died).
	if not character:
		return
	var charpos = character.position
	var new_pos = position.lerp(charpos, delta * 2.0)
	# Snap to whole pixels so the camera does not jitter on sub-pixel moves.
	new_pos.x = int(new_pos.x)
	new_pos.y = int(new_pos.y)
	position = new_pos
