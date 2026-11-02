class_name Captain
extends CharacterBody2D
## The Captain: final boss of the game.
##
## Sleeps until [method activate] is called (the boss arena does it when it
## closes). Then it alternates three attacks, each announced by a short
## wind-up (exclamation mark and flashing) so the player can react:
## [br]- Dash: charges across the arena, hurting the player on contact.
## [br]- Bombs: throws bombs that land where the player stands and explode
##   after a short fuse.
## [br]- Slam: jumps onto the player and lands with a shock wave.
## [br]At half health it enters phase 2: shorter wind-ups and pauses, a second
## dash on the way back, three bombs at once and two slams in a row.
##
## Damage: a sword hit takes 1 health, a sword hit with a power-up takes
## [member power_hit_damage] (and uses one power-up charge, see
## [method EnemyRules.consume_special_attack]; unlike regular enemies the
## Captain never dies in one power-up hit) and a bomb blast takes
## [member bomb_damage]. When defeated it plays its death animation with a big
## burst, a screen shake and a slow-motion moment, then emits [signal defeated].

signal health_changed(health: int, max_health: int)
signal phase_changed(phase: int)
signal defeated

enum State { DORMANT, IDLE, WINDUP, DASH, THROW, SLAM, STAGGER, PHASE_CHANGE, DEAD }
enum Attack { DASH, BOMBS, SLAM }

const GRAVITY = 900.0
const MAX_FALL_SPEED = 600.0
const KNOCKBACK_DECAY = 400.0
const SLAM_JUMP_SPEED = 420.0
const SPARK_COLOR = Color(1, 0.9, 0.55)
const POWER_COLOR = Color(0.55, 0.85, 1)
const DUST_COLOR = Color(0.85, 0.8, 0.7)
const ENRAGED_TINT = Color(1, 0.72, 0.68)
const FLASH_COLOR = Color(2.4, 2.4, 2.4)
const SLOW_MOTION_SCALE = 0.25
const SLOW_MOTION_TIME = 1.4 # Real seconds
const SPRITE_DIR = "res://assets/sprites/pirate_bomb/5_enemy_captain/"
# Animation name -> [folder, frame count, frames per second, loops]
const ANIMATIONS = {
	"idle": ["1_idle", 32, 20.0, true],
	"run": ["2_run", 14, 18.0, true],
	"anticipation": ["3_jump_anticipation", 1, 10.0, false],
	"jump": ["4_jump", 4, 12.0, false],
	"fall": ["5_fall", 2, 10.0, true],
	"ground": ["6_ground", 3, 12.0, false],
	"attack": ["7_attack", 7, 14.0, false],
	"scare_run": ["8_scare_run", 12, 18.0, true],
	"hit": ["9_hit", 8, 24.0, false],
	"dead_hit": ["10_dead_hit", 6, 10.0, false],
	"dead_ground": ["11_dead_ground", 4, 8.0, false],
}
const EXCLAMATION_DIR = "res://assets/sprites/pirate_bomb/7_objects/5_exclamation_dialog/1-opening/%d.png"
const BOMB_SCENE = preload("res://scenes/game/enemy/captain/captain_bomb.tscn")
# Attack animation frame on which the bombs leave the hand
const THROW_FRAME = 3

## Health; one sword hit takes one point.
@export var max_health := 18
## Health taken by a sword hit while a power-up is active.
@export var power_hit_damage := 3
## Health taken by a bomb blast.
@export var bomb_damage := 3
## Life the player loses when run over by a dash or caught by a slam.
@export var contact_damage := 2
## Leftmost and rightmost x (global) the Captain moves between. The boss
## arena sets them when the fight starts.
@export var arena_left := -INF
@export var arena_right := INF

var health := 0
var phase := 1
var state := State.DORMANT

