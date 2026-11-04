extends Node
## Records the README gameplay GIF frames with Movie Maker mode.
##
## Presses Start like a player, then plays level 1 with a small bot that
## sends the real input actions: it runs right, jumps at walls and gaps
## (jumping again in the air up tall walls) and slashes the enemies in front
## of it. It lives under tools/, which the export presets leave out, so the
## shipped game never contains it. Run it with:
##
##   godot --path . --write-movie <folder>/frame.png --fixed-fps 15 \
##       --quit-after 300 res://tools/capture/gameplay_capture.tscn
##
## Each frame is then <folder>/frameNNNNNNNN.png; the README GIF is frames
## 158-247 turned into a GIF with ffmpeg (palettegen/paletteuse).


const LEVEL := "res://scenes/game/levels/rooms/scene_1/scene_1.tscn"
const REACH := 56.0 # Distance (px) at which the bot swings at an enemy in front
const SWING_GAP := 0.45 # Seconds between two swings
const JUMP_HOLD := 0.15 # Seconds the jump button stays down

var driver := false # The copy that survives the scene change and plays
var _playing := false
var _swing_wait := 0.0
var _jump_left := 0.0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if driver:
		return
	# English HUD for the README, without touching the saved settings.
	TranslationServer.set_locale("en")
	# The level replaces this scene, so the bot runs from a copy on the root.
	var copy = load(get_script().resource_path).new()
	copy.driver = true
	get_tree().root.add_child.call_deferred(copy)
	MainMenu.call_deferred("_on_button_pressed")
	set_process(false)


func _physics_process(delta):
	if not driver:
		return
	var level = get_tree().current_scene
	if not _playing:
		if level and level.scene_file_path == LEVEL and not SceneTransition.visible:
			_playing = true
			_send("move_right", true)
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	_swing_wait -= delta
	if _jump_left > 0.0:
		_jump_left -= delta
		if _jump_left <= 0.0:
			_send("jump", false)
	elif player.is_on_floor() and (player.is_on_wall() or _gap_ahead(player)):
		_send("jump", true)
		_jump_left = JUMP_HOLD
	elif player.is_on_wall() and player.velocity.y > -20.0:
		# Still against the wall at the top of the jump: jump again in the air.
		_send("jump", true)
		_jump_left = JUMP_HOLD
	if _swing_wait <= 0.0 and _enemy_in_front(level, player):
		_send("attack", true)
		_send("attack", false)
		_swing_wait = SWING_GAP


func _enemy_in_front(level: Node, player: Node2D) -> bool:
	for node in level.get_children():
		if node is CharacterBody2D and node != player and node.visible:
			var offset: Vector2 = node.global_position - player.global_position
			if offset.x > -8.0 and offset.x < REACH and absf(offset.y) < 44.0:
				return true
	return false


# True when there is no floor a little ahead of the player's feet.
func _gap_ahead(player: CharacterBody2D) -> bool:
	var from := player.global_position + Vector2(18, 0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 48))
	query.exclude = [player.get_rid()]
	return get_viewport().world_2d.direct_space_state.intersect_ray(query).is_empty()


func _send(action: String, pressed: bool):
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
