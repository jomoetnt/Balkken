extends MarginContainer

var buttons = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	buttons["Play"] = get_node("VSplitContainer/VBoxContainer/PlayButton")
	buttons["Settings"] = get_node("VSplitContainer/VBoxContainer/SettingsButton")
	buttons["Quit"] = get_node("VSplitContainer/VBoxContainer/QuitButton")
	buttons["Play"].pressed.connect(_play)
	buttons["Settings"].pressed.connect(_open_settings)
	buttons["Quit"].pressed.connect(_quit_game)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _play():
	get_tree().change_scene_to_file("res://scenes/place.tscn")
	
func _open_settings():
	var settingsNode = preload("res://scenes/settings.tscn").instantiate()
	add_child(settingsNode)
	
func _quit_game():
	get_tree().quit()
