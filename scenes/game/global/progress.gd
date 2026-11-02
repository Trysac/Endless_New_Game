extends Node
## Run progress: respawn points, checkpoints and the saved best score.
##
## A run starts from the main menu. Every scene entered through
## [method SceneTransition.change_scene] gets a respawn point: the level start,
## or the last checkpoint touched in it. Dying restores the HUD state saved at
## that point (with full health) and reloads the level, placing the player at
## the checkpoint. Pickups collected before the respawn point stay collected
## (they free themselves when the level reloads) and the ones collected after
## it come back, so no pickup is ever counted twice. Changing level clears the
## checkpoint.
##
## The best run score and the furthest level reached are saved in a
## ConfigFile, separate from the settings file.


signal best_score_changed(score: int)

## Levels in the order they are played; the furthest one reached is saved.
const LEVELS: Array[String] = [
	"res://scenes/game/levels/rooms/scene_1/scene_1.tscn",
	"res://scenes/game/levels/rooms/scene_4/scene_4.tscn",
	"res://scenes/game/levels/rooms/scene_2/scene_2.tscn",
	"res://scenes/game/levels/rooms/scene_3/scene_3.tscn",
]
const SECTION = "progress"
const KEY_BEST_SCORE = "best_score"
const KEY_FURTHEST_LEVEL = "furthest_level"

## File the progress is stored in.
var path = "user://progress.cfg"
## Highest run score ever reached.
var best_score = 0
## Number of levels reached so far (1 = the first level), 0 before playing.
var furthest_level = 0

var _config = ConfigFile.new()
var _best_before_run = 0 # Best score when the current run started
# Respawn point of the current level: "hud" (HUD state), "collected" (pickup
# keys) and "position" (Vector2, or null for the level start). Empty when the
# level was not entered through a transition.
var _respawn: Dictionary = {}
var _checkpoint_key = "" # Key of the active checkpoint, "" for the level start
var _collected: Dictionary = {} # Keys of the pickups collected in this level
var _tracked_scene_id = 0 # Instance id of the last scene seen
var _pending_level_start = false # Save the level start once the new scene is ready
var _pending_respawn = false # Restore the respawn point once the reloaded scene is ready


func _ready():
	# Respawns must be applied even if the tree is paused meanwhile.
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_progress()


func _process(_delta):
	var scene = get_tree().current_scene
	if scene == null or scene.get_instance_id() == _tracked_scene_id:
		return
	_tracked_scene_id = scene.get_instance_id()
	# Every node of the new scene is ready by now (the player has its bombs).
	if _pending_respawn:
		_pending_respawn = false
		_apply_respawn(scene)
	elif _pending_level_start:
		_pending_level_start = false
		_respawn = {"hud": HealthDashboard.get_state(), "collected": {}, "position": null}


## Reads the saved progress (a missing file means nothing saved yet).
func load_progress():
	_config = ConfigFile.new()
	_config.load(path)
	best_score = max(0, int(_config.get_value(SECTION, KEY_BEST_SCORE, 0)))
	furthest_level = clamp(int(_config.get_value(SECTION, KEY_FURTHEST_LEVEL, 0)), 0, LEVELS.size())
	_best_before_run = best_score
	best_score_changed.emit(best_score)


func save_progress():
	_config.set_value(SECTION, KEY_BEST_SCORE, best_score)
	_config.set_value(SECTION, KEY_FURTHEST_LEVEL, furthest_level)
	var error = _config.save(path)
	if error != OK:
		push_warning("Could not save progress to %s (error %d)." % [path, error])


## Starts a new run: empty HUD, no respawn point.
func start_run():
	HealthDashboard.restart()
	_best_before_run = best_score
	_clear_level()


## Score of the current run.
func current_score() -> int:
	return HealthDashboard.score


## Ends the run with `score`: saves it if it beats the best score and returns
## true when it is a new record for this run (even if the best score was
## already raised while changing level).
func submit_run(score: int) -> bool:
	_raise_best_score(score)
	return score > _best_before_run


## Called by SceneTransition right before changing to `target`: clears the
## checkpoint, records the furthest level and keeps the best score up to date.
func enter_level(target: String):
	_clear_level()
	_pending_level_start = true
	var level = LEVELS.find(target) + 1
	if level > furthest_level:
		furthest_level = level
		save_progress()
	_raise_best_score(current_score())


## Called by SceneTransition before reloading the level after a death.
## Returns false when there is no respawn point to restore (the level was
## opened directly), in which case the run starts over.
func prepare_respawn() -> bool:
	if _respawn.is_empty():
		HealthDashboard.restart()
		_collected = {}
		_pending_level_start = true
		return false
	_collected = _respawn.collected.duplicate()
	_pending_respawn = true
	return true


## Makes `checkpoint` the respawn point of this level, placing the player at
## `respawn_position`. Returns false when it already was.
func activate_checkpoint(checkpoint: Node, respawn_position: Vector2) -> bool:
	var key = _node_key(checkpoint)
	if key == _checkpoint_key:
		return false
	_checkpoint_key = key
	_respawn = {
		"hud": HealthDashboard.get_state(),
		"collected": _collected.duplicate(),
		"position": respawn_position,
	}
	return true


## True when `checkpoint` is the active respawn point of this level.
func is_active_checkpoint(checkpoint: Node) -> bool:
	return _checkpoint_key != "" and _node_key(checkpoint) == _checkpoint_key


## True when the pickup `node` was collected before the current respawn point.
func is_collected(node: Node) -> bool:
	return _collected.has(_node_key(node))


func mark_collected(node: Node):
	_collected[_node_key(node)] = true


func _clear_level():
	_respawn = {}
	_checkpoint_key = ""
	_collected = {}
	_pending_level_start = false
	_pending_respawn = false


func _raise_best_score(score: int):
	if score <= best_score:
		return
	best_score = score
	save_progress()
	best_score_changed.emit(best_score)


func _apply_respawn(scene: Node):
	HealthDashboard.set_state(_respawn.hud)
	var position = _respawn.position
	if position == null:
		return
	var player = _find_player(scene)
	if player == null:
		return
	var movement = player.get_node_or_null("MainCharacterMovement")
	if movement and movement.has_method("respawn_at"):
		movement.respawn_at(position)
	else:
		player.global_position = position
	# Jump the camera there instead of panning across the level.
	for camera in scene.find_children("*", "Camera2D", true, false):
		if camera.get("character") == player:
			camera.global_position = player.global_position
			camera.reset_smoothing()


func _find_player(scene: Node) -> Node2D:
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D and scene.is_ancestor_of(node):
			return node
	return null


# Identifies a node of a level by its path inside the level scene, so it
# matches the same node after the level is reloaded.
func _node_key(node: Node) -> String:
	var root = node.owner
	if root == null:
		return str(node.name)
	return str(root.get_path_to(node))
