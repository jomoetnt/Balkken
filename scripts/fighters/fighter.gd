class_name fighter extends CharacterBody3D

# Universal character constants
const SLIDE_VELOCITY = 0.5
const EPSILON = 0.1
const MAX_MANA = 10
const CROUCH_DAMAGE = 1.5

# Character specific constants
var WALK_SPEED = 2.0
var JUMP_VELOCITY = 6.0
var PREJUMP_FRAMES = 5
var LAND_FRAMES = 4
var INPUT_BUFFER_SIZE = 7
var MAX_HEALTH = 500

var health = MAX_HEALTH
var mana = 0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var animation_tree = $AnimationTree
@onready var anim_state = $AnimationTree.get("parameters/playback")
@onready var anim_player = $AnimationPlayer

var actionable = true
var actionableTimer = 0

var slowmoTimer = 0

var hurtboxNode:CollisionShape3D

@export var player = 1

# StringName: commandMove
var moves:Dictionary

var hurtboxes = {
	"Standing": hitbox.new(Vector3.ZERO, Vector3.ZERO, 0),
	"Crouching": hitbox.new(Vector3.ZERO, Vector3.ZERO, 0)
}

# Q = quarter, C = circle, R = right, L = left
var motions = {
	"QCR": [motionInput.new(direction.DOWN, button.NONE), motionInput.new(direction.DOWNRIGHT, button.NONE), motionInput.new(direction.RIGHT, button.NONE)],
	"QCL": [motionInput.new(direction.DOWN, button.NONE), motionInput.new(direction.DOWNLEFT, button.NONE), motionInput.new(direction.LEFT, button.NONE)],
	"HCR": [motionInput.new(direction.LEFT, button.NONE), motionInput.new(direction.DOWNLEFT, button.NONE), motionInput.new(direction.DOWN, button.NONE), \
	motionInput.new(direction.DOWNRIGHT, button.NONE), motionInput.new(direction.RIGHT, button.NONE)],
	"HCL": [motionInput.new(direction.RIGHT, button.NONE), motionInput.new(direction.DOWNRIGHT, button.NONE), motionInput.new(direction.DOWN, button.NONE), \
	motionInput.new(direction.DOWNLEFT, button.NONE), motionInput.new(direction.LEFT, button.NONE)],
	"ZR": [motionInput.new(direction.RIGHT, button.NONE), motionInput.new(direction.DOWN, button.NONE), motionInput.new(direction.DOWNRIGHT, button.NONE)],
	"ZL": [motionInput.new(direction.LEFT, button.NONE), motionInput.new(direction.DOWN, button.NONE), motionInput.new(direction.DOWNLEFT, button.NONE)],
}

# Array[motionInput]: Array[commandMove]
var motionMap = {}

# hitbox: Area3D
var activeHitboxes = {}

enum direction {UP, DOWN, LEFT, RIGHT, UPLEFT, UPRIGHT, DOWNLEFT, DOWNRIGHT, NEUTRAL}
enum button {LIGHT_PUNCH, LIGHT_KICK, HEAVY_PUNCH, HEAVY_KICK, ENHANCE, THROW, THROW_SWAP, ULTIMATE_IGNITE, START, READY, NONE}
enum inputFlag {CANCELLED, BUFFERED, DROPPED}

var curDir = direction.NEUTRAL
var curBtn = button.NONE
var curMove:commandMove

var directionFacing:direction
var movementLocked = false

var inputBuffer:Array[motionInput]

var sliding = false
var blocking = false

signal inputSignal(inputString, flags)
signal healthSignal(healthInt)

class motionInput:
	var inputDirection:direction
	var inputButton:button
	# How many frames ago the input was made, used for input buffering and rollback
	var lifetime = 0
	func _init(inputDir:direction, inputBtn:button):
		inputDirection = inputDir
		inputButton = inputBtn
	func _to_string():
		return direction.keys()[inputDirection] + " + " + button.keys()[inputButton]
		
class commandMove:
	enum state {STANDING, JUMPING}
	var commandInputs = []
	var startupFrames:int
	var activeFrames:int
	var recoveryFrames:int
	var cancelMoves:Array
	var animationName:StringName
	var moveName:StringName
	var moveState:state
	# hitbox:int, where the value is the frame it should be created.
	var hitboxes:Dictionary
	# Used for whatever information needs to be stored about a move, e.g. how charged
	var data
	func _init(startup:int, active:int, recovery:int, animName:StringName, name:StringName):
		startupFrames = startup
		activeFrames = active
		recoveryFrames = recovery
		animationName = animName
		moveName = name
	func get_duration():
		return startupFrames + activeFrames + recoveryFrames
	func _to_string():
		return str(moveName)
		