var _player: Node2D
var _facing_left := true
var _timer := 0.0 # Time left in the current state
var _next_attack := Attack.DASH
var _last_attack := -1
var _repeats_left := 0 # Extra dashes or slams left in the current attack
var _dash_direction := -1.0
var _airborne := false
var _knockback := 0.0
var _slowed := false
var _flash_time := 0.0
var _rng := RandomNumberGenerator.new()
var _punch_sound = preload("res://assets/sounds/punch.mp3")
var _slam_sound = preload("res://assets/sounds/explosion.mp3")

@onready var _flip: Node2D = $Flip
@onready var _sprite: AnimatedSprite2D = $Flip/Sprite
@onready var _exclamation: AnimatedSprite2D = $Exclamation
@onready var _hurt_box: Area2D = $HurtBox
@onready var _contact: Area2D = $ContactArea
@onready var _audio: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var _health_bar: CanvasLayer = $HealthBar
@onready var _bar: ProgressBar = $HealthBar/Root/Box/Bar
@onready var _bar_box: Control = $HealthBar/Root/Box


func _ready():
	health = max_health
	_sprite.sprite_frames = _build_frames()
	_sprite.animation_finished.connect(_on_sprite_animation_finished)
	_sprite.frame_changed.connect(_on_sprite_frame_changed)
	_exclamation.sprite_frames = _build_exclamation_frames()
	_exclamation.visible = false
	_hurt_box.area_entered.connect(_on_hurt_box_area_entered)
	_bar.max_value = max_health
	_bar.value = health
	_health_bar.visible = false
	_set_facing(true)
	_play("idle")


func _exit_tree():
	_end_slow_motion()


## Starts the fight against `player`, moving between `left` and `right`.
func activate(player: Node2D, left := arena_left, right := arena_right):
	if state != State.DORMANT:
		return
	_player = player
	arena_left = left
	arena_right = right
	if player is PhysicsBody2D:
		# The player walks through the Captain; only its attacks hurt.
		add_collision_exception_with(player)
	_health_bar.visible = true
	_bar_box.modulate.a = 0.0
	create_tween().tween_property(_bar_box, "modulate:a", 1.0, 0.4)
	GameFeel.popup_text(global_position + Vector2(0, -78), tr("BOSS_TAUNT"), Color(1, 0.85, 0.35))
	_enter_idle(1.2)


## True once it has been defeated.
func is_dead() -> bool:
	return state == State.DEAD


## True while the fight is going on.
func is_active() -> bool:
	return state != State.DORMANT and state != State.DEAD


## Wind-up time before each attack (shorter in phase 2).
func windup_time() -> float:
	return 0.6 if phase == 1 else 0.4


## Starts the wind-up of `attack` right away.
func perform(attack: Attack):
	if not is_active() or state == State.PHASE_CHANGE:
		return
	_next_attack = attack
	_last_attack = attack
	# Phase 2 dashes back once more and slams twice.
	_repeats_left = 1 if phase == 2 and attack != Attack.BOMBS else 0
	_start_windup(windup_time())


## Takes `amount` health from a blow coming from `source`. `powered` marks a
## power-up sword hit (shows the extra damage).
func take_damage(amount: int, source: Vector2, powered := false):
	if not is_active() or state == State.PHASE_CHANGE:
		return
	health = max(health - amount, 0)
	health_changed.emit(health, max_health)
	create_tween().tween_property(_bar, "value", float(health), 0.2)
	_audio.stream = _punch_sound
	_audio.play()
	_flash()
	var center = global_position + Vector2(0, -28)
	GameFeel.burst(center, POWER_COLOR if powered else SPARK_COLOR, 14 if powered else 8, 120.0)
	GameFeel.hitstop(0.08 if powered else 0.05)
	GameFeel.shake(4.0 if powered else 2.5, 0.15)
	if powered:
		GameFeel.popup_text(center + Vector2(0, -36), "-%d" % amount, POWER_COLOR)
	if health == 0:
		_die()
		return
	if phase == 1 and health * 2 <= max_health:
		_enter_phase_2()
		return
	# Staggers only between attacks, so hits never cancel an attack.
	if state == State.IDLE:
		var side = signf(global_position.x - source.x)
		_knockback = (side if side != 0.0 else 1.0) * 60.0
		state = State.STAGGER
		_timer = 0.3
		_play("hit")


