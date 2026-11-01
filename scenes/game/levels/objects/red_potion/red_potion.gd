extends Node2D
## Health potion.
##
## Restores health when the player touches it.


## Health restored.
@export var life = 4

@onready var _potion = $Potion
@onready var _effect = $Effect
@onready var _audio = $AudioStreamPlayer


func _ready():
	_potion.play()


func _on_area_body_entered(body):
	if body.is_in_group("player"):
		HealthDashboard.add_life(life)
		_audio.play()
		# Play the pick-up effect before freeing the potion.
		_potion.visible = false
		_effect.visible = true
		_effect.play()
		await _effect.animation_finished
		self.queue_free()
