class_name fighter extends CharacterBody3D

const SLIDE_VELOCITY = 0.5
const EPSILON = 0.1

var WALK_SPEED = 2.0
var JUMP_VELOCITY = 6.0
var PREJUMP_FRAMES = 5
var LAND_FRAMES = 4
var INPUT_BUFFER_SIZE = 7

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var animation_tree = $AnimationTree
@onready var anim_state = $AnimationTree.get("parameters/playback")
@onready var anim_player = $AnimationPlayer

var health = 500
var mana = 0

var actionable = true
var actionableTimer = 0

var slowmoTimer = 0

var hurtboxNode:CollisionShape3D

@export var player = 1

var moves = {
	"Nothing": commandMove.new(0, 0, 0, "BlendSpace1D"),
	"Jump": commandMove.new(PREJUMP_FRAMES, 0, 0, "jump"),
	"Jump Land": commandMove.new(0, 0, LAND_FRAMES, "jump_land"),
	"Light Punch": commandMove.new(0, 0, 0, "light_punch"),
	"Heavy Punch": commandMove.new(0, 0, 0, "heavy_punch") 
}

var hurtboxes = {
	"Standing": hitbox.new(Vector3.ZERO, Vector3.ZERO, 0),
	"Crouching": hitbox.new(Vector3.ZERO, Vector3.ZERO, 0)
}

# hitbox: Area3D
var activeHitboxes:Dictionary

enum direction {UP, DOWN, LEFT, RIGHT, UPLEFT, UPRIGHT, DOWNLEFT, DOWNRIGHT, NEUTRAL}
enum button {LIGHT_PUNCH, LIGHT_KICK, HEAVY_PUNCH, HEAVY_KICK, ENHANCE, THROW, THROW_SWAP, ULTIMATE_IGNITE, START, READY, NONE}
enum inputFlag {CANCELLED, BUFFERED, DROPPED}
var curDir = direction.NEUTRAL
var curBtn = button.NONE
var curMove = moves["Nothing"]

var directionFacing:direction
var movementLocked = false

var inputBuffer:Array[motionInput]

var sliding = false

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
	get_parent().changeDirSignal.connect(_change_direction)
	hurtboxNode = CollisionShape3D.new()
	add_child(hurtboxNode)
	if player == 1:
		directionFacing = direction.RIGHT
	else:
		directionFacing = direction.LEFT
	healthSignal.emit(health)

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
	health -= hurter.damage
	actionable = false
	actionableTimer = hurter.hitstun
	velocity.x = hurter.knockback.x
	velocity.y = hurter.knockback.y
	var length = hurter.knockback.length()
	anim_state.travel("hurt_standing")
	healthSignal.emit(health)
	if length > 1.0:
		Engine.time_scale = 0.1
		slowmoTimer = round(length) * 10

func is_animation_finished():
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
	if actionableTimer >= 0 && Engine.time_scale == 1:
		actionableTimer -= 1
		
	if slowmoTimer > 0:
		slowmoTimer -= 1
		if slowmoTimer == 0:
			Engine.time_scale = 1
		
	var bufferedInput = motionInput.new(direction.NEUTRAL, button.NONE)
	
	if actionableTimer == 0:
		actionable = true
		if curMove == moves["Jump"] and anim_state.get_current_node() != "jump_idle":
			velocity.y = JUMP_VELOCITY
			velocity.x = curMove.data
			curMove = moves["Nothing"]
		
	if actionableTimer == -1:
		# Only the most recent bufferable input should be considered
		for input in inputBuffer:
			if input.inputButton != button.NONE:
				bufferedInput = input
		actionableTimer = 0
		
	for box in activeHitboxes.keys():
		box.lifetime += 1
		if box.lifetime > box.lifespan:
			box.active = false
			box.lifetime = 0
			remove_child(activeHitboxes[box])
			activeHitboxes.erase(box)
			break
		for hitPlayer in activeHitboxes[box].get_overlapping_bodies():
			if hitPlayer is fighter:
				hitPlayer.player_hurt(box)
				box.active = false
				box.lifetime = 0
				remove_child(activeHitboxes[box])
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
	
	if curMove != moves["Nothing"] and is_animation_finished():
		curMove = moves["Nothing"]
		anim_state.travel("BlendSpace1D")
		
	if anim_state.get_current_node() == "jump_idle" and is_on_floor() and !sliding:
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
			execute_move("Jump")
			curMove.data = speed * 2
		direction.DOWNLEFT, direction.DOWN, direction.DOWNRIGHT:
			crouch()

func execute_move(move:StringName):
	velocity.x = 0
	curMove = moves[move]
	anim_state.travel(curMove.animationName)
	if anim_state.get_current_node() == curMove.animationName:
		anim_state.start(curMove.animationName)
	actionableTimer = curMove.get_duration()
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
	
	match curInput.inputButton:
		button.NONE:
			if !is_jumping() and curMove == moves["Nothing"] and anim_state.get_current_node() != "jump_land":
				handle_movement(curInput, WALK_SPEED * input_dir.x)
		button.HEAVY_PUNCH:
			if !is_jumping():
				execute_move("Heavy Punch")
		button.LIGHT_PUNCH:
			if !is_jumping():
				execute_move("Light Punch")

# Virtual function for cancelling certain moves into others
func _cancel_move(_curInput:motionInput):
	pass
