extends Node2D
## Character movement and animation controller.
##
## Reads the movement input to move the character through the level
## and picks the animation that matches the movement.


@export var character: CharacterBody2D # Character to move
@export var main_animation: AnimatedSprite2D # Character sprite
@export var effect_animation_sword: AnimatedSprite2D # Sword slash effect sprite
@export var audio_player: AudioStreamPlayer2D
@onready var _collision := $"../AreaSword/CollisionShape2D" # Sword hitbox

var fall_damage = 2

# Seconds after taking damage during which further damage is ignored
const INVULNERABILITY_TIME = 1.0
# Seconds per blink while invulnerable
const BLINK_PERIOD = 0.2

var gravity = 650
var velocity = 100 # Horizontal speed
var jump = 220 # Jump strength: the higher, the higher the jump

var distance_to_damage:float = 50 # Maximum fall height before taking fall damage
var current_position:float = 0
var last_position:float = 0

# Animation names for each movement
var _movements = {
	IDLE = "default",
	IDLE_WITH_SWORD = "idle_with_sword",
	LEFT_WITH_SWORD = "left_with_sword",
	RIGHT_WITH_SWORD = "run_with_sword",
	JUMP_WITH_SWORD = "jump_with_sword",
	FALL_WITH_SWORD = "fall_with_sword",
	HIT_WITH_SWORD = "hit_with_sword",
	DEAD_HIT = "dead_hit",
	ATTACK = "attack_2",
	BOMB = "attack_3",
}
var _current_movement = _movements.IDLE
var _is_jumping = false
var _max_jumps = 3
var _jump_count = 0
var _died = false
var attacking = false
var bombing = false
var _is_playing: String = "" # Name of the sound currently playing
var turn_side: String = "right" # Side the character is facing
var _invulnerable = false # True for a short while after taking damage
var _blink_tween: Tween


var _jump_sound = preload("res://assets/sounds/jump.mp3")
var _run_sound = preload("res://assets/sounds/running.mp3")
var _dead_sound = preload("res://assets/sounds/dead.mp3")
var _male_hurt_sound = preload("res://assets/sounds/male_hurt.mp3")
var _hit_sound = preload("res://assets/sounds/slash.mp3")


func _ready():
	main_animation.play(_current_movement)
	if not character:
		set_physics_process(false)


func _physics_process(_delta):
	_move(_delta)


func _unhandled_input(event):
	if event.is_action_released("attack"):
		character.velocity.x = 0
		_current_movement = _movements.ATTACK
	elif event.is_action_released("throw_bomb"):
		_current_movement = _movements.BOMB
	_set_animation()


func _move(delta):
	if Input.is_action_pressed("move_left"):
		character.velocity.x = -velocity
		_current_movement = _movements.LEFT_WITH_SWORD
		turn_side = "left"
	elif Input.is_action_pressed("move_right"):
		character.velocity.x = velocity
		_current_movement = _movements.RIGHT_WITH_SWORD
		turn_side = "right"
	else:
		character.velocity.x = 0
		_current_movement = _movements.IDLE

	if Input.is_action_just_pressed("jump"):
		if character.is_on_floor():
			_current_movement = _movements.JUMP_WITH_SWORD
			if last_position == 0:
				last_position = character.position.y
			_is_jumping = true
			_jump_count += 1
		elif _is_jumping and _jump_count < _max_jumps:
			# Extra jumps in the air
			_current_movement = _movements.JUMP_WITH_SWORD
			_jump_count += 1

	_apply_gravity(delta)

	# A dead character cannot move horizontally.
	if _died:
		character.velocity.x = 0

	_set_animation()
	character.move_and_slide()


# Plays the animation that matches the current movement.
func _set_animation():
	# Do not interrupt an attack or bomb animation.
	if attacking or bombing:
		return
	if _died:
		main_animation.play(_movements.DEAD_HIT)
		return
	if _is_jumping:
		if character.velocity.y >= 0:
			main_animation.play(_movements.FALL_WITH_SWORD)
		else:
			main_animation.play(_movements.JUMP_WITH_SWORD)
	elif _current_movement == _movements.ATTACK:
		attacking = true
		main_animation.play(_movements.ATTACK)
		_play_sound(_hit_sound)
		_play_sword_effect()
	elif _current_movement == _movements.BOMB:
		bombing = true
		main_animation.play(_movements.BOMB)
	elif _current_movement == _movements.RIGHT_WITH_SWORD:
		main_animation.play(_movements.RIGHT_WITH_SWORD)
		main_animation.flip_h = false
		_collision.position.x = abs(_collision.position.x)
	elif _current_movement == _movements.LEFT_WITH_SWORD:
		# Running left reuses the run animation, flipped.
		main_animation.play(_movements.RIGHT_WITH_SWORD)
		main_animation.flip_h = true
		_collision.position.x = - abs(_collision.position.x)
	else:
		main_animation.play(_movements.IDLE_WITH_SWORD)
		audio_player.stop()
		_is_playing = ""


