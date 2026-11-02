extends VBoxContainer
## Controls screen list.
##
## One row per remappable action with its keyboard and gamepad bindings.
## Pressing a binding waits for the next key (or gamepad button) and saves it;
## Escape cancels. A last button restores the defaults.


const FONT = preload("res://assets/fonts/press_Sstart_2p/PressStart2P-Regular.ttf")
const FONT_SIZE = 16
const ROW_HEIGHT = 34
# Translation key of each action's label
const ACTION_LABELS = {
	&"move_left": "CONTROLS_MOVE_LEFT",
	&"move_right": "CONTROLS_MOVE_RIGHT",
	&"jump": "CONTROLS_JUMP",
	&"attack": "CONTROLS_ATTACK",
	&"throw_bomb": "CONTROLS_BOMB",
	&"interact": "CONTROLS_INTERACT",
	&"inventory_toggle": "CONTROLS_INVENTORY",
	&"pause": "CONTROLS_MENU",
}
const COLOR_TEXT = Color(0.96, 0.9, 0.78)
const COLOR_BUTTON = Color(0.29, 0.18, 0.12, 0.9)
const COLOR_BUTTON_FOCUS = Color(0.55, 0.33, 0.16, 1)
const COLOR_BORDER = Color(0.95, 0.72, 0.35)

# Button being remapped and whether it takes a gamepad button
var _listening: Button = null
var _listening_joypad = false
# Bindings buttons per action: [keyboard, gamepad]
var _buttons = {}


func _ready():
	add_theme_constant_override("separation", 4)
	_add_header()
	for action in Settings.REMAPPABLE_ACTIONS:
		_add_row(action)
	_add_reset()
	Settings.bindings_changed.connect(_refresh)
	_refresh()


## Gives keyboard/gamepad focus to the first binding.
func focus_first():
	var first = _buttons.get(Settings.REMAPPABLE_ACTIONS[0])
	if first:
		first[0].grab_focus()


func _input(event):
	if _listening == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE:
			_stop_listening()
		elif not _listening_joypad:
			_finish_listening(_physical_key(event))
	elif event is InputEventJoypadButton and event.pressed:
		get_viewport().set_input_as_handled()
		if _listening_joypad:
			var button = InputEventJoypadButton.new()
			button.button_index = event.button_index
			_finish_listening(button)


func _add_header():
	var row = _new_row()
	row.add_child(_new_label("", HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(_new_label("CONTROLS_KEYBOARD", HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(_new_label("CONTROLS_GAMEPAD", HORIZONTAL_ALIGNMENT_CENTER))
	add_child(row)


func _add_row(action: StringName):
	var row = _new_row()
	row.add_child(_new_label(ACTION_LABELS[action], HORIZONTAL_ALIGNMENT_LEFT))
	var key_button = _new_button()
	var joy_button = _new_button()
	key_button.pressed.connect(_start_listening.bind(key_button, false))
	joy_button.pressed.connect(_start_listening.bind(joy_button, true))
	key_button.set_meta("action", action)
	joy_button.set_meta("action", action)
	row.add_child(key_button)
	row.add_child(joy_button)
	_buttons[action] = [key_button, joy_button]
	add_child(row)


func _add_reset():
	var reset = _new_button()
	reset.text = "CONTROLS_RESET"
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.custom_minimum_size = Vector2(320, 30)
	reset.pressed.connect(Settings.reset_bindings)
	add_child(reset)


func _new_row() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = ROW_HEIGHT
	row.add_theme_constant_override("separation", 12)
	return row


func _new_label(text: String, alignment: HorizontalAlignment) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = 1.7 if alignment == HORIZONTAL_ALIGNMENT_LEFT else 1.0
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	return label


func _new_button() -> Button:
	var button = Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(COLOR_BUTTON, 1))
	button.add_theme_stylebox_override("hover", _style(COLOR_BUTTON_FOCUS, 1))
	button.add_theme_stylebox_override("pressed", _style(COLOR_BUTTON_FOCUS, 2))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), 2))
	return button


func _style(color: Color, border: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = COLOR_BORDER
	style.set_border_width_all(border)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	return style


func _start_listening(button: Button, joypad: bool):
	_stop_listening()
	_listening = button
	_listening_joypad = joypad
	button.text = "CONTROLS_PRESS"


func _stop_listening():
	_listening = null
	_refresh()


func _finish_listening(event: InputEvent):
	var action = _listening.get_meta("action")
	_listening = null
	Settings.set_binding(action, event)
	_refresh()


func _refresh():
	if _listening != null:
		return
	for action in _buttons:
		var pair = _buttons[action]
		pair[0].text = Settings.binding_name(Settings.get_binding(action, false))
		pair[1].text = Settings.binding_name(Settings.get_binding(action, true))


# Copy of a key press keeping only its physical key, the way bindings are stored.
static func _physical_key(event: InputEventKey) -> InputEventKey:
	var key = InputEventKey.new()
	key.physical_keycode = event.physical_keycode if event.physical_keycode else event.keycode
	return key
