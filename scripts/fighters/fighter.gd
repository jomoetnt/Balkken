class_name fighter extends CharacterBody3D

const SPEED = 2.0
const JUMP_VELOCITY = 4.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var animation_tree = $AnimationTree
@onready var anim_state = $AnimationTree.get("parameters/playback")

var health = 500
var mana = 0

var player = 1

enum dirList {UP, DOWN, LEFT, RIGHT, UPLEFT, UPRIGHT, DOWNLEFT, DOWNRIGHT, NEUTRAL}
enum btnList {light_punch, light_kick, heavy_punch, heavy_kick, enhance, throw, throw_swap, ultimate, start, ready, none}
enum universalMoves {light_punch, light_kick, heavy_punch, heavy_kick, throw, throw_swap, ultimate}
var curDir = dirList.NEUTRAL
var curBtn = btnList.none

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	# Get the input direction
	var input_dir:Vector2
	if player == 1:
		input_dir = Input.get_vector("p1_left", "p1_right", "p1_down", "p1_up")
		print(input_dir)
	else:
		input_dir = Input.get_vector("p2_left", "p2_right", "p2_down", "p2_up")
	
	if input_dir.x > 0.5:
		if input_dir.y < -0.5:
			curDir = dirList.DOWNRIGHT
		elif input_dir.y > 0.5:
			curDir = dirList.UPRIGHT
		else:
			curDir = dirList.RIGHT
	elif input_dir.x < -0.5:
		if input_dir.y < -0.5:
			curDir = dirList.DOWNLEFT
		elif input_dir.y > 0.5:
			curDir = dirList.UPLEFT
		else:
			curDir = dirList.LEFT
	else:
		if input_dir.y < -0.5:
			curDir = dirList.DOWN
		elif input_dir.y > 0.5:
			curDir = dirList.UP
		else:
			curDir = dirList.NEUTRAL
	
	curBtn = parse_btn()
	
	process_input(curDir, SPEED * input_dir.x, curBtn)

	#Handles land
	if anim_state.get_current_node() == "jump_idle" and is_on_floor():
		land()
	
	move_and_slide()

func jump():
	velocity.y = JUMP_VELOCITY
	anim_state.travel("jump")
	
func land():
	anim_state.travel("jump_land")
	velocity.x = 0
	
func crouch():
	velocity.x = 0
	anim_state.travel("crouch")
	
func walk(speed):
	anim_state.travel("BlendSpace1D")
	velocity.x = speed
	if player == 1:
		animation_tree.set("parameters/BlendSpace1D/blend_position", speed / SPEED)
	else:
		animation_tree.set("parameters/BlendSpace1D/blend_position", -speed / SPEED)

func execute_move(move:StringName):
	match move:
		"heavy_punch":
			anim_state.travel("heavy_punch")
		"light_punch":
			anim_state.travel("light_punch")

func parse_btn():
	if player == 1:
		if Input.is_action_just_pressed("p1_heavy_kick"):
			return btnList.heavy_kick
		if Input.is_action_just_pressed("p1_light_kick"):
			return btnList.light_kick
		if Input.is_action_just_pressed("p1_heavy_punch"):
			return btnList.heavy_punch
		if Input.is_action_just_pressed("p1_light_punch"):
			return btnList.light_punch
	else:
		if Input.is_action_just_pressed("p2_heavy_kick"):
			return btnList.heavy_kick
		if Input.is_action_just_pressed("p2_light_kick"):
			return btnList.light_kick
		if Input.is_action_just_pressed("p2_heavy_punch"):
			return btnList.heavy_punch
		if Input.is_action_just_pressed("p2_light_punch"):
			return btnList.light_punch
	return btnList.none

func process_input(dir:dirList, speed, btn:btnList):
	match dir:
		dirList.UP:
			if anim_state.get_current_node() == "BlendSpace1D" || anim_state.get_current_node() == "crouch_idle":
				jump()
		dirList.UPRIGHT:
			if anim_state.get_current_node() == "BlendSpace1D" || anim_state.get_current_node() == "crouch_idle":
				velocity.x = speed * 2
				jump()
		dirList.UPLEFT:
			if anim_state.get_current_node() == "BlendSpace1D" || anim_state.get_current_node() == "crouch_idle":
				velocity.x = speed * 2
				jump()
		dirList.DOWN:
			if anim_state.get_current_node() == "BlendSpace1D":
				crouch()
		dirList.DOWNLEFT:
			if anim_state.get_current_node() == "BlendSpace1D":
				crouch()
		dirList.DOWNRIGHT:
			if anim_state.get_current_node() == "BlendSpace1D":
				crouch()
		dirList.LEFT:
			if anim_state.get_current_node() == "BlendSpace1D" || anim_state.get_current_node() == "crouch_idle":
				walk(speed)
		dirList.RIGHT:
			if anim_state.get_current_node() == "BlendSpace1D" || anim_state.get_current_node() == "crouch_idle":
				walk(speed)
		dirList.NEUTRAL:
			match btn:
				btnList.heavy_punch:
					if anim_state.get_current_node() == "BlendSpace1D":
						execute_move("heavy_punch")
				btnList.light_punch:
					if anim_state.get_current_node() == "BlendSpace1D":
						execute_move("light_punch")
				_:
					if anim_state.get_current_node() == "BlendSpace1D" || anim_state.get_current_node() == "crouch_idle":
						walk(0)
			