class hitbox:
	var size:Vector3
	var location:Vector3
	var lifetime = 0
	var lifespan:int
	var damage:int
	# Damage dealt on blocking target
	var chipDamage:int
	# Hitlag (or hitstop) is the freeze effect when a hit lands, while hitstun is the opponent not being actionable after being hit.
	var hitlag:int
	var hitstun:int
	var blockstun:int
	var knockback:Vector2
	var blockKnockback: Vector2
	var active = false
	# E.g. paralysis
	var effects
	func _init(hitSize:Vector3, hitLocation:Vector3, hitLifespan:int):
		size = hitSize
		location = hitLocation
		lifespan = hitLifespan
	
# kinda messy
func _ready():
	get_node("../Camera3D").lockMovement.connect(_lock_movement)
	
	get_parent().changeDirSignal.connect(_change_direction)
	
	hurtboxNode = CollisionShape3D.new()
	add_child(hurtboxNode)
	
	if player == 1:
		directionFacing = direction.RIGHT
	else:
		directionFacing = direction.LEFT
	
	healthSignal.emit(health)
	
	var mList = []
	_init_moves(mList)
	for move in mList:
		moves[move.moveName] = move
	
	for moveName in moves:
		var move = moves[moveName]
		if motionMap.has(move.commandInputs):
			motionMap[move.commandInputs].append(move)
		else:
			motionMap[move.commandInputs] = [move]
	
	curMove = moves["Nothing"]
	
func _init_moves(list):
	var nothing = commandMove.new(0, 0, 0, "BlendSpace1D", "Nothing")
	nothing.commandInputs.append(motionInput.new(direction.NEUTRAL, button.NONE))
	list.append(nothing)
	var slp = commandMove.new(0, 0, 0, "light_punch", "Light Punch")
	slp.commandInputs.append(motionInput.new(direction.NEUTRAL, button.LIGHT_PUNCH))
	slp.moveState = slp.state.STANDING
	list.append(slp)
	var shp = commandMove.new(0, 0, 0, "heavy_punch", "Heavy Punch")
	shp.commandInputs.append(motionInput.new(direction.NEUTRAL, button.HEAVY_PUNCH))
	shp.moveState = shp.state.STANDING
	list.append(shp)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	update_state()
	if sliding:
		velocity.x = SLIDE_VELOCITY * -scale.x

	# Slide players if they collide with each other
	if move_and_slide():
		var collision = get_last_slide_collision()
		sliding = false
		for j in collision.get_collision_count():
			var collider = collision.get_collider(j)
			if collider is fighter and collider != self:
				position.x -= scale.x * delta * SLIDE_VELOCITY
				collider.position.x -= collider.scale.x * delta * SLIDE_VELOCITY
				if position.y > collider.position.y + EPSILON and velocity.y < 0:
					position.y = collider.hurtboxNode.shape.size.y + collider.position.y + delta
				sliding = true
				collider.sliding = true
							
func player_hurt(hurter:hitbox):
	if is_blocking_standing():
		health -= hurter.chipDamage
		actionable = false
		actionableTimer = hurter.blockstun
		velocity.x = hurter.blockKnockback.x * -scale.x
		velocity.y = hurter.blockKnockback.y
		anim_state.travel("block_standing")
		curMove = moves["Block Standing"]
		healthSignal.emit(health)
		blocking = true
	elif is_blocking_crouching():
		health -= hurter.chipDamage * CROUCH_DAMAGE
		actionable = false
		actionableTimer = hurter.blockstun
		velocity.x = hurter.blockKnockback.x * -scale.x
		velocity.y = hurter.blockKnockback.y
		anim_state.travel("block_crouching")
		curMove = moves["Block Crouching"]
		healthSignal.emit(health)
		blocking = true
	else:
		if anim_state.get_current_node() != "crouch_idle":
			health -= hurter.damage
		else:
			health -= hurter.damage * CROUCH_DAMAGE
		actionable = false
		actionableTimer = hurter.hitstun
		velocity.x = hurter.knockback.x * -scale.x
		velocity.y = hurter.knockback.y
		var length = hurter.knockback.length()
		anim_state.travel("hurt_standing")
		healthSignal.emit(health)
		if length > 1.0:
			Engine.time_scale = 0.1
			slowmoTimer = round(length) * 10
		
