class_name fighter extends CharacterBody3D

var WALK_SPEED = 2.0
var JUMP_VELOCITY = 4.5
var PREJUMP_FRAMES = 5
var LAND_FRAMES = 4
var INPUT_BUFFER_SIZE = 7

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var animation_tree = $AnimationTree
@onready var anim_state = $AnimationTree.get("parameters/playback")

var health = 500
var mana = 0

var actionable = true
var actionableTimer = 0

@export var player = 1

var moves = {
	"Nothing": commandMove.new(0, 0, 0, "BlendSpace1D"),
	"Jump": commandMove.new(PREJUMP_FRAMES, 0, 0, "jump"),
	"Jump Land": commandMove.new(0, 0, LAND_FRAMES, "jump_land"),
	"Light Punch": commandMove.new(0, 0, 0, "light_punch"),
	"Heavy Punch": commandMove.new(0, 0, 0, "heavy_punch") 
}

enum direction {UP, DOWN, LEFT, RIGHT, UPLEFT, UPRIGHT, DOWNLEFT, DOWNRIGHT, NEUTRAL}
enum button {LIGHT_PUNCH, LIGHT_KICK, HEAVY_PUNCH, HEAVY_KICK, ENHANCE, THROW, THROW_SWAP, ULTIMATE_IGNITE, START, READY, NONE}
var curDir = direction.NEUTRAL
var curBtn = button.NONE
var curMove = moves["Nothing"]

var directionFacing:direction
var movementLocked = false

var inputBuffer:Array[motionInput]

signal inputSignal(inputString)

class motionInput:
	var inputDirection:direction
	var inputButton:button
	# How many frames ago the input was made, used for input buffering and rollback
	var lifetime = 0
	func _init(inputDir:direction, inputBtn:button):
		inputDirection = inputDir
		inputButton = inputBtn
	func _to_string():
		if inputButton != button.NONE:
			return direction.keys()[inputDirection] + " + " + button.keys()[inputButton]
		if inputDirection != direction.NEUTRAL:
			return direction.keys()[inputDirection]
		return ""
		
class commandMove:
	# Order of inputs matters
	var commandInputs:Array[motionInput]
	var startupFrames:int
	var activeFrames:int
	var recoveryFrames:int
	var animationName:StringName
	# Used for whatever information needs to be stored about a move, e.g. how charged
	var data
	func _init(startup:int, active:int, recovery:int, name:StringName):
		startupFrames = startup
		activeFrames = active
		recoveryFrames = recovery
		animationName = name
	func get_duration():
		return startupFrames + activeFrames + recoveryFrames

func _ready():
	get_node("../Camera3D").lockMovement.connect(_lock_movement)
	if player == 1:
		directionFacing = direction.RIGHT
	else:
		directionFacing = direction.LEFT

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	updateState()
	
	move_and_slide()

func isAnimationFinished():
	return anim_state.get_current_play_position() >= anim_state.get_current_length()

func isJumping():
	return anim_state.get_current_node() == "jump" or anim_state.get_current_node() == "jump_idle"
	
func updateState():
	# The non-strict inequality here is intentional
	if actionableTimer >= 0:
		actionableTimer -= 1
		
	var bufferedInput = motionInput.new(direction.NEUTRAL, button.NONE)
	
	if actionableTimer == 0:
		actionable = true
		if curMove == moves["Jump"]:
			velocity.y = JUMP_VELOCITY
			velocity.x = curMove.data
		curMove = moves["Nothing"]
		
	if actionableTimer == -1:
		# Only the most recent bufferable input should be considered
		for input in inputBuffer:
			if input.inputButton != button.NONE:
				bufferedInput = input
		actionableTimer = 0
		
	process_input(bufferedInput)
	
	if anim_state.get_current_node() == "jump" and isAnimationFinished():
		anim_state.travel("jump_idle")
	
	if anim_state.get_current_node() == "jump_land" and isAnimationFinished():
		anim_state.travel("BlendSpace1D")
	
	if anim_state.get_current_node() == "crouch" and isAnimationFinished():
		anim_state.travel("crouch_idle")
		
	if anim_state.get_current_node() == "jump_idle" and is_on_floor():
		execute_move("Jump Land")

# Stops player from going off screen
func _lock_movement():
	velocity.x = 0
	movementLocked = true
	
func crouch():
	velocity.x = 0
	anim_state.travel("crouch")
	curMove = moves["Nothing"]
	
func walk(speed):
	anim_state.travel("BlendSpace1D")
	if player == 1:
		animation_tree.set("parameters/BlendSpace1D/blend_position", speed / WALK_SPEED)
	else:
		animation_tree.set("parameters/BlendSpace1D/blend_position", -speed / WALK_SPEED)
	curMove = moves["Nothing"]
	if movementLocked:
		if directionFacing == direction.RIGHT:
			if speed <= 0:
				return
			else:
				movementLocked = false
		elif directionFacing == direction.LEFT:
			if speed >= 0:
				return
			else:
				movementLocked = false
		
	velocity.x = speed
		
func handle_movement(motInput:motionInput, speed):
	match motInput.inputDirection:
		direction.NEUTRAL:
			if curMove == moves["Nothing"] and anim_state.get_current_node() != "jump_land":
				walk(0)
		direction.RIGHT, direction.LEFT:
			if curMove == moves["Nothing"]:
				walk(speed)
		direction.UPLEFT, direction.UP, direction.UPRIGHT:
			if curMove == moves["Nothing"] and anim_state.get_current_node() != "jump" and anim_state.get_current_node() != "jump_idle":
				execute_move("Jump")
				curMove.data = speed * 2
		direction.DOWNLEFT, direction.DOWN, direction.DOWNRIGHT:
			if curMove == moves["Nothing"] and anim_state.get_current_node() != "crouch_idle" and anim_state.get_current_node() != "crouch":
				crouch()

func execute_move(move:StringName):
	velocity.x = 0
	curMove = moves[move]
	anim_state.travel(curMove.animationName)
	actionable = false
	actionableTimer = curMove.get_duration()

# This function non-trivially determines the priority system for inputs
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

func process_input(bufInput:motionInput):
	var input_dir:Vector2
	if player == 1:
		input_dir = Input.get_vector("p1_left", "p1_right", "p1_down", "p1_up")
	else:
		input_dir = Input.get_vector("p2_left", "p2_right", "p2_down", "p2_up")
	
	curBtn = parse_btn()
	
	var curInput = motionInput.new(curDir, curBtn)
	
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
			
	inputSignal.emit(str(curInput))
	
	for input in inputBuffer:
		if input.lifetime >= INPUT_BUFFER_SIZE:
			inputBuffer.erase(input)
		input.lifetime += 1
	
	if !actionable:
		inputBuffer.append(curInput)
		return
	
	if curInput.inputButton == button.NONE and bufInput.inputButton != button.NONE:
		curInput = bufInput
		inputBuffer.clear()
	
	match curInput.inputButton:
		button.NONE:
			if !isJumping():
				handle_movement(curInput, WALK_SPEED * input_dir.x)
		button.HEAVY_PUNCH:
			if !isJumping():
				execute_move("Heavy Punch")
		button.LIGHT_PUNCH:
			if !isJumping():
				execute_move("Light Punch")
