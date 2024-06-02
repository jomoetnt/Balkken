class_name KillerBeanFighter extends "fighter.gd"


func _ready():
	super._ready()
	hurtboxes["Standing"].size = Vector3(0.735, 1.413, 0.5)
	hurtboxes["Standing"].location = Vector3(0.048, -0.12, 0.2)
	hurtboxes["Crouching"].size = Vector3(0.735, 1.22, 0.5)
	hurtboxes["Crouching"].location = Vector3(0.048, -0.23, 0.2)
	
	initialize_moves()

# temporary
func initialize_moves():
	moves["Light Punch"].recoveryFrames = 17
	var jabBox = hitbox.new(Vector3(1, 1, 0.5), Vector3(1, 0, 0), 5)
	jabBox.hitstun = 4
	jabBox.damage = 5
	jabBox.blockstun = 5
	moves["Light Punch"].hitboxes[jabBox] = 5
	moves["Heavy Punch"].startupFrames = 10
	moves["Heavy Punch"].recoveryFrames = 26
	var crossBox = hitbox.new(Vector3(1, 1, 0.5), Vector3(1, 0, 0), 15)
	crossBox.hitstun = 15
	crossBox.damage = 10
	crossBox.blockstun = 10
	crossBox.knockback = Vector2(2, 2)
	crossBox.blockKnockback = Vector2(1, 0)
	moves["Heavy Punch"].hitboxes[crossBox] = 12
	
func _cancel_move(_curInput:motionInput):
	if _curInput.inputButton == button.HEAVY_PUNCH && curMove == moves["Light Punch"]:
		execute_move(moves["Heavy Punch"])
		return true
	return false
