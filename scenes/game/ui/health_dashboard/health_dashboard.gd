extends CanvasLayer
## Health and score HUD.
##
## Holds the player's health, points and bombs, and draws them using
## digit sprites from a font atlas.


var life = 10
# Points per collectible type, plus the bomb count
var points = {
	"GoldCoin": 0,
	"SilverCoin": 0,
	"BlueDiamond": 0,
	"GreenDiamond": 0,
	"RedDiamond": 0,
	"Bomb": 0,
}

# Digit sprites of the counter being updated
var _number_1: TextureRect
var _number_2: TextureRect
var _number_3: TextureRect

# Atlas index of the digit 1 (digits 1-9 are consecutive)
var _index_number_1 = 8
# Atlas index of the digit 0
var _index_number_0 = 17

@onready var bar = $LifeBar/Bar
@onready var point_group = $PointGroup
@onready var bomb_group = $LifeBar/Bomb


func _ready():
	self.visible = false


# Adds health, capped at 10.
func add_life(value: int):
	life += value
	if life > 10:
		life = 10
	_set_life_progress(life)


# Removes health, down to 0.
func remove_life(value: int):
	life -= value
	if life < 0:
		life = 0
	_set_life_progress(life)


# Adds `value` points of `type` (may be negative) and redraws its counter.
func add_points(type: String, value: int, group = null):
	if not group:
		group = point_group.find_child(type)
	if group:
		_number_1 = group.find_child("Number1")
		_number_2 = group.find_child("Number2")
		_number_3 = group.find_child("Number3")
		points[type] += value
		_set_points(points[type])


# Adds (or, with a negative value, removes) bombs.
func add_bomb(value: int):
	add_points("Bomb", value, bomb_group)


# Resets health and every counter.
func restart():
	life = 10
	_set_life_progress(life)
	for type in points:
		var group = point_group.find_child(type)
		if not group:
			group = bomb_group
			
		_number_1 = group.find_child("Number1")
		_number_2 = group.find_child("Number2")
		_number_3 = group.find_child("Number3")
		points[type] = 0
		_set_points(points[type])


func _set_life_progress(value: int):
	bar.value = value


# Draws a three-digit value (capped at 999) with the digit sprites.
func _set_points(value: int):
	if value > 999:
		value = 999
	var digit_str = str(value)
	var digit_list = digit_str.split("")
	
	# Pad with leading zeros
	if value < 100:
		for i in range(3 - digit_list.size()):
			digit_list.insert(0, "0")
	
	for index in range(digit_list.size()):
		var n = digit_list[index]
		var region = Rect2()
		if n == "0":
			region = _get_text_region(_index_number_0)
		else:
			var v = int(n)
			var position = v + _index_number_1 - 1
			region = _get_text_region(position)
		match index:
			0:
				_number_1.texture.set_region(region)
			1:
				_number_2.texture.set_region(region)
			2:
				_number_3.texture.set_region(region)


# Returns the atlas region of the character at index `position`
# (6 columns, 10x11 glyphs on a 20 px grid starting at 4,4).
func _get_text_region(position: int):
	var w = 10
	var h = 11
	var x = 4.0
	var y = 4.0
	var delta = 20.0 # Grid step between glyphs
	var column_count = 6.0
	
	for p in range(position):
		if x / delta < column_count - 1.0:
			x += delta
		else:
			# Wrap to the start of the next row
			x = 4
			y += delta
			
	return Rect2(x, y, w, h)
