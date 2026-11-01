extends CharacterBody2D
## NPC behaviour.
##
## Forwards dialogue calls to its NpcDialogueArea child.


var _npc_dialogue_area: Node2D

@onready var _collision = $CollisionShape2D
@onready var _animation = $Npc


func _ready():
	_npc_dialogue_area = find_child("NpcDialogueArea")


func _physics_process(delta):
	# Fall until landing, then stop simulating.
	velocity.y += 1000 * delta
	move_and_slide()
	if is_on_floor():
		set_physics_process(false)


# Connects a callback to the end of the dialogue.
func on_dialogue_ended(fn):
	if _npc_dialogue_area:
		_npc_dialogue_area.on_dialogue_ended(fn)


# Connects a callback to the response chosen in the dialogue.
func on_response_selected(fn):
	if _npc_dialogue_area:
		_npc_dialogue_area.on_response_selected(fn)


# Disables (or enables) both the NPC's collision and its physics.
func set_collision_disabled(disabled: bool):
	set_physics_process(not disabled)
	_collision.disabled = disabled


func flip_h(flip: bool):
	_animation.flip_h = flip


# Sets a new dialogue and shows it.
func set_and_show_dialogue(resource: DialogueResource):
	if _npc_dialogue_area:
		_npc_dialogue_area.set_and_show_dialogue(resource)


func set_dialogue(resource: DialogueResource):
	if _npc_dialogue_area:
		_npc_dialogue_area.set_dialogue(resource)
