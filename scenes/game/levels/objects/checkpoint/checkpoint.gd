extends Area2D
## Checkpoint: a pirate flag that is raised when the player touches it.
##
## Touching it makes it the level's respawn point (see Progress): after a
## death the player comes back here with full health and the counters it had
## when the flag was raised.


const LOWERED_SCALE = 0.35 # Height of the lowered flag, relative to raised
const LOWERED_COLOR = Color(0.55, 0.55, 0.62)
const RAISE_TIME = 0.45
const POPUP_COLOR = Color(1, 0.85, 0.35)
## Where the player reappears, relative to the flag's base.
const RESPAWN_OFFSET = Vector2(0, -16)

@onready var _flag: AnimatedSprite2D = $Flag
@onready var _audio: AudioStreamPlayer2D = $AudioStreamPlayer2D

var _raised = false


func _ready():
	body_entered.connect(_on_body_entered)
	if Progress.is_active_checkpoint(self):
		_show_raised()
	else:
		_flag.stop()
		_flag.scale.y = LOWERED_SCALE
		_flag.modulate = LOWERED_COLOR


## True once this flag is the active respawn point.
func is_raised() -> bool:
	return _raised


func get_respawn_position() -> Vector2:
	return global_position + RESPAWN_OFFSET


func _on_body_entered(body):
	if _raised or not body.is_in_group("player"):
		return
	if not Progress.activate_checkpoint(self, get_respawn_position()):
		return
	_raised = true
	_flag.play("wave")
	var tween = create_tween().set_parallel(true)
	tween.tween_property(_flag, "scale:y", 1.0, RAISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_flag, "modulate", Color.WHITE, RAISE_TIME)
	_audio.play()
	GameFeel.popup_text(global_position + Vector2(0, -70), tr("CHECKPOINT_REACHED"), POPUP_COLOR)
	GameFeel.burst(global_position + Vector2(0, -60), POPUP_COLOR, 14, 70.0)


func _show_raised():
	_raised = true
	_flag.scale.y = 1.0
	_flag.modulate = Color.WHITE
	_flag.play("wave")
