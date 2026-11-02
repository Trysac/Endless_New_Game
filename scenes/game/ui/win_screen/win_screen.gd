extends Control
## Victory screen, shown after defeating the Captain.
##
## Ends the run: submits the run score (see [method Progress.submit_run]) and
## shows it with the best score, a "New record!" banner when the run beat the
## best score it started with, and the diamonds collected. "Play again"
## starts a fresh run from the first level through the main menu's start
## path; "Main menu" goes back to the title screen with the menu open.


const PATH_TITLE_ROOM = "res://scenes/game/levels/rooms/init/init.tscn"
const DIAMOND_TYPES = ["BlueDiamond", "GreenDiamond", "RedDiamond"]
const FOCUSED_MODULATE = Color(1.15, 1.15, 1.15)

## Score of the finished run.
var score := 0
## Diamonds collected during the run.
var diamonds := 0
## True when the run set a new best score.
var new_record := false

var _leaving := false
var _restarting := false

@onready var _panel: Control = $Panel
@onready var _score: Label = $Panel/Content/Score/Value
@onready var _best: Label = $Panel/Content/Best
@onready var _diamonds: Label = $Panel/Content/Diamonds/Value
@onready var _new_record: Label = $Panel/Content/NewRecord
@onready var _play_again: Button = $Panel/Content/Buttons/PlayAgain/Button
@onready var _main_menu: Button = $Panel/Content/Buttons/MainMenu/Button


func _ready():
	HealthDashboard.visible = false
	_end_run_in_menu()
	score = Progress.current_score()
	diamonds = count_diamonds()
	new_record = Progress.submit_run(score)
	_refresh_texts()
	Settings.locale_changed.connect(func(_locale): _refresh_texts())
	_new_record.visible = new_record
	if new_record:
		var blink = create_tween().set_loops()
		blink.tween_property(_new_record, "modulate:a", 0.55, 0.45)
		blink.tween_property(_new_record, "modulate:a", 1.0, 0.45)
	for button in [_play_again, _main_menu]:
		var look: Control = button.get_parent()
		button.focus_entered.connect(func(): look.modulate = FOCUSED_MODULATE)
		button.focus_exited.connect(func(): look.modulate = Color.WHITE)
		button.mouse_entered.connect(button.grab_focus)
	_play_again.pressed.connect(play_again)
	_main_menu.pressed.connect(main_menu)
	# Keyboard and gamepad players can choose right away.
	_play_again.grab_focus.call_deferred()
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.85, 0.85)
	_panel.modulate.a = 0.0
	var intro = create_tween().set_parallel(true)
	intro.tween_property(_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(_panel, "modulate:a", 1.0, 0.25)


func _exit_tree():
	# The HUD comes back with the first level of the new run.
	if _restarting:
		HealthDashboard.visible = true


## Diamonds of every colour collected during the run.
static func count_diamonds() -> int:
	var total = 0
	for type in DIAMOND_TYPES:
		total += int(HealthDashboard.points.get(type, 0))
	return total


## Starts a new run from the first level, like the main menu's play button.
func play_again():
	if _leaving:
		return
	_leaving = true
	_restarting = true
	MainMenu.start_run()


## Goes back to the title screen with the main menu open.
func main_menu():
	if _leaving:
		return
	_leaving = true
	SceneTransition.change_scene(PATH_TITLE_ROOM, true)


# The run is over: the pause action no longer opens the menu over this screen
# and the menu offers a new game instead of "Continue".
func _end_run_in_menu():
	MainMenu.end_run()


func _refresh_texts():
	_score.text = tr("WIN_SCORE") % score
	_best.text = tr("MENU_BEST_SCORE") % Progress.best_score
	_diamonds.text = tr("WIN_DIAMONDS") % diamonds
