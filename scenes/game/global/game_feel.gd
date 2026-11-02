extends Node
## Game feel effects shared by every scene.
##
## Screen shake on the active camera, hit-stop (a few frames of near-frozen
## time), one-shot particle bursts and floating text popups.


const FONT = preload("res://assets/fonts/press_Sstart_2p/PressStart2P-Regular.ttf")
# Time scale while a hit-stop is running
const HITSTOP_TIME_SCALE = 0.05

var _shake_strength = 0.0
var _shake_time_left = 0.0
var _shake_duration = 0.0
var _applied_offset = Vector2.ZERO # Shake offset currently added to the camera
var _shaken_camera: Camera2D
var _hitstop_end_msec = 0
var _hitstop_id = 0 # Increases with every hit-stop that takes over


func _ready():
	# Shake and hit-stop must finish even while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta):
	_clear_shake_offset()
	if _shake_time_left <= 0.0:
		return
	_shake_time_left -= delta
	var camera = get_viewport().get_camera_2d()
	if camera == null:
		return
	# Fade the shake out over its duration.
	var strength = _shake_strength * clamp(_shake_time_left / _shake_duration, 0.0, 1.0)
	_applied_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength
	_shaken_camera = camera
	camera.offset += _applied_offset


## Shakes the active camera by up to `strength` pixels for `duration` seconds.
## A weaker shake never cuts a stronger one short.
func shake(strength: float, duration: float):
	if strength < _shake_strength * clamp(_shake_time_left / max(_shake_duration, 0.001), 0.0, 1.0):
		return
	_shake_strength = strength
	_shake_duration = duration
	_shake_time_left = duration


## Nearly freezes time for `duration` real seconds to sell an impact.
## A shorter hit-stop never cuts a running longer one short.
func hitstop(duration: float):
	var end = Time.get_ticks_msec() + int(duration * 1000)
	if end <= _hitstop_end_msec:
		return
	_hitstop_end_msec = end
	_hitstop_id += 1
	var id = _hitstop_id
	Engine.time_scale = HITSTOP_TIME_SCALE
	await get_tree().create_timer(duration, true, false, true).timeout
	# Only the latest hit-stop restores the time scale.
	if id == _hitstop_id:
		Engine.time_scale = 1.0
		_hitstop_end_msec = 0


## One-shot burst of square particles at a world position.
func burst(position: Vector2, color: Color, amount := 12, speed := 80.0, spread := 180.0):
	var parent = get_tree().current_scene
	if parent == null:
		return
	var particles = CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.45
	particles.direction = Vector2.UP
	particles.spread = spread
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector2(0, 260)
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.5
	particles.color = color
	var fade = Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	particles.color_ramp = fade
	particles.z_index = 10
	parent.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


## Text that floats up from a world position and fades out.
func popup_text(position: Vector2, text: String, color := Color.WHITE):
	var parent = get_tree().current_scene
	if parent == null:
		return
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.06))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 20
	parent.add_child(label)
	label.reset_size()
	label.global_position = position - Vector2(label.size.x / 2, label.size.y)
	# Keep it inside the visible part of the level.
	var view = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	label.global_position.x = clamp(label.global_position.x, view.position.x + 2, view.end.x - label.size.x - 2)
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 18, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)


func _clear_shake_offset():
	if _applied_offset != Vector2.ZERO and is_instance_valid(_shaken_camera):
		_shaken_camera.offset -= _applied_offset
	_applied_offset = Vector2.ZERO
	_shaken_camera = null