func _physics_process(delta):
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	_update_flash(delta)
	match state:
		State.DORMANT, State.DEAD:
			velocity.x = 0.0
		State.IDLE:
			_process_idle(delta)
		State.STAGGER:
			velocity.x = _knockback
			_knockback = move_toward(_knockback, 0.0, KNOCKBACK_DECAY * delta)
			_timer -= delta
			if _timer <= 0.0:
				_enter_idle(0.4)
		State.WINDUP:
			velocity.x = 0.0
			_timer -= delta
			if _timer <= 0.0:
				_launch_attack()
		State.DASH:
			_process_dash(delta)
		State.THROW:
			velocity.x = 0.0
		State.SLAM:
			_process_slam(delta)
		State.PHASE_CHANGE:
			velocity.x = 0.0
			_timer -= delta
			if _timer <= 0.0:
				_enter_idle(0.5)
	move_and_slide()
	_keep_inside_arena()


func _process_idle(delta):
	_timer -= delta
	if _player_alive():
		_face(_player.global_position.x)
		var distance = absf(_player.global_position.x - global_position.x)
		if distance > 140.0:
			velocity.x = _direction() * (40.0 if phase == 1 else 60.0)
			_play("run")
		else:
			velocity.x = 0.0
			_play("idle")
	else:
		velocity.x = 0.0
		_play("idle")
		return
	if _timer <= 0.0:
		perform(_pick_attack())


func _process_dash(delta):
	_timer -= delta
	velocity.x = _dash_direction * _dash_speed()
	_hurt_player_on_contact()
	var at_edge = (_dash_direction < 0.0 and global_position.x <= arena_left + 24.0) \
			or (_dash_direction > 0.0 and global_position.x >= arena_right - 24.0)
	if is_on_wall() or at_edge or _timer <= 0.0:
		velocity.x = 0.0
		GameFeel.shake(3.0, 0.15)
		GameFeel.burst(global_position + Vector2(_dash_direction * 18.0, -10), DUST_COLOR, 8, 70.0)
		if _repeats_left > 0:
			# Phase 2: turn around and dash back after a short warning.
			_repeats_left -= 1
			_next_attack = Attack.DASH
			_start_windup(0.3)
		else:
			_enter_idle(_rest_time())


func _process_slam(_delta):
	if not _airborne:
		velocity.x = 0.0
		return
	if velocity.y > 0.0:
		_play("fall")
		_hurt_player_on_contact()
	if is_on_floor() and velocity.y >= 0.0:
		_land_slam()


func _pick_attack() -> Attack:
	var options = [Attack.DASH, Attack.BOMBS, Attack.SLAM]
	options.erase(_last_attack)
	return options[_rng.randi() % options.size()]


func _start_windup(time: float):
	state = State.WINDUP
	_timer = time
	velocity.x = 0.0
	if _player_alive():
		_face(_player.global_position.x)
	_play("anticipation")
	_exclamation.visible = true
	_exclamation.frame = 0
	_exclamation.play("open")
	_flash_time = time


func _launch_attack():
	_exclamation.visible = false
	_flash_time = 0.0
	_sprite.modulate = Color.WHITE
	match _next_attack:
		Attack.DASH:
			state = State.DASH
			_dash_direction = _direction()
			_timer = 2.0
			_play("run", 1.6)
		Attack.BOMBS:
			state = State.THROW
			_play("attack")
		Attack.SLAM:
			_jump_at_player()


func _jump_at_player():
	state = State.SLAM
	var target_x = global_position.x
	if _player_alive():
		target_x = _player.global_position.x
	target_x = clampf(target_x, arena_left + 30.0, arena_right - 30.0)
	var air_time = 2.0 * SLAM_JUMP_SPEED / GRAVITY
	velocity = Vector2((target_x - global_position.x) / air_time, -SLAM_JUMP_SPEED)
	_face(target_x)
	_airborne = true
	_play("jump")


