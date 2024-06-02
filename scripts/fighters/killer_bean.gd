class_name KillerBeanFighter extends "fighter.gd"


func _ready():
	super._ready()
	hurtboxes["Standing"].size = Vector3(0.735, 1.413, 0.5)
	hurtboxes["Standing"].location = Vector3(0.048, -0.12, 0.2)
	hurtboxes["Crouching"].size = Vector3(0.735, 1.22, 0.5)
	hurtboxes["Crouching"].location = Vector3(0.048, -0.23, 0.2)
	FIGHTER_NAME = "Killer Bean"
	#write_to_file("res://data/killer_bean.json", budget_stringify(0))
	
func _cancel_move(_curInput:motionInput):
	if _curInput.inputButton == button.HEAVY_PUNCH && curMove == moves["Light Punch"]:
		execute_move(moves["Heavy Punch"])
		return true
	return false