func is_blocking_standing():
	if directionFacing == direction.RIGHT:
		return curDir == direction.LEFT
	else:
		return curDir == direction.RIGHT
		
func is_blocking_crouching():
	if directionFacing == direction.RIGHT:
		return curDir == direction.DOWNLEFT
	else:
		return curDir == direction.DOWNRIGHT

func is_animation_finished():
	if anim_state.get_current_node() == "block_standing" or anim_state.get_current_node() == "block_crouching":
		return false
	return anim_state.get_current_play_position() >= anim_state.get_current_length() && Engine.time_scale == 1

func is_jumping():
	return anim_state.get_current_node() == "jump" or anim_state.get_current_node() == "jump_idle"

func _change_direction():
	if directionFacing == direction.RIGHT:
		directionFacing = direction.LEFT
	else:
		directionFacing = direction.RIGHT
	scale.x *= -1
	
func update_state():
	# The non-strict inequality here is intentional
	if actionableTimer >= 0 && abs(Engine.time_scale - 1) < EPSILON:
		actionableTimer -= 1
		
	if slowmoTimer > 0:
		slowmoTimer -= 1
		if slowmoTimer == 0:
			Engine.time_scale = 1
		
	var bufferedInput = motionInput.new(direction.NEUTRAL, button.NONE)
	
	if !actionable and actionableTimer <= 0:
		actionable = true
		if anim_state.get_current_node() == "jump":
			velocity.y = JUMP_VELOCITY
			velocity.x = curMove.data
		curMove = moves["Nothing"]
		
	if actionableTimer == -1:
		# Only the most recent bufferable input should be considered
		for input in inputBuffer:
			if input.inputButton != button.NONE:
				bufferedInput = input
		
	for box in activeHitboxes.keys():
		box.lifetime += 1
		if box.lifetime > box.lifespan:
			box.active = false
			box.lifetime = 0
			remove_child(activeHitboxes[box])
			# apparently erasing elements while iterating over an array results in undefined behaviour
			activeHitboxes.erase(box)
			break
		for hitPlayer in activeHitboxes[box].get_overlapping_bodies():
			if hitPlayer is fighter:
				hitPlayer.player_hurt(box)
				box.active = false
				box.lifetime = 0
				remove_child(activeHitboxes[box])
				# apparently erasing elements while iterating over an array results in undefined behaviour
				activeHitboxes.erase(box)
	
	for box in curMove.hitboxes:
		if get_animation_frames() == curMove.hitboxes[box]:
			# Area3D lets us check for collisions, which needs a CollisionShape3D child node, which needs a Shape3D property.
			var hitDetector = Area3D.new()
			var hitShape = CollisionShape3D.new()
			var hitBox = BoxShape3D.new()
			hitBox.size = box.size
			hitShape.shape = hitBox
			hitShape.position = box.location
			add_child(hitDetector)
			hitDetector.add_child(hitShape)
			activeHitboxes[box] = hitDetector
			box.active = true
		
	process_input(bufferedInput)
	
	if anim_state.get_current_node() == "jump" and is_animation_finished():
		anim_state.travel("jump_idle")
	
	if anim_state.get_current_node() == "jump_land" and is_animation_finished():
		anim_state.travel("BlendSpace1D")
	
	if anim_state.get_current_node() == "crouch" and is_animation_finished():
		anim_state.travel("crouch_idle")
	
	if anim_state.get_current_node() == "block_standing" and actionable:
		anim_state.travel("BlendSpace1D")
	
	if anim_state.get_current_node() == "block_crouching" and actionable:
		anim_state.travel("BlendSpace1D")
	
	if curMove != moves["Nothing"] and is_animation_finished():
		curMove = moves["Nothing"]
		anim_state.travel("BlendSpace1D")
		
	if anim_state.get_current_node() == "jump_idle" and is_on_floor() and !sliding:
		anim_state.travel("jump_land")
		actionable = false
		actionableTimer = LAND_FRAMES
		velocity.x = 0

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
	if directionFacing == direction.RIGHT:
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
			walk(0)
		direction.RIGHT, direction.LEFT:
			walk(speed)
		direction.UPLEFT, direction.UP, direction.UPRIGHT:
			velocity.x = 0
			anim_state.travel("jump")
			actionable = false
			actionableTimer = PREJUMP_FRAMES
			curMove.data = speed * 2
		direction.DOWNLEFT, direction.DOWN, direction.DOWNRIGHT:
			if anim_state.get_current_node() != "crouch_idle":
				crouch()

