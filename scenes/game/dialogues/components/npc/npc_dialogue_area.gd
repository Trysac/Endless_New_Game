extends Node2D
## NPC dialogue trigger.
##
## Starts and ends an NPC's dialogue when the player enters its area,
## optionally waiting for an input action.


signal talk()
signal dialogue_ended()
signal response_selected(response: String)

## Dialogue the NPC shows to the player.
@export var dialogue_resource: DialogueResource
## Title the dialogue starts at.
@export var dialogue_start: String = "start"
## Balloon scene used to display the dialogue.
@export var balloon_scene: PackedScene
## Area that starts the dialogue when the player enters it.
@export var area: Area2D
## Area that ends the interaction when the player leaves it (defaults to [member area]).
@export var area_listen: Area2D
@export var npc: CharacterBody2D
## Optional input action that starts the dialogue; empty starts it on contact.
@export var show_input_key: String = ""

# Player movement script, set while the player is inside the area
var character: Node2D
var _dialogue_is_visible = false
var _in_dialogue = false

func _ready():
	talk.connect(_show_dialogue)
	area.body_entered.connect(_body_entered)
	if !area_listen:
		area_listen = area
	area_listen.body_exited.connect(_body_exited)


func _unhandled_input(event):
	if show_input_key.is_empty():
		return
	if event.is_action_pressed(show_input_key) and character and not _dialogue_is_visible:
		_show_dialogue()

func set_and_show_dialogue(resource: DialogueResource):
	set_dialogue(resource)
	_show_dialogue()


func set_dialogue(resource: DialogueResource):
	dialogue_resource = resource


# Opens the balloon and freezes the player until it closes.
func _show_dialogue():
	if _in_dialogue:
		return
	var balloon: Node = balloon_scene.instantiate()
	get_tree().current_scene.add_child(balloon)
	balloon.start(dialogue_resource, dialogue_start)

	balloon.on_dialogue_ended(_npc_dialogue_ended)
	balloon.on_response_selected(_on_response_selected)
	character.set_disabled(true)
	character.set_idle()
	_dialogue_is_visible = true
	_in_dialogue = true


func _npc_dialogue_ended():
	self.emit_signal("dialogue_ended")
	character.set_disabled(false)
	_dialogue_is_visible = false


func _on_response_selected(response: String):
	self.emit_signal("response_selected", response)


# Connects a callback to the end of the dialogue.
func on_dialogue_ended(fn):
	dialogue_ended.connect(fn)


# Connects a callback to the selected response.
func on_response_selected(fn):
	response_selected.connect(fn)


func _body_entered(body):
	if body.is_in_group("player"):
		character = body.get_node("MainCharacterMovement")
		# Without an input action, talk on contact.
		if show_input_key == "":
			_show_dialogue()
		var _npc_animation: AnimatedSprite2D = npc.find_child('Npc')
		# Face the player.
		if body.global_position.x > area.global_position.x:
			_npc_animation.flip_h = false
		else:
			_npc_animation.flip_h = true


func _body_exited(_body):
	character = null
	_in_dialogue = false
