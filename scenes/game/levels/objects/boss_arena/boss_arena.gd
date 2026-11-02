class_name BossArena
extends Node2D
## Boss arena: closes behind the player and starts the boss fight.
##
## The node sits at the top-left corner of the arena entrance. When the
## player walks into the arena a gate of rock rises from the ground behind
## them, the camera stays inside the arena, the level music fades into the
## boss music and the boss wakes up. Once the boss is defeated the music fades
## out and the exit appears.

signal closed
signal cleared

const TILE_SIZE = 32
const GATE_SOURCE = 3 # Palm tree island terrain atlas of bg_tile_set
const GATE_TILE = Vector2i(4, 1) # Middle of a one-tile-wide rock pillar
const DUST_COLOR = Color(0.85, 0.8, 0.7)
const EXIT_COLOR = Color(1, 0.85, 0.35)
const MUSIC_FADE_TIME = 0.8

## Boss fought here.
@export var boss: Captain
## Exit shown once the boss is defeated; hidden and inactive until then.
@export var exit: Node2D
## Level music that fades out when the fight starts.
@export var level_music: AudioStreamPlayer
## Level camera, kept inside the arena during the fight.
@export var camera: Camera2D
## Floor-to-floor width of the arena, from the gate to the far wall (px).
@export var arena_width := 608.0
## Gate height in tiles (the entrance height).
@export var gate_height := 3

var _closed := false
var _cleared := false

@onready var _gate: Node2D = $Gate
@onready var _gate_tiles: TileMapLayer = $Gate/Tiles
@onready var _trigger: Area2D = $Trigger
@onready var _trigger_shape: CollisionShape2D = $Trigger/CollisionShape2D
@onready var _boss_music: AudioStreamPlayer = $BossMusic
@onready var _gate_sound: AudioStreamPlayer2D = $GateSound


func _ready():
	for i in gate_height:
		_gate_tiles.set_cell(Vector2i(0, i), GATE_SOURCE, GATE_TILE)
	_gate_tiles.collision_enabled = false
	_gate.visible = false
	_gate.position.y = gate_height * TILE_SIZE
	# The fight starts a few steps inside, so the gate never closes on the player.
	var floor_y = gate_height * TILE_SIZE
	var shape = RectangleShape2D.new()
	shape.size = Vector2(arena_width - 3 * TILE_SIZE, floor_y + 160.0)
	_trigger_shape.shape = shape
	_trigger_shape.position = Vector2(TILE_SIZE * 4 + shape.size.x / 2.0, floor_y - shape.size.y / 2.0)
	_trigger.body_entered.connect(_on_trigger_body_entered)
	if exit:
		exit.visible = false
		exit.process_mode = Node.PROCESS_MODE_DISABLED


## True once the gate has closed behind the player.
func is_closed() -> bool:
	return _closed


## True once the boss has been defeated.
func is_cleared() -> bool:
	return _cleared


## Closes the arena and starts the fight against `player`.
func close(player: Node2D):
	if _closed:
		return
	_closed = true
	_trigger.set_deferred("monitoring", false)
	_raise_gate()
	_lock_camera()
	_fade_out(level_music)
	_boss_music.volume_db = 0.0
	_boss_music.play()
	if boss:
		boss.defeated.connect(_on_boss_defeated, CONNECT_ONE_SHOT)
		var left = global_position.x + TILE_SIZE + 18.0
		boss.activate(player, left, global_position.x + TILE_SIZE + arena_width - 18.0)
	closed.emit()


func _raise_gate():
	_gate.visible = true
	_gate_tiles.collision_enabled = true
	var tween = create_tween()
	tween.tween_property(_gate, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_gate_sound.play()
	GameFeel.shake(5.0, 0.4)
	var base = global_position + Vector2(TILE_SIZE / 2.0, gate_height * TILE_SIZE)
	GameFeel.burst(base, DUST_COLOR, 16, 90.0, 80.0)


# Moves the camera limits to the arena walls, sliding them from the current
# view so the camera does not jump.
func _lock_camera():
	if not camera:
		return
	var left = int(global_position.x)
	var right = int(global_position.x + TILE_SIZE * 2 + arena_width)
	var view_half = get_viewport_rect().size.x / camera.zoom.x / 2.0
	var center = camera.get_screen_center_position().x
	camera.limit_left = int(minf(center - view_half, left))
	camera.limit_right = int(maxf(center + view_half, right))
	var tween = create_tween().set_parallel(true)
	tween.tween_property(camera, "limit_left", left, 0.8)
	tween.tween_property(camera, "limit_right", right, 0.8)


func _fade_out(player: AudioStreamPlayer):
	if not player or not player.playing:
		return
	var tween = create_tween()
	tween.tween_property(player, "volume_db", -40.0, MUSIC_FADE_TIME)
	tween.tween_callback(player.stop)


func _on_trigger_body_entered(body):
	if body.is_in_group("player") and body is CharacterBody2D:
		close(body)


func _on_boss_defeated():
	_cleared = true
	_fade_out(_boss_music)
	if exit:
		exit.visible = true
		exit.process_mode = Node.PROCESS_MODE_INHERIT
		exit.modulate.a = 0.0
		create_tween().tween_property(exit, "modulate:a", 1.0, 0.6)
		GameFeel.burst(exit.global_position + Vector2(0, 20), EXIT_COLOR, 24, 110.0)
		GameFeel.popup_text(exit.global_position + Vector2(0, -16), tr("BOSS_EXIT_OPEN"), EXIT_COLOR)
	cleared.emit()
