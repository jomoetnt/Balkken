extends CanvasLayer

var buttons = {}

@onready var movelistNode = get_node("Shade/Movelist")
@onready var boxmenuNode = get_node("Shade/BoxMenu")

# Called when the node enters the scene tree for the first time.
func _ready():
	buttons["Resume"] = get_node("Shade/BoxMenu/MarginContainer/OptionMenu/ResumeButton")
	buttons["Move List"] = get_node("Shade/BoxMenu/MarginContainer/OptionMenu/MoveListButton")
	buttons["Settings"] = get_node("Shade/BoxMenu/MarginContainer/OptionMenu/SettingsButton")
	buttons["Exit Match"] = get_node("Shade/BoxMenu/MarginContainer/OptionMenu/ExitMatchButton")
	buttons["Resume"].pressed.connect(_resume)
	buttons["Move List"].pressed.connect(_show_movelist)
	buttons["Settings"].pressed.connect(_open_settings)
	buttons["Exit Match"].pressed.connect(_exit_match)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("pause"):
		if movelistNode.visible:
			movelistNode.visible = false
			boxmenuNode.visible = true
		else:
			visible = not visible

func _resume():
	visible = false

func _show_movelist():
	boxmenuNode.visible = false
	movelistNode.visible = true

func _open_settings():
	var settingsNode = preload("res://scenes/settings.tscn").instantiate()
	add_child(settingsNode)

func _exit_match():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
