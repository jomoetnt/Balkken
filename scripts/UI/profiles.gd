extends PanelContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_save_button_pressed():
	pass # Replace with function body.


func _on_exit_button_pressed():
	get_parent().remove_child(self)
