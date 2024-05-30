class_name fighter extends CharacterBody3D

var WALK_SPEED = 2.0
var JUMP_VELOCITY = 6.0
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

var collisionNode:CollisionShape3D

@export var player = 1

var moves = {
	"Nothing": commandMove.new(0, 0, 0, "BlendSpace1D"),
	"Jump": commandMove.new(PREJUMP_FRAMES, 0, 0, "jump"),
	"Jump Land": commandMove.new(0, 0, LAND_FRAMES, "jump_land"),
	"Light Punch": commandMove.new(0, 0, 0, "light_punch"),
	"Heavy Punch": commandMove.new(0, 0, 0, "heavy_punch") 
}

var hurtboxes = {
	"Standing": hitbox.new(Vector3(0, 0, 0), Vector3(0, 0, 0), 0),
	"Crouching": hitbox.new(Vector3(0, 0, 0), Vector3(0, 0, 0), 0)
}

# hitbox: collisionshape3d
var activeHitboxes:Dictionary

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
	# hitbox:int, where the value is the frame it should be created.
	var hitboxes:Dictionary
	# Used for whatever information needs to be stored about a move, e.g. how charged
	var data
	func _init(startup:int, active:int, recovery:int, name:StringName):
		startupFrames = startup
		activeFrames = active
		recoveryFrames = recovery
		animationName = name
	func get_duration():
		return startupFrames + activeFrames + recoveryFrames
		
class hitbox:
	var size:Vector3
	var location:Vector3
	var lifetime = 0
	var lifespan:int
	var damage:int
	# Hitlag (or hitstop) is the freeze effect when a hit lands, while hitstun is the opponent not being actionable after being hit.
	var hitlag:int
	var hitstun:int
	var knockback:Vector2
	var active = false
	# E.g. paralysis
	var effects
	func _init(hitSize:Vector3, hitLocation:Vector3, hitLifespan:int):
		size = hitSize
		location = hitLocation
		lifespan = hitLifespan
	

func _ready():
	get_node("../Camera3D").lockMovement.connect(_lock_movement)
	collisionNode = CollisionShape3D.new()
	add_child(collisionNode)
	if player == 1:
		directionFacing = direction.RIGHT
	else:
		directionFacing = direction.LEFT

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	update_state()
	
	move_and_slide()

func isAnimationFinished():
	return anim_state.get_current_play_position() >= anim_state.get_current_length()

func isJumping():
	return anim_state.get_current_node() == "jump" or anim_state.get_current_node() == "jump_idle"
	
func update_state():
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
		
	
	if curMove != moves["Nothing"]:
		for box in curMove.hitboxes:
			if box.active:
				box.lifetime += 1
				if box.lifetime > box.lifespan:
					box.active = false
					box.lifetime = 0
					remove_child(activeHitboxes[box])
					activeHitboxes.erase(box)
			elif get_animation_frames() == curMove.hitboxes[box]:
				var hit = CollisionShape3D.new()
				var hitshape = BoxShape3D.new()
				hitshape.size = box.size
				hit.shape = hitshape
				hit.position = box.location
				add_child(hit)
				activeHitboxes[box] = hit
				box.active = true
		
	process_input(bufferedInput)
	
	if anim_state.get_current_node() == "jump" and isAnimationFinished():
		anim_state.travel("jump_idle")
	
	if anim_state.get_current_node() == "jump_land" and isAnimationFinished():
		anim_state.travel("BlendSpace1D")
	
	if anim_state.get_current_node() == "crouch" and isAnimationFinished():
		anim_state.travel("crouch_idle")
		
	if anim_state.get_current_node() == "jump_idle" and is_on_floor():
		execute_move("Jump Land")

func get_animation_frames():
	var frames = round(anim_state.get_current_play_position() * 60)
	return frames

# Stops player from going off screen
func _lock_movement():
	velocity.x = 0
	movementLocked = true
	
func crouch():
	velocity.x = 0
	anim_state.travel("crouch")
	curMove = moves["Nothing"]
	update_hurtbox("Crouching")
	
func walk(speed):
	anim_state.travel("BlendSpace1D")
	update_hurtbox("Standing")
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

func update_hurtbox(stateName:StringName):
	remove_child(collisionNode)
	collisionNode = CollisionShape3D.new()
	var hurtshape = BoxShape3D.new()
	hurtshape.size = hurtboxes[stateName].size
	collisionNode.shape = hurtshape
	collisionNode.position = hurtboxes[stateName].location
	add_child(collisionNode)

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
