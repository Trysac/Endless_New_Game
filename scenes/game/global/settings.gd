extends Node
## Player settings.
##
## Loads and saves the player's preferences in a ConfigFile and applies them:
## the interface language and the remapped controls.


signal locale_changed(locale: String)
signal bindings_changed

## Actions the player can remap, in the order the controls screen lists them.
const REMAPPABLE_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"jump", &"attack",
	&"throw_bomb", &"interact", &"inventory_toggle", &"pause",
]

## Locales the game is translated to; the first one is the default.
const LOCALES: Array[String] = ["en", "es"]
const SECTION_GENERAL = "general"
const KEY_LOCALE = "locale"
const SECTION_INPUT = "input"
# Stored binding fields; -1 means "keep the project default".
const FIELD_KEY = "key"
const FIELD_JOY = "joy"

## File the settings are stored in.
var path = "user://settings.cfg"

var _config = ConfigFile.new()


func _ready():
	load_settings()


## Reads the settings file (missing values fall back to defaults) and applies it.
func load_settings():
	_config = ConfigFile.new()
	# A missing or unreadable file just means defaults.
	_config.load(path)
	TranslationServer.set_locale(get_locale())
	_apply_saved_bindings()


## Saves the current settings to disk.
func save_settings():
	var error = _config.save(path)
	if error != OK:
		push_warning("Could not save settings to %s (error %d)." % [path, error])


## Returns the saved interface locale, or the default one for this system.
func get_locale() -> String:
	var locale = _config.get_value(SECTION_GENERAL, KEY_LOCALE, default_locale())
	if not LOCALES.has(locale):
		return default_locale()
	return locale


## Switches the interface language and remembers the choice.
func set_locale(locale: String):
	if not LOCALES.has(locale):
		push_warning("Unsupported locale: %s" % locale)
		return
	TranslationServer.set_locale(locale)
	_config.set_value(SECTION_GENERAL, KEY_LOCALE, locale)
	save_settings()
	locale_changed.emit(locale)


## Spanish when the system language is Spanish, English otherwise.
static func default_locale() -> String:
	if OS.get_locale_language() == "es":
		return "es"
	return LOCALES[0]


## Returns the primary binding of an action: its first key when `joypad` is
## false, its first gamepad button when true, or null when it has none.
func get_binding(action: StringName, joypad: bool) -> InputEvent:
	for event in InputMap.action_get_events(action):
		if _is_binding_kind(event, joypad):
			return event
	return null


## Makes `event` (a key or a gamepad button) the primary binding of `action`.
## A remappable action whose primary binding it was takes the old binding
## instead, so no action is left without a control; one that only had it as
## a secondary binding loses it, so one press never triggers two actions.
func set_binding(action: StringName, event: InputEvent):
	var joypad = event is InputEventJoypadButton
	var previous = get_binding(action, joypad)
	for other in REMAPPABLE_ACTIONS:
		if other == action:
			continue
		if _has_binding(other, event, joypad):
			_replace_binding(other, get_binding(other, joypad), previous, joypad)
		else:
			_erase_matching(other, event)
	_replace_binding(action, previous, event, joypad)
	_save_bindings()
	bindings_changed.emit()


## Restores every control to the project defaults and forgets the saved ones.
func reset_bindings():
	InputMap.load_from_project_settings()
	if _config.has_section(SECTION_INPUT):
		_config.erase_section(SECTION_INPUT)
	save_settings()
	bindings_changed.emit()


## Short human-readable name of a binding, e.g. "Space" or "Gamepad A".
static func binding_name(event: InputEvent) -> String:
	if event is InputEventKey:
		# Built-in ui_* actions store a layout keycode instead of a physical one.
		if event.physical_keycode == KEY_NONE:
			return OS.get_keycode_string(event.keycode)
		var keycode = event.physical_keycode
		# Name the key as printed on the player's layout where the platform can tell.
		if DisplayServer.get_name() in ["Windows", "macOS", "X11", "Wayland"]:
			keycode = DisplayServer.keyboard_get_keycode_from_physical(keycode)
		return OS.get_keycode_string(keycode)
	if event is InputEventJoypadButton:
		return "Pad " + _joy_button_name(event.button_index)
	return "-"


static func _joy_button_name(button: int) -> String:
	const NAMES = ["A", "B", "X", "Y", "Back", "Guide", "Start", "LS", "RS",
		"LB", "RB", "Up", "Down", "Left", "Right"]
	if button >= 0 and button < NAMES.size():
		return NAMES[button]
	return str(button)


static func _is_binding_kind(event: InputEvent, joypad: bool) -> bool:
	if joypad:
		return event is InputEventJoypadButton
	return event is InputEventKey


func _has_binding(action: StringName, event: InputEvent, joypad: bool) -> bool:
	var current = get_binding(action, joypad)
	return current != null and _same_binding(current, event)


static func _same_binding(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	return false


# Removes every binding of `action` that matches `event`.
func _erase_matching(action: StringName, event: InputEvent):
	for current in InputMap.action_get_events(action):
		if _same_binding(current, event):
			InputMap.action_erase_event(action, current)


# Swaps `old_event` for `new_event` keeping the primary binding first.
func _replace_binding(action: StringName, old_event: InputEvent, new_event: InputEvent, joypad: bool):
	var events = InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	var placed = false
	for event in events:
		if old_event != null and event == old_event:
			if new_event != null:
				InputMap.action_add_event(action, new_event)
			placed = true
		elif new_event != null and _is_binding_kind(event, joypad) and _same_binding(event, new_event):
			continue # Drop a secondary binding that duplicates the new one
		else:
			InputMap.action_add_event(action, event)
	if not placed and new_event != null:
		InputMap.action_add_event(action, new_event)


func _save_bindings():
	for action in REMAPPABLE_ACTIONS:
		var key = get_binding(action, false)
		var joy = get_binding(action, true)
		_config.set_value(SECTION_INPUT, action, {
			FIELD_KEY: key.physical_keycode if key else -1,
			FIELD_JOY: joy.button_index if joy else -1,
		})
	save_settings()


func _apply_saved_bindings():
	for action in REMAPPABLE_ACTIONS:
		var saved = _config.get_value(SECTION_INPUT, action, {})
		if not (saved is Dictionary) or not InputMap.has_action(action):
			continue
		var key_code = int(saved.get(FIELD_KEY, -1))
		if key_code > 0:
			var key = InputEventKey.new()
			key.physical_keycode = key_code
			_replace_binding(action, get_binding(action, false), key, false)
		var button = int(saved.get(FIELD_JOY, -1))
		if button >= 0:
			var joy = InputEventJoypadButton.new()
			joy.button_index = button
			_replace_binding(action, get_binding(action, true), joy, true)
	_drop_shadowed_bindings()


# Defaults may list a remapped control as another action's secondary binding:
# drop those so the remapped primary is the only action it triggers.
func _drop_shadowed_bindings():
	for action in REMAPPABLE_ACTIONS:
		for joypad in [false, true]:
			var primary = get_binding(action, joypad)
			if primary == null:
				continue
			for other in REMAPPABLE_ACTIONS:
				if other == action:
					continue
				for current in InputMap.action_get_events(other):
					if current != get_binding(other, joypad) and _same_binding(current, primary):
						InputMap.action_erase_event(other, current)