func _land_slam():
	_airborne = false
	velocity.x = 0.0
	_play("ground")
	_audio.stream = _slam_sound
	_audio.play()
	var radius = slam_radius()
	GameFeel.shake(6.0 if phase == 1 else 8.0, 0.35)
	GameFeel.burst(global_position + Vector2(-radius * 0.5, -4), DUST_COLOR, 10, 90.0, 60.0)
	GameFeel.burst(global_position + Vector2(radius * 0.5, -4), DUST_COLOR, 10, 90.0, 60.0)
	# The shock wave hurts a player standing on the ground nearby.
	if _player_alive():
		var player_body = _player as CharacterBody2D
		var on_ground = player_body == null or player_body.is_on_floor()
		var dx = absf(_player.global_position.x - global_position.x)
		var dy = absf(_player.global_position.y - (global_position.y - 12.0))
		if on_ground and dx <= radius and dy <= 24.0:
			_hit_player()
	var pause = 0.35
	if _repeats_left > 0:
		_repeats_left -= 1
		# A tween owned by the Captain: nothing runs if it is freed meanwhile.
		create_tween().tween_callback(_slam_again).set_delay(pause)
	else:
		_enter_idle(_rest_time() + pause)


func _slam_again():
	if state == State.SLAM and not _airborne:
		_jump_at_player()


## Reach of the slam's shock wave (wider in phase 2).
func slam_radius() -> float:
	return 70.0 if phase == 1 else 110.0


func _throw_bombs():
	if not _player_alive():
		return
	var offsets = [0.0] if phase == 1 else [-60.0, 0.0, 60.0]
	# Bombs land at the player's feet.
	var target_y = _player.global_position.y + 11.0
	for offset in offsets:
		var bomb: CaptainBomb = BOMB_SCENE.instantiate()
		get_parent().add_child(bomb)
		bomb.global_position = global_position + Vector2(_direction() * 22.0, -44.0)
		var target_x = clampf(_player.global_position.x + offset, arena_left + 16.0, arena_right - 16.0)
		bomb.launch(Vector2(target_x, target_y), 0.8)


func _enter_idle(time: float):
	state = State.IDLE
	_timer = time
	_repeats_left = 0
	_play("idle")


func _rest_time() -> float:
	return 1.1 if phase == 1 else 0.7


func _dash_speed() -> float:
	return 230.0 if phase == 1 else 300.0


func _enter_phase_2():
	phase = 2
	state = State.PHASE_CHANGE
	_timer = 1.2
	_repeats_left = 0
	_airborne = false
	_exclamation.visible = false
	_flash_time = 0.0
	_sprite.self_modulate = ENRAGED_TINT
	_play("scare_run", 1.4)
	GameFeel.shake(5.0, 0.5)
	GameFeel.burst(global_position + Vector2(0, -30), Color(1, 0.35, 0.3), 20, 140.0)
	GameFeel.popup_text(global_position + Vector2(0, -80), tr("BOSS_ENRAGED"), Color(1, 0.45, 0.4))
	phase_changed.emit(phase)


func _die():
	state = State.DEAD
	velocity = Vector2.ZERO
	_airborne = false
	_knockback = 0.0
	_exclamation.visible = false
	_flash_time = 0.0
	_sprite.modulate = Color.WHITE
	_hurt_box.set_deferred("monitoring", false)
	_hurt_box.set_deferred("monitorable", false)
	_contact.set_deferred("monitoring", false)
	create_tween().tween_property(_bar_box, "modulate:a", 0.0, 0.6)
	_play("dead_hit")
	var center = global_position + Vector2(0, -30)
	GameFeel.burst(center, Color(1, 0.62, 0.25), 40, 220.0)
	GameFeel.burst(center, Color(1, 0.9, 0.55), 30, 160.0)
	GameFeel.burst(center, Color(0.95, 0.4, 0.3), 24, 120.0)
	GameFeel.shake(9.0, 0.9)
	_victory_slow_motion()


