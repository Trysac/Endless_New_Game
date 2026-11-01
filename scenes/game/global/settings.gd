extends Node
## Player settings.
##
## Loads and saves the player's preferences in a ConfigFile and applies them.
## For now it only holds the interface language.


signal locale_changed(locale: String)

## Locales the game is translated to; the first one is the default.
const LOCALES: Array[String] = ["en", "es"]
const SECTION_GENERAL = "general"
const KEY_LOCALE = "locale"

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
