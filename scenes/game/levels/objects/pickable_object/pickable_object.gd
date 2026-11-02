extends Area2D
## Collectible coin or diamond.
##
## Loads the idle frames for the configured item, plays the pick-up animation
## when the player touches it, adds one point and frees itself.


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

# Sparkle colour of each item
const SPARKLE_COLORS = {
	"blue_diamond": Color(0.5, 0.75, 1),
	"green_diamond": Color(0.55, 0.95, 0.5),
	"red_diamond": Color(1, 0.45, 0.45),
	"gold_coin": Color(1, 0.85, 0.35),
	"silver_coin": Color(0.9, 0.9, 0.95),
}


func _ready():
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

	# Every item is worth one point of its type.
	var type = "GoldCoin"
	if animation == "silver_coin":
		type = "SilverCoin"
	elif animation == "blue_diamond":
		type = "BlueDiamond"
	elif animation == "green_diamond":
		type = "GreenDiamond"
	elif animation == "red_diamond":
		type = "RedDiamond"
	HealthDashboard.add_points(type, 1)
	GameFeel.burst(global_position, SPARKLE_COLORS.get(animation, Color.WHITE), 8, 60.0)


func _on_body_entered(body):
	# Disabling the collider ensures the item is collected only once.
	if body.is_in_group("player") and not _taken:
		_collider.set_deferred("disabled", true)
		_taken = true
		do_animation()
