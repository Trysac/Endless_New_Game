extends Node2D
## Inventory.
##
## Draws the inventory slots and adds, stacks and removes power-up items.
## Opens with the inventory action (I / Tab / gamepad Back) or the mouse
## wheel. The arrow keys or the d-pad pick a slot and accept uses its item.


# Number of slots; each holds one item type
const SLOT_COUNT = 6
# Slots per grid row (matches the GridContainer columns)
const COLUMNS = 3
const CURSOR_COLOR = Color(1, 0.84, 0.4)

# Slot frames, in grid order
var _item_contents = []
# Names of the items in the inventory, in slot order
var _item_object_names = []
# Item nodes, in slot order
var _item_objects = []
# Frame drawn around the selected slot, one per slot
var _cursors = []
var _selected = 0 # Index of the selected slot


@onready var canvas = $CanvasLayer
@onready var animation_player = $CanvasLayer/AnimationPlayer
@onready var grid = $CanvasLayer/Inventory/GridContainer
@onready var _hint = $CanvasLayer/Inventory/Hint


func _ready():
	# Build the six slot frames that items are placed into.
	for n in SLOT_COUNT:
		var item = load("res://scenes/game/inventory/item_content/item_content.tscn").instantiate()
		grid.add_child(item)
		_item_contents.append(item)
		var cursor = ReferenceRect.new()
		cursor.editor_only = false
		cursor.border_color = CURSOR_COLOR
		cursor.border_width = 0.5
		cursor.set_anchors_preset(Control.PRESET_FULL_RECT)
		cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cursor.visible = false
		item.add_child(cursor)
		_cursors.append(cursor)


func _unhandled_input(event):
	# The inventory is not available on these screens.
	var scenes = ["Splash", "Init"]
	var current_scene = get_tree().get_current_scene().name
	if scenes.find(current_scene,0) > -1:
		return
	
	if event.is_action_pressed("inventory_toggle"):
		if canvas.visible:
			_close()
		else:
			_open()
	elif event.is_action_pressed("inventory_close"):
		_close()
	elif event.is_action_pressed("inventory_open"):
		_open()
	elif canvas.visible:
		_navigate(event)


func _open():
	if canvas.visible:
		return
	get_tree().paused = true
	canvas.visible = true
	_select(min(_selected, max(_item_objects.size() - 1, 0)))
	_hint.text = "%s %s   %s %s" % [
		_binding_names("ui_accept"), tr("INVENTORY_HINT_USE"),
		_binding_names("inventory_toggle"), tr("INVENTORY_HINT_CLOSE"),
	]
	animation_player.play("down")
	await animation_player.animation_finished


func _close():
	# Closing an inventory that is not open must not unpause the game.
	if not canvas.visible:
		return
	animation_player.play_backwards("down")
	await animation_player.animation_finished
	canvas.visible = false
	get_tree().paused = false


# Arrow keys / d-pad move the cursor; accept uses the selected item.
func _navigate(event):
	var target = _selected
	if event.is_action_pressed("ui_left"):
		target -= 1
	elif event.is_action_pressed("ui_right"):
		target += 1
	elif event.is_action_pressed("ui_up"):
		target -= COLUMNS
	elif event.is_action_pressed("ui_down"):
		target += COLUMNS
	elif event.is_action_pressed("ui_accept"):
		if _selected < _item_objects.size():
			_item_objects[_selected].request_use()
		get_viewport().set_input_as_handled()
		return
	else:
		return
	get_viewport().set_input_as_handled()
	if target >= 0 and target < SLOT_COUNT:
		_select(target)


func _select(index: int):
	_selected = index
	for n in _cursors.size():
		_cursors[n].visible = n == index


# "Space / Pad A" style list of an action's key and gamepad bindings.
func _binding_names(action: StringName) -> String:
	var names = []
	for joypad in [false, true]:
		var event = Settings.get_binding(action, joypad)
		if event:
			names.append(Settings.binding_name(event))
	return " / ".join(names)


# Adds one item by animation name (e.g. blue_potion or green_bottle).
# An item already in the inventory just increases its count.
# Returns false when the item could not be added (every slot is taken).
func add_item_by_name(_name: String) -> bool:
	var index = _item_object_names.find(_name)
	if index >= 0:
		var _num_available = _item_objects[index].get_num()
		_num_available += 1
		_item_objects[index].set_num(str(_num_available))
		return true

	# A new item type needs a free slot.
	if _item_object_names.size() >= _item_contents.size():
		return false

	var item_to_load = load("res://scenes/game/levels/objects/power_up/power_up_item.tscn")

	if not item_to_load:
		return false
	
	# Place it in the next free slot.
	index = _item_object_names.size()
	var item = item_to_load.instantiate()
	var item_content = _item_contents[index]
	item_content.add_child(item)
	item.set_animation(_name)
	_item_object_names.append(_name);
	_item_objects.append(item)
	return true


# Removes one item by animation name (e.g. blue_potion or green_bottle).
# When its count reaches zero the item is freed and later items shift back
# one slot so no gaps are left.
func remove_item_by_name(_name: String):
	var index = _item_object_names.find(_name)
	if index >= 0:
		var item_content = _item_contents[index]
		var item = _item_objects[index]
		var _num_available = _item_objects[index].get_num()
		_num_available -= 1 
		if _num_available > 0:
			_item_objects[index].set_num(str(_num_available))
			return
		else:
			item_content.remove_child(item)
			item.queue_free();
			
			var size = _item_objects.size()
			for n in range(index, size - 1):
				var current_content = _item_contents[n]
				var next_content = _item_contents[n + 1]
				var next_item = _item_objects[n + 1];
				# Move the next item into this slot (reparent, do not free).
				next_content.remove_child(next_item);
				current_content.add_child(next_item);
			
			_item_object_names.remove_at(index)
			
			_item_objects.remove_at(index)


func show_inventory(show: bool):
	canvas.visible = show
	get_tree().paused = show