func execute_move(move:commandMove):
	velocity.x = 0
	curMove = move
	if move == moves["Nothing"]:
		return
	anim_state.travel(move.animationName)
	if anim_state.get_current_node() == move.animationName:
		anim_state.start(move.animationName)
	actionableTimer = move.get_duration()
	if actionableTimer > 0:
		actionable = false

func update_hurtbox(stateName:StringName):
	remove_child(hurtboxNode)
	hurtboxNode = CollisionShape3D.new()
	var hurtshape = BoxShape3D.new()
	hurtshape.size = hurtboxes[stateName].size
	hurtboxNode.shape = hurtshape
	hurtboxNode.position = hurtboxes[stateName].location
	add_child(hurtboxNode)

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
	var curFlags = []
	
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
	
	for input in inputBuffer:
		if input.lifetime >= INPUT_BUFFER_SIZE:
			# apparently erasing elements while iterating over an array results in undefined behaviour
			inputBuffer.erase(input)
		input.lifetime += 1
	
	if !actionable:
		if _cancel_move(curInput):
			curFlags.append(inputFlag.CANCELLED)
		else:
			curFlags.append(inputFlag.DROPPED)
		inputBuffer.append(curInput)
		inputSignal.emit(str(curInput), curFlags)
		return	
	
	if curInput.inputButton == button.NONE and bufInput.inputButton != button.NONE:
		curInput = bufInput
		curFlags.append(inputFlag.BUFFERED)
		inputBuffer.clear()
	
	inputSignal.emit(str(curInput), curFlags)
	
	if !is_jumping() and curMove == moves["Nothing"] and anim_state.get_current_node() != "jump_land" and curInput.inputButton == button.NONE:
		handle_movement(curInput, WALK_SPEED * input_dir.x)
	else:
		var curMotion = inputBuffer.duplicate(true)
		curMotion.append(curInput)
		
		var dirName = direction.keys()[curInput.inputDirection]
		var butName = button.keys()[curInput.inputButton]
		
		
		var potentialMoves = []
		for motion in motionMap:
			if are_same_motions(curMotion, motion) and motion in motionMap:
				potentialMoves.append_array(motionMap[motion])
		if is_jumping():
			for move in potentialMoves:
				if move.moveState == move.state.JUMPING:
					execute_move(move)
					return
		else:
			for move in potentialMoves:
				if move.moveState == move.state.STANDING:
					execute_move(move)
					return

func are_same_inputs(input1:motionInput, input2:motionInput):
	if input1 == null or input2 == null:
		if input1 == null and input2 == null:
			return true
		return false
	if input1.inputDirection == input2.inputDirection and input1.inputButton == input2.inputButton:
		return true
	return false

# This will have some more complicated logic in the future to make motion inputs a bit lenient.
# Currently removes repeated values in both motions, only comparing the elements and their order.
func are_same_motions(motion1:Array, motion2:Array):
	if motion1.is_empty() or motion2.is_empty():
		if motion1.is_empty() and motion2.is_empty():
			return true
		return false
	var minSize = min(motion1.size(), motion2.size())
	var lastUniqueInput1:motionInput
	var lastUniqueInput2:motionInput
	var cleanedMotion1 = []
	var cleanedMotion2 = []
	for i in minSize:
		if are_same_inputs(motion1[i], moves["Nothing"].commandInputs[0]) or are_same_inputs(motion2[i], moves["Nothing"].commandInputs[0]):
			continue
		if !are_same_inputs(motion1[i], lastUniqueInput1):
			lastUniqueInput1 = motion1[i]
			cleanedMotion1.append(lastUniqueInput1)
		if !are_same_inputs(motion2[i], lastUniqueInput2):
			lastUniqueInput2 = motion2[i]
			cleanedMotion2.append(lastUniqueInput2)
	if lastUniqueInput1 == null or lastUniqueInput2 == null:
		return false
	var cleanedSize = cleanedMotion1.size()
	if cleanedSize != cleanedMotion2.size():
		return false
	for i in cleanedSize:
		if !are_same_inputs(cleanedMotion1[i], cleanedMotion2[i]):
			return false
	return true

# Virtual function for cancelling certain moves into others
func _cancel_move(_curInput:motionInput):
	pass
