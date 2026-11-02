extends EnemyBase
## Cucumber enemy.
##
## Patrols and fights like the other Pirate Bomb enemies, and puts out the
## player's lit bombs it touches by blowing out the wick.


func _ready():
	super()
	_hurt_box.body_entered.connect(_on_hurt_box_body_entered)


func _on_hurt_box_body_entered(body):
	if state == State.DEAD:
		return
	if body.is_in_group("bomb") and body.has_method("defuse") and body.is_lit():
		body.defuse()
		_perform("blow_the_wick")
