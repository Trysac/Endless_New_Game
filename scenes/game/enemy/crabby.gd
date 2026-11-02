extends CharacterBody2D
## Crabby enemy.
##
## Patrols or idles, chases the player when set to "active", attacks on contact
## and dies after a few hits (or one hit while a power-up is active).


## Animation (and behaviour) the enemy starts with.
@export_enum(
	"idle",
	"run",
) var animation: String

## Initial direction; "active" chases the player when seen.
@export_enum(
	"left",
	"right",
	"active",
) var moving_direction: String

@onready var _animation := $EnemyAnimation
@onready var _animation_effect := $EnemyEffect
@onready var _raycast_terrain := $Area2D/RayCastTerrain
@onready var _raycast_wall := $Area2D/RayCastWall
@onready var _raycast_vision_left := $Area2D/RayCastVisionLeft
@onready var _raycast_vision_right := $Area2D/RayCastVisionRight
@onready var _audio_player= $AudioStreamPlayer2D

# Push received from the sword, and how fast it fades (px/s, px/s²)
const KNOCKBACK_SPEED = 120.0
const KNOCKBACK_DECAY = 600.0
const SPARK_COLOR = Color(1, 0.9, 0.55)
const DEATH_COLOR = Color(0.95, 0.45, 0.3)

var _punch_sound = preload("res://assets/sounds/punch.mp3")

var _gravity = 10
var _speed = 25
var _moving_left = true
# Player currently in attack range
var _body: Node2D
var _is_chasing = false
# Stops chasing while attacking
var _stop_detection = false
# Set once dying: no more attacks
var _stop_attack = false
var _hits_to_die = 3
var _hits_taken = 0
var is_dead = false
var _knockback = 0.0 # Current knockback speed; overrides walking while not zero


func _ready():
	if moving_direction == 'right':
		_moving_left = false
		scale.x = -scale.x
	if not animation:
		animation = "idle"
	_init_state()


func _physics_process(delta):
	if _knockback != 0.0:
		velocity.x = _knockback
		velocity.y += _gravity
		_knockback = move_toward(_knockback, 0.0, KNOCKBACK_DECAY * delta)
		move_and_slide()
		return
	if (is_dead): return
	if animation == "run":
		_move_character(delta)
		_turn()
	elif animation == "idle":
		_move_idle()
	if moving_direction == "active" and !_stop_detection:
		_detection()


func _move_character(_delta):
	velocity.y += _gravity

	if _moving_left:
		velocity.x = - _speed
	else:
		velocity.x = _speed

	move_and_slide()


func _move_idle():
	velocity.y += _gravity
	velocity.x = 0
	move_and_slide()


func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		_stop_detection = true
		_body = body
		_attack()


func _on_area_2d_body_exited(_exited_body):
	if not is_dead:
		_init_state()


func _turn():
	# Turn around at the edge of the ground or at a wall (but not at the player).
	if not _raycast_terrain.is_colliding() or _raycast_wall.is_colliding():
		var _object = _raycast_wall.get_collider()
		if not _object or _object and not _object.is_in_group("player"):
			_moving_left = !_moving_left
			scale.x = -scale.x


# Starts attacking the player in range, if there is one and they are alive.
func _attack():
	if _stop_attack or not _body or _is_player_dead():
		return
	_animation.play("attack")


# True when the player in range is dead (no point in attacking them).
func _is_player_dead() -> bool:
	if not is_instance_valid(_body):
		return true
	var move_script = _body.get_node_or_null("MainCharacterMovement")
	return move_script == null or move_script.is_dead()


func _init_state():
	if _stop_attack:
		return
	velocity.x = 0
	_animation.play(animation)
	_animation_effect.play("idle")
	_body = null
	_stop_detection = false

func _on_enemy_animation_frame_changed():
	if _stop_attack:
		return
	# Damage lands on the first frame of the attack animation.
	if _animation.frame == 0 and _animation.get_animation() == "attack":
		# Stop attacking once the player is dead or gone.
		if _is_player_dead():
			_animation.play("idle")
			_animation_effect.play("idle")
			return

		# Only show the hit when it lands (not while the player blinks).
		if _body.get_node("MainCharacterMovement").hit(2, false, global_position):
			_animation_effect.play("attack_effect")


func _detection():
	# No ground ahead: go back to the initial state.
	if not _raycast_terrain.is_colliding():
		_init_state()
		return
	var _object1 = _raycast_vision_left.get_collider()
	var _object2 = _raycast_vision_right.get_collider()
	
	# Player seen by the left ray: charge
	if _object1 and _object1.is_in_group("player") and _raycast_vision_left.is_colliding():
		_move(true)
	else:
		_is_chasing = false
	
	# Player seen by the right ray: turn around
	if _object2 and _object2.is_in_group("player") and _raycast_vision_right.is_colliding():
		_move(false)
	
	if not _object1 and not _object2 and _animation.get_animation() != "attack":
		_is_chasing = false
		
		
func _move(_direction):
	if _is_chasing or _animation.get_animation() == "attack":
		return
	velocity.y += _gravity

	# false turns around, true charges in the current direction.
	if not _direction:
		_moving_left = !_moving_left
		scale.x = -scale.x
	else:
		if _moving_left:
			velocity.x = - _speed * 5
		else:
			velocity.x = _speed * 5

	move_and_slide()


func _on_area_2d_area_entered(area):
	if area.is_in_group("hit"):
		_damage(area.global_position)
	elif area.is_in_group("die"):
		is_dead = true
		_damage(area.global_position)

func _damage(source: Vector2):
	_hits_taken += 1
	_audio_player.stream = _punch_sound
	_audio_player.play()
	_animation.play("hit")
	_animation_effect.play("idle")
	_flash()
	var side = sign(global_position.x - source.x)
	_knockback = (side if side != 0 else 1.0) * KNOCKBACK_SPEED
	GameFeel.burst(global_position, SPARK_COLOR, 8, 100.0)
	GameFeel.hitstop(0.05)
	GameFeel.shake(2.0, 0.12)
	
	# A power-up attack kills in one hit and uses one charge.
	if Global.special_attacks_left > 0:
		is_dead = true
		Global.special_attacks_left -= 1
	
	# Out of charges: back to the normal attack.
	if Global.special_attacks_left == 0:
		Global.attack_effect = "normal"

	if is_dead or _hits_to_die <= _hits_taken:
		_stop_attack = true
		is_dead = true
		velocity.x = 0
		# Freed when the death animation ends
		if _animation.animation != "dead_ground":
			_animation.play("dead_ground")
			GameFeel.burst(global_position, DEATH_COLOR, 18, 130.0)
			GameFeel.shake(3.0, 0.2)


# Flashes the sprite white for a moment.
func _flash():
	_animation.modulate = Color(3, 3, 3)
	create_tween().tween_property(_animation, "modulate", Color.WHITE, 0.15)


func _on_enemy_animation_animation_finished():
	if _animation.animation == "dead_ground":
		queue_free()
	elif _animation.animation == "hit":
		if not _stop_attack: 
			_animation.play("idle")
			_animation_effect.play("idle")
			_attack()
