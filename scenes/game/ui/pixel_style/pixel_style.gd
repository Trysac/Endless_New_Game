class_name PixelStyle
extends RefCounted
## Shared look for code-styled buttons: dark wood fill with a gold border,
## matching the Treasure Hunters UI sprites.


const FONT = preload("res://assets/fonts/press_Sstart_2p/PressStart2P-Regular.ttf")
const COLOR_TEXT = Color(0.96, 0.9, 0.78)
const COLOR_FILL = Color(0.29, 0.18, 0.12, 0.9)
const COLOR_FILL_ACTIVE = Color(0.55, 0.33, 0.16, 1)
const COLOR_BORDER = Color(0.95, 0.72, 0.35)


## Applies the pixel font and the wood styles to a Button (or OptionButton).
static func apply_button(button: Button, font_size := 16):
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", box(COLOR_FILL, 1))
	button.add_theme_stylebox_override("hover", box(COLOR_FILL_ACTIVE, 1))
	button.add_theme_stylebox_override("pressed", box(COLOR_FILL_ACTIVE, 2))
	button.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), 2))


## Flat box with a gold border of `border` pixels.
static func box(color: Color, border: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = COLOR_BORDER
	style.set_border_width_all(border)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	return style
