extends Node2D
## Title screen room.
##
## Shows the main menu once the splash screen hands over.


func _ready():
	MainMenu.show_menu(true)
