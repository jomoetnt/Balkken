extends Control

@onready var setupPanel:PanelContainer = get_node("ControllerSetupPanel")
var setupVisible = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("pause"):
		_on_button_pressed()

func _on_button_pressed():
	get_parent().remove_child(self)

func _on_vsync_button_item_selected(index):
	if index == 0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	elif index == 1:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_mode_button_item_selected(index):
	if index == 0:
		get_window().set_mode(Window.MODE_WINDOWED)
	elif index == 1:
		get_window().set_mode(Window.MODE_EXCLUSIVE_FULLSCREEN)
		var newScale = ProjectSettings.get("display/window/size/viewport_width") / (get_window().size.x as float)
		get_tree().root.content_scale_factor = newScale
	elif index == 2:
		get_window().set_mode(Window.MODE_FULLSCREEN)
		var newScale = ProjectSettings.get("display/window/size/viewport_width") / (get_window().size.x as float)
		get_tree().root.content_scale_factor = newScale

func _on_width_text_text_submitted(new_text):
	var newSize = Vector2i(int(new_text), get_window().size.y)
	get_window().set_size(newSize)

func _on_height_text_text_submitted(new_text):
	var newSize = Vector2i(get_window().size.x, int(new_text))
	get_window().set_size(newSize)

func _on_profiles_button_pressed():
	var profileScene = preload("res://scenes/profiles.tscn").instantiate()
	add_child(profileScene)


func _on_setup_button_pressed():
	setupVisible = not setupVisible
	setupPanel.set("visible", setupVisible) 

func _on_tab_container_tab_changed(tab):
	setupPanel.set("visible", setupVisible and tab == 2)


func _on_resized():
	var newScale = ProjectSettings.get("display/window/size/viewport_width") / (get_window().size.x as float)
	get_tree().root.content_scale_factor = newScale
	find_child("WidthText", true, true).text = str(get_window().size.x)
	find_child("HeightText", true, true).text = str(get_window().size.y)
