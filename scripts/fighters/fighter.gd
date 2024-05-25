class_name fighter extends CharacterBody3D

const WALK_SPEED = 2.0
const JUMP_VELOCITY = 4.5
const PREJUMP_FRAMES = 5
const LAND_FRAMES = 4

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var animation_tree = $AnimationTree
@onready var anim_state = $AnimationTree.get("parameters/playback")

var health = 500
var mana = 0

var actionable = true
var actionableTimer = 0

var player = 1

var moves = {
	"Nothing": commandMove.new(0, 0, 0),
	"Jump": commandMove.new(PREJUMP_FRAMES, 0, 0),
	"Jump Land": commandMove.new(0, 0, LAND_FRAMES),
	"Light Punch": commandMove.new(0, 0, 0),
	"Heavy Punch": commandMove.new(0, 0, 0) 
}

enum direction {UP, DOWN, LEFT, RIGHT, UPLEFT, UPRIGHT, DOWNLEFT, DOWNRIGHT, NEUTRAL}
enum button {LIGHT_PUNCH, LIGHT_KICK, HEAVY_PUNCH, HEAVY_KICK, ENHANCE, THROW, THROW_SWAP, ULTIMATE_IGNITE, START, READY, NONE}
var curDir = direction.NEUTRAL
var curBtn = button.NONE
var curMove = moves["Nothing"]

var inputBuffer:Array[motionInput]

signal inputSignal(inputString)

class motionInput:
	var inputDirection:direction
	var inputButton:button
	var lifetime:int
	func _init(inputDir:direction, inputBtn:button):
		inputDirection = inputDir
		inputButton = inputBtn
		lifetime = determine_lifetime()
	func determine_lifetime():
		return 30
	func _to_string():
		if inputButton != button.NONE:
			return direction.keys()[inputDirection] + " + " + button.keys()[inputButton]
		if inputDirection != direction.NEUTRAL:
			return direction.keys()[inputDirection]
		return ""
		

class commandMove:
	var commandInputs = []
	var startupFrames = 0
	var activeFrames = 0
	var recoveryFrames:int
	func _init(startup:int, active:int, recovery:int):
		startupFrames = startup
		activeFrames = active
		recoveryFrames = recovery

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	updateState()
		
	# Get the input direction
	var input_dir:Vector2
	if player == 1:
		input_dir = Input.get_vector("p1_left", "p1_right", "p1_down", "p1_up")
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
	process_input(curInput, WALK_SPEED * input_dir.x)
	
	move_and_slide()

func isAnimationFinished():
	return anim_state.get_current_play_position() >= anim_state.get_current_length()
	
func updateState():
	if actionableTimer > 0:
		actionableTimer -= 1
		
	if actionableTimer == 0:
		actionable = true
		curMove = moves["Nothing"]
	
	if anim_state.get_current_node() == "jump" and isAnimationFinished():
		anim_state.travel("jump_idle")
	
	if anim_state.get_current_node() == "jump_land" and isAnimationFinished():
		anim_state.travel("BlendSpace1D")
	
	if anim_state.get_current_node() == "crouch" and isAnimationFinished():
		anim_state.travel("crouch_idle")
		
	if anim_state.get_current_node() == "jump_idle" and is_on_floor():
		land()

func jump(xDirection):
	velocity.y = JUMP_VELOCITY
	velocity.x = xDirection * WALK_SPEED * 2
	curMove = moves["Jump"]
	actionable = false
	actionableTimer = curMove.startupFrames
	anim_state.travel("jump")
	
func land():
	anim_state.travel("jump_land")
	velocity.x = 0
	curMove = moves["Jump Land"]
	actionableTimer = curMove.recoveryFrames
	actionable = false
	
func crouch():
	velocity.x = 0
	anim_state.travel("crouch")
	curMove = moves["Nothing"]
	
func walk(speed):
	anim_state.travel("BlendSpace1D")
	velocity.x = speed
	if player == 1:
		animation_tree.set("parameters/BlendSpace1D/blend_position", speed / WALK_SPEED)
	else:
		animation_tree.set("parameters/BlendSpace1D/blend_position", -speed / WALK_SPEED)
	curMove = moves["Nothing"]
		
func handle_movement(motInput:motionInput, speed):
	match motInput.inputDirection:
		direction.NEUTRAL:
			if curMove == moves["Nothing"] and anim_state.get_current_node() != "jump_land":
				walk(0)
		direction.RIGHT, direction.LEFT:
			if curMove == moves["Nothing"]:
				walk(speed)
		direction.UPLEFT:
			if curMove == moves["Nothing"]:
				jump(-1)
		direction.UP:
			if curMove == moves["Nothing"]:
				jump(0)
		direction.UPRIGHT:
			if curMove == moves["Nothing"]:
				jump(1)
		direction.DOWNLEFT, direction.DOWN, direction.DOWNRIGHT:
			if curMove == moves["Nothing"] and anim_state.get_current_node() != "crouch_idle" and anim_state.get_current_node() != "crouch":
				crouch()

func execute_move(move:StringName):
	velocity.x = 0
	match move:
		"heavy_punch":
			anim_state.travel("heavy_punch")
			curMove = moves["Heavy Punch"]
			actionable = false
			actionableTimer = curMove.recoveryFrames
		"light_punch":
			anim_state.travel("light_punch")
			curMove = moves["Light Punch"]
			actionable = false
			actionableTimer = curMove.recoveryFrames

func parse_btn():
	if player == 1:
		if Input.is_action_just_pressed("p1_heavy_kick"):
			return button.HEAVY_KICK
		if Input.is_action_just_pressed("p1_light_kick"):
			return button.LIGHT_KICK
		if Input.is_action_just_pressed("p1_heavy_punch"):
			return button.HEAVY_PUNCH
		if Input.is_action_just_pressed("p1_light_punch"):
			return button.LIGHT_PUNCH
	else:
		if Input.is_action_just_pressed("p2_heavy_kick"):
			return button.HEAVY_KICK
		if Input.is_action_just_pressed("p2_light_kick"):
			return button.LIGHT_KICK
		if Input.is_action_just_pressed("p2_heavy_punch"):
			return button.HEAVY_PUNCH
		if Input.is_action_just_pressed("p2_light_punch"):
			return button.LIGHT_PUNCH
	return button.NONE

func process_input(motInput:motionInput, speed):
	inputSignal.emit(str(motInput))
	if !actionable:
		inputBuffer.append(motInput)
		return
	for input in inputBuffer:
		input.lifetime -= 1
		if input.lifetime <= 0:
			inputBuffer.erase(input)
	
	match motInput.inputButton:
		button.NONE:
			if anim_state.get_current_node() != "jump_idle" and anim_state.get_current_node() != "jump":
				handle_movement(motInput, speed)
		button.HEAVY_PUNCH:
			if anim_state.get_current_node() != "jump_idle":
				execute_move("heavy_punch")
		button.LIGHT_PUNCH:
			if anim_state.get_current_node() != "jump_idle":
				execute_move("light_punch")
