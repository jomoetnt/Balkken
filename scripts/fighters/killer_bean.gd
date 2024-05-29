class_name KillerBeanFighter extends "fighter.gd"


func _init():
	hurtboxes["Standing"].size = Vector3(0.735, 1.413, 0.5)
	hurtboxes["Standing"].location = Vector3(0.048, -0.12, 0.2)
	hurtboxes["Crouching"].size = Vector3(0.735, 1.22, 0.5)
	hurtboxes["Crouching"].location = Vector3(0.048, -0.23, 0.2)
	
	initializeMoves()

func initializeMoves():
	moves["Light Punch"].recoveryFrames = 17
	moves["Light Punch"].hitboxes[5] = hitbox.new(Vector3(1, 1, 0.5), Vector3(1, 0, 0), 5)
	moves["Heavy Punch"].recoveryFrames = 36
	moves["Heavy Punch"].hitboxes[12] = hitbox.new(Vector3(1, 1, 0.5), Vector3(1, 0, 0), 15)
	
