extends Node2D
## Power-up item in the inventory.
##
## Clicking it asks for confirmation; accepting activates the power-up,
## shows its dialogue and removes one item from the inventory.


var _is_active = false # True while the mouse is over the item
# Dialogue shown when each power-up is used
var _dialogues = {
	"blue_potion": "res://scenes/game/dialogues/dialogues/power_up/blue_potion_item.dialogue",
	"green_bottle": "res://scenes/game/dialogues/dialogues/power_up/green_bottle_item.dialogue",
}

@export var num = "1" # Item count
@onready var canvas = $Num # Count label
@onready var animation = $PowerUpItem
@onready var _confirm = $CanvasConfirm


func _ready():
	canvas.text = num


func _unhandled_input(event):
	if not _is_active:
		return
	if event is InputEventMouseButton and event.is_action_released("click"):
		_confirm.show()


func _show_dialogue():
	var _resource = _dialogues[animation.animation]
	var _instance = load(_resource)
	var _dialogue = CustomDialogue.create_and_show_dialogue(_instance)
	_dialogue.on_dialogue_ended(_on_dialogue_ended)


func _on_dialogue_ended():
	InventoryCanvas.remove_item_by_name(animation.animation)

func set_num(_num: String):
	canvas.text = _num


func get_num():
	return int(canvas.text)


func _on_area_mouse_entered():
	_is_active = true


func _on_area_mouse_exited():
	_is_active = false


func _on_cancel_pressed():
	_confirm.hide()


# Activates the power-up for the next four hits.
func _on_accept_pressed():
	Global.attack_effect = animation.animation
	Global.special_attacks_left = 4
	_confirm.hide()
	InventoryCanvas.show_inventory(false)
	_show_dialogue()


# Sets which power-up this item shows.
func set_animation(animation_name):
	animation.play(animation_name)
