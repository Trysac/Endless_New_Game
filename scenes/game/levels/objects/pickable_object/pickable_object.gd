extends Area2D
## Collectible coin or diamond.
##
## Loads the idle frames for the configured item, plays the pick-up animation
## when the player touches it, adds one point of its type plus its run score
## and frees itself. Items collected before the player's respawn point are
## not spawned again when the level reloads after a death.


## Item type; also selects the sprite folder.
@export_enum(
	"blue_diamond",
	"green_diamond",
	"red_diamond",
	"gold_coin",
	"silver_coin",
) var animation: String

@onready var _animated_sprite = $AnimatedSprite2D
@onready var _audio_player = $AudioStreamPlayer2D
@onready var _collider = $CollisionShape2D

var _pickup_sound = preload("res://assets/sounds/pickup.mp3")
var _taken = false # True once collected; the collider is only disabled next frame

# HUD counter of each item
const POINT_TYPES = {
	"blue_diamond": "BlueDiamond",
	"green_diamond": "GreenDiamond",
	"red_diamond": "RedDiamond",
	"gold_coin": "GoldCoin",
	"silver_coin": "SilverCoin",
}
const BONUS_COLOR = Color(1, 0.4, 0.45)

# Sparkle colour of each item
const SPARKLE_COLORS = {
	"blue_diamond": Color(0.5, 0.75, 1),
	"green_diamond": Color(0.55, 0.95, 0.5),
	"red_diamond": Color(1, 0.45, 0.45),
	"gold_coin": Color(1, 0.85, 0.35),
	"silver_coin": Color(0.9, 0.9, 0.95),
}


func _ready():
	# Already collected before the respawn point: it must not count again.
	if Progress.is_collected(self):
		queue_free()
		return
	if not animation:
		return

	# Swap the idle frames for the configured item's sprites.
	var _animation1 = "res://assets/sprites/treasure_hunters/pirate_treasure/sprites/" + animation + "/01.png"
	var _animation2 = "res://assets/sprites/treasure_hunters/pirate_treasure/sprites/" + animation + "/02.png"
	var _animation3 = "res://assets/sprites/treasure_hunters/pirate_treasure/sprites/" + animation + "/03.png"
	var _animation4 = "res://assets/sprites/treasure_hunters/pirate_treasure/sprites/" + animation + "/04.png"

	_animated_sprite.sprite_frames.set_frame("idle", 0, load(_animation1))
	_animated_sprite.sprite_frames.set_frame("idle", 1, load(_animation2))
	_animated_sprite.sprite_frames.set_frame("idle", 2, load(_animation3))
	_animated_sprite.sprite_frames.set_frame("idle", 3, load(_animation4))

	_animated_sprite.play("idle")


func _on_animated_sprite_2d_animation_finished():
	await get_tree().create_timer(2).timeout
	queue_free()


func do_animation():
	_audio_player.stream = _pickup_sound
	_audio_player.play()
	if animation == "gold_coin" or animation == "silver_coin":
		_animated_sprite.play("coin_taken")
	else:
		_animated_sprite.play("diamond_taken")

	var type = POINT_TYPES.get(animation, "GoldCoin")
	var color = SPARKLE_COLORS.get(animation, Color.WHITE)
	Progress.mark_collected(self)
	var completed_set = HealthDashboard.collect(type)
	GameFeel.burst(global_position, color, 8, 60.0)
	GameFeel.popup_text(global_position + Vector2(0, -8), "+%d" % HealthDashboard.PICKUP_SCORES[type], color)
	if completed_set:
		# Third diamond colour: full health, once per run.
		GameFeel.popup_text(global_position + Vector2(0, -24), tr("DIAMOND_SET_BONUS"), BONUS_COLOR)
		GameFeel.burst(global_position, BONUS_COLOR, 16, 90.0)


func _on_body_entered(body):
	# Disabling the collider ensures the item is collected only once.
	if body.is_in_group("player") and not _taken:
		_collider.set_deferred("disabled", true)
		_taken = true
		do_animation()
