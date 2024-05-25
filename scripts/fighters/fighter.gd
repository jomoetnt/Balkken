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

enum direction {UP, DOWN, LEFT, RIGHT, UPLEFT, UPRIGHT, DOWNLEFT, DOWNRIGHT, NEUTRAL}
enum button {light_punch, light_kick, heavy_punch, heavy_kick, enhance, throw, throw_swap, ultimate, start, ready, none}
enum universalMoves {light_punch, light_kick, heavy_punch, heavy_kick, throw, throw_swap, ultimate}
var curDir = direction.NEUTRAL
var curBtn = button.none

var inputBuffer = []

class motionInput:
	var inputDirection:direction
	var inputButton:button
	func _init(inputDir:direction, inputBtn:button):
		inputDirection = inputDir
		inputButton = inputBtn

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
			curDir = direction.DOWNRIGHT
		elif input_dir.y > 0.5:
			curDir = direction.UPRIGHT
		else:
			curDir = direction.RIGHT
	elif input_dir.x < -0.5:
		if input_dir.y < -0.5:
			curDir = direction.DOWNLEFT
		elif input_dir.y > 0.5:
			curDir = direction.UPLEFT
		else:
			curDir = direction.LEFT
	else:
		if input_dir.y < -0.5:
			curDir = direction.DOWN
		elif input_dir.y > 0.5:
			curDir = direction.UP
		else:
			curDir = direction.NEUTRAL
	
	curBtn = parse_btn()
	
	var curInput = motionInput.new(curDir, curBtn)
	process_input(curInput, SPEED * input_dir.x)

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
			return button.heavy_kick
		if Input.is_action_just_pressed("p1_light_kick"):
			return button.light_kick
		if Input.is_action_just_pressed("p1_heavy_punch"):
			return button.heavy_punch
		if Input.is_action_just_pressed("p1_light_punch"):
			return button.light_punch
	else:
		if Input.is_action_just_pressed("p2_heavy_kick"):
			return button.heavy_kick
		if Input.is_action_just_pressed("p2_light_kick"):
			return button.light_kick
		if Input.is_action_just_pressed("p2_heavy_punch"):
			return button.heavy_punch
		if Input.is_action_just_pressed("p2_light_punch"):
			return button.light_punch
	return button.none

func process_input(motInput:motionInput, speed):
	match dir:
		direction.UP:
			if anim_state.get_current_node() == "BlendSpace1D" || anim_state.get_current_node() == "crouch_idle":
				jump()
		direction.UPRIGHT:
			if anim_state.get_current_node() == "BlendSpace1D" || anim_state.get_current_node() == "crouch_idle":
				velocity.x = speed * 2
				jump()
		direction.UPLEFT:
			if anim_state.get_current_node() == "BlendSpace1D" || anim_state.get_current_node() == "crouch_idle":
				velocity.x = speed * 2
				jump()
		direction.DOWN:
			if anim_state.get_current_node() == "BlendSpace1D":
				crouch()
		direction.DOWNLEFT:
			if anim_state.get_current_node() == "BlendSpace1D":
				crouch()
		direction.DOWNRIGHT:
			if anim_state.get_current_node() == "BlendSpace1D":
				crouch()
		direction.LEFT:
			if anim_state.get_current_node() == "BlendSpace1D" || anim_state.get_current_node() == "crouch_idle":
				walk(speed)
		direction.RIGHT:
			if anim_state.get_current_node() == "BlendSpace1D" || anim_state.get_current_node() == "crouch_idle":
				walk(speed)
		direction.NEUTRAL:
			match btn:
				button.heavy_punch:
					if anim_state.get_current_node() == "BlendSpace1D":
						execute_move("heavy_punch")
				button.light_punch:
					if anim_state.get_current_node() == "BlendSpace1D":
						execute_move("light_punch")
				_:
					if anim_state.get_current_node() == "BlendSpace1D" || anim_state.get_current_node() == "crouch_idle":
						walk(0)
			
