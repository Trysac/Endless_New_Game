extends CanvasLayer
## Health and score HUD.
##
## Holds the player's health, points, bombs and run score, and draws them
## using digit sprites from a font atlas.
##
## Every pickup also adds to the run score (see [constant PICKUP_SCORES]).
## Collecting the three diamond colours in one run restores full health once.


## Run score of each pickup type.
const PICKUP_SCORES = {
	"SilverCoin": 1,
	"GoldCoin": 5,
	"BlueDiamond": 25,
	"GreenDiamond": 25,
	"RedDiamond": 25,
}
## Diamond types that together grant the full-health bonus.
const DIAMOND_SET = ["BlueDiamond", "GreenDiamond", "RedDiamond"]
const MAX_LIFE = 10
# Digits shown by the run score counter
const SCORE_DIGITS = 5

var life = MAX_LIFE
## Run score: the value of every pickup collected in this run.
var score = 0
# Points per collectible type, plus the bomb count
var points = {
	"GoldCoin": 0,
	"SilverCoin": 0,
	"BlueDiamond": 0,
	"GreenDiamond": 0,
	"RedDiamond": 0,
	"Bomb": 0,
}

# Diamond types collected in this run, and whether the bonus was used
var _diamonds_found: Array[String] = []
var _diamond_bonus_used = false

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
@onready var _score_value = $Score/Value


func _ready():
	self.visible = false
	_draw_score()


# Adds health, capped at MAX_LIFE.
func add_life(value: int):
	life += value
	if life > MAX_LIFE:
		life = MAX_LIFE
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


## Collects one pickup of `type`: one point of its type plus its run score.
## Returns true when it completes the diamond set for the first time in this
## run, which restores full health.
func collect(type: String) -> bool:
	add_points(type, 1)
	score += PICKUP_SCORES.get(type, 0)
	_draw_score()
	if not DIAMOND_SET.has(type) or _diamond_bonus_used:
		return false
	if not _diamonds_found.has(type):
		_diamonds_found.append(type)
	if _diamonds_found.size() < DIAMOND_SET.size():
		return false
	_diamond_bonus_used = true
	add_life(MAX_LIFE)
	return true


## True when the diamond set bonus was already used in this run.
func is_diamond_bonus_used() -> bool:
	return _diamond_bonus_used


# Adds (or, with a negative value, removes) bombs.
func add_bomb(value: int):
	add_points("Bomb", value, bomb_group)


# Resets health, every counter and the run score.
func restart():
	var empty = {}
	for type in points:
		empty[type] = 0
	set_state({"points": empty, "score": 0, "diamonds": [], "diamond_bonus_used": false})


## Counters and run progress, to restore them later with [method set_state].
func get_state() -> Dictionary:
	return {
		"points": points.duplicate(),
		"score": score,
		"diamonds": _diamonds_found.duplicate(),
		"diamond_bonus_used": _diamond_bonus_used,
	}


## Restores a state saved with [method get_state], with full health.
func set_state(state: Dictionary):
	life = MAX_LIFE
	_set_life_progress(life)
	for type in points:
		points[type] = int(state.points.get(type, 0))
		var group = point_group.find_child(type)
		if not group:
			group = bomb_group
		_number_1 = group.find_child("Number1")
		_number_2 = group.find_child("Number2")
		_number_3 = group.find_child("Number3")
		_set_points(points[type])
	score = int(state.score)
	_diamonds_found.assign(state.diamonds)
	_diamond_bonus_used = bool(state.diamond_bonus_used)
	_draw_score()


func _draw_score():
	var shown = min(score, int(pow(10, SCORE_DIGITS)) - 1)
	_score_value.text = str(shown).pad_zeros(SCORE_DIGITS)


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
