class_name CaptainBomb
extends Node2D
## Bomb thrown by the Captain.
##
## Flies along an arc to a target point, lands with its fuse burning (the
## flashing is the warning) and explodes shortly after, hurting the player
## inside the blast. It deals far less damage than the player's own bombs or
## the cannons (which take a full health bar), so a boss pattern stays fair,
## and it never hurts the Captain.

const GRAVITY = 600.0
const BOMB_FRAMES = "res://assets/sprites/pirate_bomb/7_objects/1_bomb/2-bomb on/%d.png"
const BOMB_FRAME_COUNT = 10
const BLAST_FRAMES = "res://assets/sprites/pirate_bomb/7_objects/1_bomb/3-explotion/%d.png"
const BLAST_FRAME_COUNT = 9
const BLAST_COLOR = Color(1, 0.62, 0.25)
const WARNING_COLOR = Color(1, 0.35, 0.3)

## Seconds the bomb lies on the ground before exploding.
@export var fuse_time := 0.6
## Distance from the bomb within which the player is hurt.
@export var blast_radius := 34.0
## Life the player loses when caught in the blast.
@export var damage := 2

var _velocity := Vector2.ZERO
var _flight_left := 0.0
var _fuse_left := 0.0
var _exploded := false

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _blast: AnimatedSprite2D = $Blast
@onready var _audio: AudioStreamPlayer2D = $AudioStreamPlayer2D


func _ready():
	_sprite.sprite_frames = _frames("on", BOMB_FRAMES, BOMB_FRAME_COUNT, 20.0, true)
	_sprite.play("on")
	_blast.sprite_frames = _frames("blast", BLAST_FRAMES, BLAST_FRAME_COUNT, 18.0, false)
	_blast.visible = false
	_blast.animation_finished.connect(queue_free)


## Throws the bomb from its current position so that it lands on `target`
## after `flight_time` seconds.
func launch(target: Vector2, flight_time: float):
	_flight_left = flight_time
	var delta = target - global_position
	_velocity = Vector2(delta.x / flight_time, (delta.y - 0.5 * GRAVITY * flight_time * flight_time) / flight_time)


## True once it has gone off.
func has_exploded() -> bool:
	return _exploded


func _physics_process(delta):
	if _exploded:
		return
	if _flight_left > 0.0:
		var step = minf(delta, _flight_left)
		global_position += _velocity * step + Vector2(0, 0.5 * GRAVITY * step * step)
		_velocity.y += GRAVITY * step
		_sprite.rotation += 8.0 * step * signf(_velocity.x)
		_flight_left -= step
		if _flight_left <= 0.0:
			_land()
		return
	_fuse_left -= delta
	# Blink faster and faster as the fuse runs out.
	_sprite.modulate = WARNING_COLOR if fmod(_fuse_left, 0.12) < 0.06 else Color.WHITE
	if _fuse_left <= 0.0:
		explode()


## Blows up at once, hurting the player if they are inside the blast.
func explode():
	if _exploded:
		return
	_exploded = true
	_sprite.visible = false
	_blast.visible = true
	_blast.play("blast")
	_audio.play()
	GameFeel.burst(global_position + Vector2(0, -6), BLAST_COLOR, 16, 120.0)
	GameFeel.shake(3.5, 0.25)
	for player in get_tree().get_nodes_in_group("player"):
		if not player is CharacterBody2D:
			continue
		# Measure from the middle of the player's body.
		var body_center = player.global_position + Vector2(0, -4)
		if body_center.distance_to(global_position + Vector2(0, -8)) <= blast_radius:
			var movement = player.get_node_or_null("MainCharacterMovement")
			if movement:
				movement.hit(damage, false, global_position)


func _land():
	_fuse_left = fuse_time
	_sprite.rotation = 0.0
	GameFeel.burst(global_position, Color(0.85, 0.8, 0.7), 5, 40.0, 70.0)


static func _frames(anim: String, pattern: String, count: int, fps: float, loop: bool) -> SpriteFrames:
	var frames = SpriteFrames.new()
	frames.rename_animation("default", anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for i in count:
		frames.add_frame(anim, load(pattern % (i + 1)))
	return frames