func _victory_slow_motion():
	# Real-time steps; the hit-stop of the last blow finishes first.
	# It keeps running while paused so the menu never opens in slow motion.
	var tween = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(0.1)
	tween.tween_callback(_start_slow_motion)
	tween.tween_interval(SLOW_MOTION_TIME)
	tween.tween_callback(_end_slow_motion)
	tween.tween_callback(defeated.emit)


func _start_slow_motion():
	Engine.time_scale = SLOW_MOTION_SCALE
	_slowed = true


func _end_slow_motion():
	if _slowed:
		_slowed = false
		Engine.time_scale = 1.0


func _hurt_player_on_contact():
	for body in _contact.get_overlapping_bodies():
		if body == _player:
			_hit_player()


func _hit_player():
	if not _player_alive():
		return
	var movement = _player.get_node_or_null("MainCharacterMovement")
	if movement and movement.hit(contact_damage, false, global_position):
		GameFeel.burst((global_position + _player.global_position) / 2.0 + Vector2(0, -16), Color(1, 0.45, 0.3), 10, 110.0)


func _player_alive() -> bool:
	if not is_instance_valid(_player):
		return false
	var movement = _player.get_node_or_null("MainCharacterMovement")
	return movement != null and not movement.is_dead()


func _keep_inside_arena():
	if global_position.x < arena_left:
		global_position.x = arena_left
	elif global_position.x > arena_right:
		global_position.x = arena_right


func _face(x: float):
	if absf(x - global_position.x) > 4.0:
		_set_facing(x < global_position.x)


func _set_facing(left: bool):
	_facing_left = left
	# The sprites look to the right.
	_flip.scale.x = -1.0 if left else 1.0


func _direction() -> float:
	return -1.0 if _facing_left else 1.0


func _play(anim: String, speed := 1.0):
	_sprite.speed_scale = speed
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


# Flashes the sprite white for a moment.
func _flash():
	_sprite.modulate = FLASH_COLOR
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)


# Blinks the sprite during a wind-up so the attack can be seen coming.
func _update_flash(delta):
	if _flash_time <= 0.0:
		return
	_flash_time -= delta
	_sprite.modulate = FLASH_COLOR if fmod(_flash_time, 0.16) < 0.08 else Color.WHITE
	if _flash_time <= 0.0:
		_sprite.modulate = Color.WHITE


func _build_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	frames.remove_animation("default")
	for anim in ANIMATIONS:
		var info = ANIMATIONS[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, info[2])
		frames.set_animation_loop(anim, info[3])
		for i in info[1]:
			frames.add_frame(anim, load(SPRITE_DIR + info[0] + "/%d.png" % (i + 1)))
	return frames


func _build_exclamation_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	frames.rename_animation("default", "open")
	frames.set_animation_speed("open", 16.0)
	frames.set_animation_loop("open", false)
	for i in 4:
		frames.add_frame("open", load(EXCLAMATION_DIR % (i + 1)))
	return frames


func _on_sprite_frame_changed():
	if state == State.THROW and _sprite.animation == "attack" and _sprite.frame == THROW_FRAME:
		_throw_bombs()


func _on_sprite_animation_finished():
	match _sprite.animation:
		"attack":
			if state == State.THROW:
				_enter_idle(_rest_time())
		"ground":
			if state == State.SLAM:
				_play("idle")
		"dead_hit":
			_play("dead_ground")


func _on_hurt_box_area_entered(area):
	# Hits during the phase change are ignored, so they must not use a charge.
	if not is_active() or state == State.PHASE_CHANGE:
		return
	if area.is_in_group("hit"):
		# A power-up sword hit uses one charge; it deals extra damage instead
		# of the one-hit kill regular enemies get.
		var powered = EnemyRules.consume_special_attack()
		take_damage(power_hit_damage if powered else 1, area.global_position, powered)
	elif area.is_in_group("die"):
		take_damage(bomb_damage, area.global_position)
