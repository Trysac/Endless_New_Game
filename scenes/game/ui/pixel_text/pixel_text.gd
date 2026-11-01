@tool
class_name PixelText
extends Control
## Text drawn with the letter sprites of the Treasure Hunters UI atlas.
##
## [member text] is translated (it is usually a translation key), so the
## title follows the current language. "\n" starts a new line. Characters the
## atlas does not have (spaces, punctuation) leave an empty cell; accented
## letters are drawn without the accent.


const ATLAS = preload("res://assets/atlases/text.png")
# Atlas layout: 6 columns of 10x11 px glyphs on a 20 px grid, 4 px margin.
const GLYPHS = ["STUVWX", "YZ1234", "567890", "ABCDEF", "GHIJKL", "MNOPQR"]
const GLYPH_SIZE = Vector2(10, 11)
const GRID_STEP = 20.0
const GRID_MARGIN = 4.0
const ACCENTS = {"Á": "A", "É": "E", "Í": "I", "Ó": "O", "Ú": "U", "Ü": "U", "Ñ": "N"}

## Text or translation key to draw.
@export var text: String = "":
	set(value):
		text = value
		_refresh()
## Size each letter is drawn at.
@export var letter_size := Vector2(28, 41):
	set(value):
		letter_size = value
		_refresh()
## Horizontal distance between the starts of two letters.
@export var letter_advance := 30.0:
	set(value):
		letter_advance = value
		_refresh()

var _regions = {} # Character -> atlas region


func _init():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for row in GLYPHS.size():
		for column in GLYPHS[row].length():
			_regions[GLYPHS[row][column]] = Rect2(
				Vector2(GRID_MARGIN + column * GRID_STEP, GRID_MARGIN + row * GRID_STEP),
				GLYPH_SIZE)


func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh()


func _draw():
	var lines = _get_lines()
	for row in lines.size():
		var line: String = lines[row]
		for column in line.length():
			var glyph = line[column]
			glyph = ACCENTS.get(glyph, glyph)
			if not _regions.has(glyph):
				continue
			var cell_position = Vector2(column * letter_advance, row * letter_size.y)
			draw_texture_rect_region(ATLAS, Rect2(cell_position, letter_size), _regions[glyph])


func _get_minimum_size() -> Vector2:
	var lines = _get_lines()
	var longest = 0
	for line in lines:
		longest = max(longest, line.length())
	if longest == 0:
		return Vector2.ZERO
	return Vector2((longest - 1) * letter_advance + letter_size.x, lines.size() * letter_size.y)


## The translated text, upper-cased.
func get_display_text() -> String:
	return atr(text).to_upper()


func _get_lines() -> PackedStringArray:
	return get_display_text().split("\n")


func _refresh():
	update_minimum_size()
	queue_redraw()
