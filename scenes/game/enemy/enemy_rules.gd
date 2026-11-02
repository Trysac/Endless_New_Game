class_name EnemyRules
## Rules shared by every enemy type.


## Called when a sword hit lands on an enemy. A power-up attack kills in one
## hit and uses one charge; once out of charges the sword goes back to normal.
## Returns true when the hit is a one-hit kill.
static func consume_special_attack() -> bool:
	var one_hit_kill: bool = Global.special_attacks_left > 0
	if one_hit_kill:
		Global.special_attacks_left -= 1
	if Global.special_attacks_left == 0:
		Global.attack_effect = "normal"
	return one_hit_kill
