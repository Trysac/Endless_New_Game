class_name EnemyBase
extends CharacterBody2D
## Shared behaviour for the Pirate Bomb enemies (Bald Pirate, Cucumber, Big Guy).
##
## Patrols (or stands guard), turns around at ledges and walls, turns to face
## a player seen behind it, optionally charges a player seen in front, attacks
## the player within reach and dies after `hits_to_die` sword hits (or a single
## power-up hit, or a bomb blast). Each enemy scene tunes the exported values.

enum State { PATROL, CHASE, ATTACK, HURT, ACTION, DEAD }

const GRAVITY = 600.0
const MAX_FALL_SPEED = 400.0
const KNOCKBACK_DECAY = 600.0
const TURN_DELAY = 0.25 # Seconds between two turns, avoids jittering at edges
const SPARK_COLOR = Color(1, 0.9, 0.55)

## Behaviour when no player is around: walk back and forth or stand still.
@export_enum("idle", "run") var animation := "run"
## Side the enemy faces at the start.
@export_enum("left", "right") var moving_direction := "left"
## Patrol speed (px/s).
@export var walk_speed := 30.0
## Speed while charging a player seen in front; 0 never charges.
@export var chase_speed := 0.0
## Life the player loses on each blow.
@export var attack_damage := 1
## Sword hits needed to kill it.
@export var hits_to_die := 3
## Attack animation frame on which the blow lands.
@export var attack_frame := 3
## Seconds before attacking again after a blow.
@export var attack_cooldown := 0.6
## Push received from the sword (px/s); heavy enemies barely move.
@export var knockback_speed := 120.0
## Playback speed of the hit animation (higher = shorter flinch).
@export var hit_speed_scale := 1.0
## Extra seconds standing still after the hit animation.
@export var hit_pause := 0.0
## Colour of the particles when a blow lands on the player.
@export var attack_color := Color(1, 0.8, 0.4)
## Colour of the particles when it dies.
@export var death_color := Color(0.95, 0.45, 0.3)
## Colour the sprite is tinted with.
@export var tint := Color.WHITE

var state := State.PATROL
var hits_taken := 0

var _punch_sound = preload("res://assets/sounds/punch.mp3")
var _attack_sound = preload("res://assets/sounds/slash.mp3")

var _facing_left := true
var _target: Node2D # Player inside the attack area
var _cooldown := 0.0
var _turn_delay := 0.0
var _pause := 0.0
var _knockback := 0.0

@onready var _flip: Node2D = $Flip
@onready var _sprite: AnimatedSprite2D = $Flip/Sprite
@onready var _ray_terrain: RayCast2D = $Flip/RayCastTerrain
@onready var _ray_wall: RayCast2D = $Flip/RayCastWall
@onready var _ray_front: RayCast2D = $Flip/RayCastVisionFront
@onready var _ray_back: RayCast2D = $Flip/RayCastVisionBack
@onready var _attack_area: Area2D = $Flip/AttackArea
@onready var _hurt_box: Area2D = $HurtBox
@onready var _audio: AudioStreamPlayer2D = $AudioStreamPlayer2D


func _ready():
	for ray in [_ray_terrain, _ray_wall, _ray_front, _ray_back]:
		ray.add_exception(self)
	_sprite.self_modulate = tint
	_set_facing(moving_direction != "right")
	_sprite.animation_finished.connect(_on_sprite_animation_finished)
	_sprite.frame_changed.connect(_on_sprite_frame_changed)
	_attack_area.body_entered.connect(_on_attack_area_body_entered)
	_attack_area.body_exited.connect(_on_attack_area_body_exited)
	_hurt_box.area_entered.connect(_on_hurt_box_area_entered)
	_play(animation)


func _physics_process(delta):
	_cooldown = maxf(_cooldown - delta, 0.0)
	_turn_delay = maxf(_turn_delay - delta, 0.0)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	if _knockback != 0.0:
		velocity.x = _knockback
		_knockback = move_toward(_knockback, 0.0, KNOCKBACK_DECAY * delta)
	else:
		velocity.x = _think(delta)
	move_and_slide()


## True once it has been killed.
func is_dead() -> bool:
	return state == State.DEAD


## Takes one hit from `source`. `lethal` kills at once (bomb blasts).
func take_hit(source: Vector2, lethal := false):
	if state == State.DEAD:
		return
	hits_taken += 1
	_audio.stream = _punch_sound
	_audio.play()
	_flash()
	var side = sign(global_position.x - source.x)
	_knockback = (side if side != 0 else 1.0) * knockback_speed
	GameFeel.burst(global_position + Vector2(0, -_half_height()), SPARK_COLOR, 8, 100.0)
	GameFeel.hitstop(0.05)
	GameFeel.shake(2.0, 0.12)
	if lethal or hits_taken >= hits_to_die:
		_die()
		return
	state = State.HURT
	_pause = 0.0
	_play("hit", hit_speed_scale)


