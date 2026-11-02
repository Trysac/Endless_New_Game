extends RigidBody2D
## Thrown bomb.
##
## Explodes three seconds after being thrown, unless something puts it out
## first (see `defuse`).

const FUSE_TIME = 3.0
const SMOKE_COLOR = Color(0.75, 0.75, 0.78)

var _bomb_effect = preload("res://scenes/game/levels/objects/damage_object/bomb/bomb_explosion.tscn")
var _lit := true
var _fuse: Timer

@onready var _animation = $BombAnimation


func _ready():
	add_to_group("bomb")
	# The fuse is a child timer so it stops if the bomb is freed or put out.
	_fuse = Timer.new()
	_fuse.one_shot = true
	_fuse.wait_time = FUSE_TIME
	_fuse.timeout.connect(_explode)
	add_child(_fuse)
	_fuse.start()


## True while the fuse is burning.
func is_lit() -> bool:
	return _lit


## Puts the fuse out: the bomb will not explode and fades away.
func defuse():
	if not _lit:
		return
	_lit = false
	_fuse.stop()
	_animation.play("off")
	GameFeel.burst(global_position + Vector2(0, -6), SMOKE_COLOR, 6, 40.0)
	GameFeel.popup_text(global_position + Vector2(0, -12), tr("BOMB_DEFUSED"), SMOKE_COLOR)
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func _explode():
	if not _lit:
		return
	_lit = false
	# Spawn the explosion slightly above the bomb, then remove the bomb.
	var bomb_scene = _bomb_effect.instantiate()
	bomb_scene.position = position
	bomb_scene.position.y = position.y - 20
	get_parent().add_child(bomb_scene)
	queue_free()
