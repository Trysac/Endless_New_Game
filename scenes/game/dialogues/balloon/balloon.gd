extends CanvasLayer
## Dialogue balloon.
##
## Shows each dialogue line with the speaker's portrait, handles the player's
## responses and keeps the balloon sized to the window.


signal dialogue_ended()
signal response_selected(response: String)

const PATH_SPRITES = "res://scenes/game/dialogues/persons/"

# Template duplicated for each response
@export var response_template: Node

var _resource: DialogueResource
var _temporary_game_states: Array = []
var _is_waiting_for_input: bool = false
# Current line; assigning it renders the line
var dialogue_line: DialogueLine:
	set(next_dialogue_line):
		# No more lines: the dialogue is over.
		if not next_dialogue_line:
			return _end_dialogue()
		
		_is_waiting_for_input = false
		
		# Clear the previous responses
		for child in responses_menu.get_children():
			responses_menu.remove_child(child)
			child.queue_free()
		
		dialogue_line = next_dialogue_line
		character_label.visible = not dialogue_line.character.is_empty()
		character_label.text = tr(dialogue_line.character, "dialogue")
		# Replace the speaker's portrait
		for n in portrait_node.get_children():
			portrait_node.remove_child(n)
			n.queue_free()
		portrait_node.add_child(_get_texture_for_dialogue(dialogue_line.character))
		
		dialogue_label.modulate.a = 0
		dialogue_label.custom_minimum_size.x = dialogue_label.get_parent().size.x - 1
		dialogue_label.dialogue_line = dialogue_line
		
		# Build the responses, if any
		responses_menu.modulate.a = 0
		if dialogue_line.responses.size() > 0:
			for response in dialogue_line.responses:
				var item: RichTextLabel = response_template.duplicate(0)
				item.name = "Response%d" % responses_menu.get_child_count()
				if not response.is_allowed:
					item.name = String(item.name) + "Disallowed"
					item.modulate.a = 0.4
				item.text = response.text
				item.show()
				responses_menu.add_child(item)
		
		balloon.show()
		
		dialogue_label.modulate.a = 1
		dialogue_label.type_out()
		await dialogue_label.finished_typing
		
		# Wait for a response, auto-advance after a delay, or wait for input
		if dialogue_line.responses.size() > 0:
			responses_menu.modulate.a = 1
			_configure_menu()
		elif dialogue_line.time != "":
			var time = (
				dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" 
				else dialogue_line.time.to_float()
			)
			await get_tree().create_timer(time).timeout
			_next(dialogue_line.next_id)
		else:
			_is_waiting_for_input = true
			balloon.focus_mode = Control.FOCUS_ALL
			balloon.grab_focus()
	get:
		return dialogue_line

@onready var balloon: ColorRect = $Balloon
@onready var margin: MarginContainer = $Balloon/Margin
@onready var portrait_node: Control = $Balloon/Margin/HBox/Portrait
@onready var character_portrait: Sprite2D = $Balloon/Margin/HBox/Portrait/Sprite2D
@onready var character_label: RichTextLabel = $Balloon/Margin/HBox/VBox/CharacterLabel
@onready var dialogue_label := $Balloon/Margin/HBox/VBox/DialogueLabel
@onready var responses_menu: VBoxContainer = $Balloon/Margin/HBox/VBox/Responses


func _ready() -> void:
	response_template.hide()
	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)


func _unhandled_input(_event: InputEvent) -> void:
	# The balloon swallows gameplay input while it is open.
	get_viewport().set_input_as_handled()


# Starts the dialogue at the given title.
func start(dialogue_resource: DialogueResource, 
		title: String, extra_game_states: Array = []) -> void:
	_temporary_game_states = extra_game_states
	_is_waiting_for_input = false
	_resource = dialogue_resource
	self.dialogue_line = await _resource.get_next_dialogue_line(title, _temporary_game_states)


# Go to the next line
func _next(next_id: String) -> void:
	self.dialogue_line = await _resource.get_next_dialogue_line(next_id, _temporary_game_states)


# Sets up focus navigation and input for the response items.
func _configure_menu() -> void:
	balloon.focus_mode = Control.FOCUS_NONE
	
	var items = _get_responses()
	for i in items.size():
		var item: Control = items[i]
		
		item.focus_mode = Control.FOCUS_ALL
		
		item.focus_neighbor_left = item.get_path()
		item.focus_neighbor_right = item.get_path()
		
		if i == 0:
			item.focus_neighbor_top = item.get_path()
			item.focus_previous = item.get_path()
		else:
			item.focus_neighbor_top = items[i - 1].get_path()
			item.focus_previous = items[i - 1].get_path()
		
		if i == items.size() - 1:
			item.focus_neighbor_bottom = item.get_path()
			item.focus_next = item.get_path()
		else:
			item.focus_neighbor_bottom = items[i + 1].get_path()
			item.focus_next = items[i + 1].get_path()
		
		item.mouse_entered.connect(_on_response_mouse_entered.bind(item))
		item.gui_input.connect(_on_response_gui_input.bind(item))
	
	items[0].grab_focus()


# Returns the allowed responses.
func _get_responses() -> Array:
	var items: Array = []
	for child in responses_menu.get_children():
		if "Disallowed" in child.name: continue
		items.append(child)
		
	return items


# Keeps the balloon at the bottom centre, sized to its content.
func _handle_resize() -> void:
	if not is_instance_valid(margin):
		call_deferred("_handle_resize")
		return
	
	balloon.custom_minimum_size.y = margin.size.y
	balloon.size.y = 0
	var viewport_size = balloon.get_viewport_rect().size
	balloon.global_position = Vector2(
		(viewport_size.x - balloon.size.x) * 0.5, 
		viewport_size.y - balloon.size.y)


# Hide the balloon while a mutation runs.
func _on_mutated(_mutation: Dictionary) -> void:
	_is_waiting_for_input = false
	balloon.hide()


func _on_response_mouse_entered(item: Control) -> void:
	if "Disallowed" in item.name: 
		return
	item.grab_focus()


func _on_response_gui_input(event: InputEvent, item: Control) -> void:
	if "Disallowed" in item.name: 
		return
	# A click or ui_accept picks the response.
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == 1:
		response_selected.emit(dialogue_line.responses[item.get_index()].text)
		_next(dialogue_line.responses[item.get_index()].next_id)
	elif event.is_action_pressed("ui_accept") and item in _get_responses():
		response_selected.emit(dialogue_line.responses[item.get_index()].text)
		_next(dialogue_line.responses[item.get_index()].next_id)


# Advances to the next line when there are no responses.
func _on_balloon_gui_input(event: InputEvent) -> void:
	if not _is_waiting_for_input: 
		return
	if dialogue_line.responses.size() > 0: return

	get_viewport().set_input_as_handled()
	
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == 1:
		_next(dialogue_line.next_id)
	elif event.is_action_pressed("ui_accept") and get_viewport().gui_get_focus_owner() == balloon:
		_next(dialogue_line.next_id)


func _on_margin_resized() -> void:
	_handle_resize()


# Instantiates the portrait scene named after the speaker's first name.
func _get_texture_for_dialogue(character: String):
	var person = character.to_lower().split(" ")[0]
	var filename = "%s/" % [person] + "%s.tscn" % [person]
	return load(PATH_SPRITES + filename).instantiate()


func _end_dialogue():
	queue_free()
	self.emit_signal("dialogue_ended")


# Connects a callback to the end of the dialogue.
func on_dialogue_ended(fn):
	dialogue_ended.connect(fn)


# Connects a callback to the selected response.
func on_response_selected(fn):
	response_selected.connect(fn)