# Applies jump impulse or gravity, and fall damage on landing.
func _apply_gravity(delta):
	var v = character.velocity
	if last_position == 0:
		last_position = character.position.y
	# The jump impulse is applied only on the frame the jump starts.
	if _current_movement == _movements.JUMP_WITH_SWORD and not _died:
		v.y = -jump
	else:
		v.y += gravity * delta
		# Back on the floor after a jump: reset the jump state.
		if character.is_on_floor():
			_is_jumping = false
			current_position = character.position.y
			_jump_count = 0
			# Fell too far: take fall damage.
			if abs(last_position - current_position) >= distance_to_damage:
				if current_position > last_position:
					fall()
			last_position = 0
			current_position = 0
	character.velocity = v

func die():
	_died = true


# True once the character has died.
func is_dead() -> bool:
	return _died


# Takes damage. Every damage source goes through here.
# Damage taken while invulnerable is ignored unless `ignore_invulnerability`
# is set (used by instant-death zones).
func hit(value: int, ignore_invulnerability := false):
	if _died:
		return
	if _invulnerable and not ignore_invulnerability:
		return
	attacking = false
	HealthDashboard.remove_life(value)
	_play_sound(_male_hurt_sound)
	main_animation.play("hit_with_sword")

	if HealthDashboard.life == 0:
		_died = true
		_stop_blink()
	else:
		_start_invulnerability()


# Ignores damage for INVULNERABILITY_TIME seconds while the sprite blinks.
func _start_invulnerability():
	_invulnerable = true
	_stop_blink()
	_blink_tween = create_tween()
	_blink_tween.set_loops(int(round(INVULNERABILITY_TIME / BLINK_PERIOD)))
	_blink_tween.tween_property(main_animation, "modulate:a", 0.3, BLINK_PERIOD / 2)
	_blink_tween.tween_property(main_animation, "modulate:a", 1.0, BLINK_PERIOD / 2)
	_blink_tween.finished.connect(_end_invulnerability)


func _end_invulnerability():
	_invulnerable = false
	main_animation.modulate.a = 1.0


func _stop_blink():
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	main_animation.modulate.a = 1.0

func _on_animation_animation_finished():
	if main_animation.get_animation() == 'dead_hit':
		if _is_playing != "_dead_sound":
			_is_playing = "_dead_sound"
			_play_sound(_dead_sound)
	elif main_animation.get_animation() == _movements.ATTACK:
		attacking = false
	elif main_animation.get_animation() == _movements.BOMB:
		bombing = false


func _on_animation_frame_changed():
	# The sword hitbox is only active on the attack's second frame.
	if main_animation.animation == "attack_2" and main_animation.frame == 1:
		_collision.set_deferred("disabled", false)
	else:
		_collision.set_deferred("disabled", true)

	# Start each movement sound only once while its animation runs.
	if main_animation.animation == _movements.JUMP_WITH_SWORD:
		if _is_playing != "_jump_sound":
			_is_playing = "_jump_sound"
			_play_sound(_jump_sound)
	if (
		main_animation.animation == _movements.RIGHT_WITH_SWORD
		or main_animation.animation == _movements.LEFT_WITH_SWORD
	):
		if _is_playing != "_run_sound":
			_is_playing = "_run_sound"
			_play_sound(_run_sound)


func _on_audio_stream_player_2d_finished():
	if audio_player.stream == _dead_sound:
		# Remove the character and restart the level.
		self.get_parent().queue_free()
		SceneTransition.reload_scene()


func _play_sound(sound):
	audio_player.stop()
	audio_player.stream = sound
	audio_player.play()

func set_disabled(disabled: bool):
	set_physics_process(not disabled)

func set_idle():
	main_animation.play(_movements.IDLE_WITH_SWORD)
	audio_player.stop()

# Tints the sword slash with the active power-up colour.
func _play_sword_effect():
	var type = Global.attack_effect
	if type == "blue_potion":
		effect_animation_sword.self_modulate = Color("#70a2ff")
	elif type == "green_bottle":
		effect_animation_sword.self_modulate = Color("#80b65a")
	else:
		effect_animation_sword.self_modulate = Color("#ffffff")

	effect_animation_sword.play("attack_2_effect")

func fall():
	HealthDashboard.remove_life(fall_damage)