# Returns the horizontal speed for this frame and updates the state.
func _think(delta) -> float:
	match state:
		State.PATROL, State.CHASE:
			if _target and _cooldown == 0.0 and _player_alive(_target):
				_start_attack()
				return 0.0
			if _sees_player(_ray_back):
				_turn()
			var seen = _sees_player(_ray_front)
			if seen and chase_speed > 0.0:
				state = State.CHASE
			elif state == State.CHASE and not seen:
				state = State.PATROL
			if state == State.CHASE:
				_play("run")
				return _direction() * chase_speed if _ray_terrain.is_colliding() else 0.0
			if animation == "run":
				if is_on_floor() and (not _ray_terrain.is_colliding() or _wall_ahead()):
					_turn()
				_play("run")
				return _direction() * walk_speed
			_play("idle")
			return 0.0
		State.HURT:
			if _pause > 0.0:
				_pause -= delta
				if _pause <= 0.0:
					_recover()
			return 0.0
	return 0.0


func _start_attack():
	state = State.ATTACK
	_play("attack")


# Plays a one-off animation during which the enemy stands still.
func _perform(anim: String):
	if state == State.DEAD:
		return
	state = State.ACTION
	_play(anim)


func _recover():
	if state == State.DEAD:
		return
	state = State.PATROL
	_play(animation)


func _land_attack():
	if not _player_alive(_target):
		return
	var move_script = _target.get_node("MainCharacterMovement")
	# Only show the blow when it lands (not while the player blinks).
	if move_script.hit(attack_damage, false, global_position):
		_audio.stream = _attack_sound
		_audio.play()
		var contact = (global_position + _target.global_position) / 2.0
		GameFeel.burst(contact + Vector2(0, -_half_height()), attack_color, 10, 110.0)


func _die():
	state = State.DEAD
	_knockback = 0.0
	velocity.x = 0.0
	# The body no longer blocks the player nor reacts to anything.
	collision_layer = 0
	_hurt_box.set_deferred("monitoring", false)
	_hurt_box.set_deferred("monitorable", false)
	_attack_area.set_deferred("monitoring", false)
	_play("dead_hit")
	GameFeel.burst(global_position + Vector2(0, -_half_height()), death_color, 18, 130.0)
	GameFeel.shake(3.0, 0.2)


func _sees_player(ray: RayCast2D) -> bool:
	var collider = ray.get_collider()
	return collider != null and collider.is_in_group("player") and _player_alive(collider)


func _wall_ahead() -> bool:
	var collider = _ray_wall.get_collider()
	return collider != null and not collider.is_in_group("player")


# True when `body` is a player that is still alive.
func _player_alive(body) -> bool:
	if not is_instance_valid(body):
		return false
	var move_script = body.get_node_or_null("MainCharacterMovement")
	return move_script != null and not move_script.is_dead()


func _turn():
	if _turn_delay > 0.0:
		return
	_turn_delay = TURN_DELAY
	_set_facing(not _facing_left)


func _set_facing(left: bool):
	_facing_left = left
	_flip.scale.x = 1.0 if left else -1.0


func _direction() -> float:
	return -1.0 if _facing_left else 1.0


func _half_height() -> float:
	return $CollisionShape2D.shape.size.y / 2.0


func _play(anim: String, speed := 1.0):
	_sprite.speed_scale = speed
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


# Flashes the sprite white for a moment.
func _flash():
	_sprite.modulate = Color(3, 3, 3)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)


func _on_sprite_frame_changed():
	if state == State.ATTACK and _sprite.animation == "attack" and _sprite.frame == attack_frame:
		_land_attack()


func _on_sprite_animation_finished():
	match _sprite.animation:
		"attack":
			if state == State.ATTACK:
				_cooldown = attack_cooldown
				_recover()
		"hit":
			if state == State.HURT:
				_pause = hit_pause
				if _pause <= 0.0:
					_recover()
				else:
					_play("idle")
		"dead_hit":
			_play("dead_ground")
		"dead_ground":
			var tween = create_tween()
			tween.tween_interval(0.4)
			tween.tween_property(self, "modulate:a", 0.0, 0.3)
			tween.tween_callback(queue_free)
		_:
			if state == State.ACTION:
				_recover()


func _on_attack_area_body_entered(body):
	if body.is_in_group("player"):
		_target = body


func _on_attack_area_body_exited(body):
	if body == _target:
		_target = null


func _on_hurt_box_area_entered(area):
	if state == State.DEAD:
		return
	if area.is_in_group("hit"):
		# A power-up sword hit kills at once and uses one charge.
		take_hit(area.global_position, EnemyRules.consume_special_attack())
	elif area.is_in_group("die"):
		take_hit(area.global_position, true)
