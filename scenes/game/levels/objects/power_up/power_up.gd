extends AnimatedSprite2D
## Power-up pickup.
##
## Shows a description dialogue when the player touches it, then goes to the inventory.
## With a full inventory it stays on the ground and says so instead.


# Description dialogue for each power-up animation
var _dialogues = {
	"blue_potion": "res://scenes/game/dialogues/dialogues/power_up/blue_potion.dialogue",
	"green_bottle": "res://scenes/game/dialogues/dialogues/power_up/green_bottle.dialogue",
}
var _move: Node2D # Player movement script, disabled while the dialogue is open


func _ready():
	play()


func _show_dialogue():
	var _resource = _dialogues[animation]
	var _instance = load(_resource)
	var _dialogue = CustomDialogue.create_and_show_dialogue(_instance)
	_dialogue.on_dialogue_ended(_on_dialogue_ended)


func _on_area_body_entered(body):
	if body.is_in_group("player") and not _move:
		if not InventoryCanvas.can_add_item(animation):
			GameFeel.popup_text(global_position + Vector2(0, -12), tr("INVENTORY_FULL"), Color(1, 0.6, 0.5))
			return
		# Freeze the player while the dialogue is shown.
		_move = body.get_node_or_null("MainCharacterMovement")
		_show_dialogue()
		if _move:
			_move.set_disabled(true)
			_move.set_idle()


# Adds the power-up to the inventory, plays the pick-up animation,
# then re-enables the player and frees itself.
func _pick_up():
	InventoryCanvas.add_item_by_name(animation)
	play("pick_up")
	await animation_finished
	if is_instance_valid(_move):
		_move.set_disabled(false)
	queue_free()


func _on_dialogue_ended():
	_pick_up()
