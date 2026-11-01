extends Node2D
## Bomb shop.
##
## Runs the shopkeeper's dialogue and trades coins for bombs.


## Price of one bomb, and the currency it is paid in.
@export var bomb_value = 5
@export var bomb_money = "GoldCoin"
## Dialogue that offers the bombs.
@export var buy_dialogue: DialogueResource
## Dialogue shown when the purchase fails.
@export var failed_dialogue: DialogueResource
## Dialogue shown after a successful purchase.
@export var success_dialogue: DialogueResource

var _ended = false # True while the purchase result dialogue is showing
var _responses = [] # Responses selected in the current dialogue

@onready var npc = $NPC/BigGuy


func _ready():
	npc.set_collision_disabled(true)
	npc.on_dialogue_ended(_on_dialogue_ended)
	npc.on_response_selected(_on_response_selected)


# Buys `amount` bombs and returns whether the purchase succeeded.
# A negative amount buys as many bombs as the coins allow.
func _buy_bombs(amount: int):
	var coins = HealthDashboard.points[bomb_money]
	
	if amount < 0:
		amount = int(coins / bomb_value)

	if amount == 0:
		return false

	var total = amount * bomb_value
	if  total <= coins:
		HealthDashboard.add_points(bomb_money, -total)
		HealthDashboard.add_bomb(amount)
		return true
	else:
		return false


# When the offer dialogue ends, try the purchase and show the result;
# when the result dialogue ends, reset so the player can buy again.
func _on_dialogue_ended():
	if _ended:
		_ended = false
		_responses = []
		npc.set_dialogue(buy_dialogue)
	else:
		_ended = true
		var amount = _get_selected_amount()
		var bought = _buy_bombs(amount)
		if bought:
			npc.set_and_show_dialogue(success_dialogue)
		else:
			npc.set_and_show_dialogue(failed_dialogue)


func _on_response_selected(response: DialogueResponse):
	_responses.append(response)


# Reads the amount from the last response tagged with [#amount=N] in the
# dialogue, so it does not depend on the (translatable) response text.
# "all" (returned as -1) means as many bombs as the coins allow.
func _get_selected_amount():
	var amount = 0
	for response: DialogueResponse in _responses:
		var value = response.get_tag_value("amount")
		if value == "all":
			amount = -1
		elif value.is_valid_int():
			amount = int(value)
	return amount
