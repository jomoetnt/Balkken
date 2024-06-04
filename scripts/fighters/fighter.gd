class_name fighter extends CharacterBody3D

# System constants (yes I know 'const' exists)
var SLOWMO_THRESHOLD = 1.0
var SLOWMO_TIMESCALE = 0.1
var SLOWMO_LENGTH_MULTIPLIER = 10
var INPUT_THRESHOLD = 0.5
var INPUT_BUFFER_SIZE = 7
var AUDIO_PATH = "res://assets/audio/"

# Universal character constants
var SLIDE_VELOCITY = 3
var EPSILON = 0.1
var MAX_MANA = 10
var CROUCH_DAMAGE = 1.5

# Character specific constants - stringify
var WALK_SPEED = 2.0
var JUMP_VELOCITY = 6.0
var JUMP_HORIZONTAL_SPEED = 2
var PREJUMP_FRAMES = 5
var LAND_FRAMES = 4
var MAX_HEALTH = 500
var FIGHTER_NAME = "jeff"
var CHARACTER_FILE:String

var health = MAX_HEALTH
var mana = 0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var animation_tree = $AnimationTree
@onready var anim_state = $AnimationTree.get("parameters/playback")
@onready var anim_player = $AnimationPlayer
@onready var audio_player:AudioStreamPlayer = self.get_parent().get_node("AudioStreamPlayer")

# filename: start timestamp
var sounds = {
	"pipe.ogg": 0.35,
	"Alarm.ogg": 0.26,
	"aneurysm.ogg": 0.08,
	"boowomp.ogg": 0.53,
	"cryman.ogg": 0.21,
	"help.ogg": 6.53,
	"lolxd.ogg": 0.3,
	"protip.ogg": 0,
	"prowler.ogg": 0,
	"Running.ogg": 0.22,
	"TikTok snoring.ogg": 0.18,
	"Vine Boom.ogg": 0.21,
	"Waterphone.ogg": 0.42,
}

var actionable = true
var actionableTimer = 0

var slidingDirection = direction.NEUTRAL

var slowmoTimer = 0

var hurtboxNode:CollisionShape3D

@export var player = 1
var otherPlayer:fighter

# StringName: commandMove
var moves:Dictionary

var hurtboxes = {}

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

# stringify later
# Array[motionInput]: Array[commandMove]
var motionMap = {}

# hitbox: Area3D
var activeHitboxes = {}

enum direction {UP, DOWN, LEFT, RIGHT, UPLEFT, UPRIGHT, DOWNLEFT, DOWNRIGHT, NEUTRAL}
enum button {LIGHT_PUNCH, LIGHT_KICK, HEAVY_PUNCH, HEAVY_KICK, ENHANCE, THROW, THROW_SWAP, ULTIMATE_IGNITE, START, READY, NONE}
enum inputFlag {CANCELLED, BUFFERED, DROPPED, BUFFERED_ACTIVATE}

var curDir = direction.NEUTRAL
var curBtn = button.NONE
var curMove:commandMove

var directionFacing:direction
var movementLocked = false

var inputBuffer:Array[motionInput]

var blocking = false
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
	func budget_stringify(numIndents):
		var text = hitbox.print_property("direction", direction.keys()[inputDirection], true, numIndents)
		text = text + hitbox.print_property("button", button.keys()[inputButton], false, numIndents)
		text = "\t".repeat(numIndents) + hitbox.create_section(text, numIndents)
		return text
		
class commandMove:
	enum state {STANDING, JUMPING}
	var commandInputs = []
	var startupFrames:int
	var activeFrames:int
	var recoveryFrames:int
	# Moves that can be cancelled into from this move.
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
	func budget_stringify(numIndents):
		var text = hitbox.print_property("name", str(moveName), true, numIndents)
		text = text + stringify_inputs(numIndents + 1) + ",\n"
		text = text + hitbox.print_property("state", state.keys()[moveState], true, numIndents)
		text = text + hitbox.print_property("startup", str(startupFrames), true, numIndents)
		text = text + hitbox.print_property("active", str(activeFrames), true, numIndents)
		text = text + hitbox.print_property("recovery", str(recoveryFrames), true, numIndents)
		text = text + "\t".repeat(numIndents + 1) + "\"cancellableInto\": " + str(cancelMoves) + ",\n"
		text = text + hitbox.print_property("animationName", str(animationName), true, numIndents)
		text = text + commandMove.stringify_hitboxes("hitboxes", numIndents, hitboxes)
		text = "\t".repeat(numIndents) + hitbox.create_section(text, numIndents)
		return text
	static func stringify_hitboxes(label, numIndents, list):
		var text = ""
		for box in list:
			# I want to remove the trailing commas at some point
			text = text + box.budget_stringify(numIndents + 2)
			
			if box != list.keys()[-1]:
				text = text + ","
			text = text + "\n"
			
		text = "\t".repeat(numIndents + 1) + "\"" + label + "\": " + commandMove.create_array(text, numIndents + 1)
		return text
	func stringify_inputs(numIndents):
		var text = ""
		for input in commandInputs:
			text = text + input.budget_stringify(numIndents + 1)
			
			if input != commandInputs[-1]:
				text = text + ","
			text = text + "\n"
		
		text = "\t".repeat(numIndents) + "\"inputs\": " + commandMove.create_array(text, numIndents)
		return text
	static func create_array(text, numIndents):
		text = "[\n" + text + "\t".repeat(numIndents) + "]"
		return text

class hitbox:
	var size:Vector3
	var location:Vector3
	var lifetime = 0
	var lifespan:int
	var firstActiveFrame:int
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
	# E.g. paralysis. Currently unused but reserved.
	var effects
	func _init(hitSize:Vector3, hitLocation:Vector3, hitLifespan:int):
		size = hitSize
		location = hitLocation
		lifespan = hitLifespan
	# numIndents is the amount of tabs the entire object will be shifted, so properties inside will still be indented by one more tab.
	func budget_stringify(numIndents):
		var text = ""
		text = text + hitbox.print_property("lifespan", str(lifespan), true, numIndents)
		text = text + hitbox.print_property("firstActiveFrame", str(lifespan), true, numIndents)
		text = text + hitbox.print_property("damage", str(damage), true, numIndents)
		text = text + hitbox.print_property("chipDamage", str(chipDamage), true, numIndents)
		text = text + hitbox.print_property("hitlag", str(hitlag), true, numIndents)
		text = text + hitbox.print_property("hitstun", str(hitstun), true, numIndents)
		text = text + hitbox.print_property("blockstun", str(blockstun), true, numIndents)
		text = text + hitbox.print_property("knockback", str(knockback), true, numIndents)
		text = text + hitbox.print_property("size", str(size), true, numIndents)
		text = text + hitbox.print_property("location", str(location), true, numIndents)
		text = text + hitbox.print_property("blockKnockback", str(blockKnockback), false, numIndents)
		text = "\t".repeat(numIndents) + hitbox.create_section(text, numIndents)
		return text
	static func create_section(text, numIndents):
		text = "{\n" + text + "\n" + "\t".repeat(numIndents) + "}"
		return text
	static func print_property(property:String, value:String, comma:bool, numIndents):
		var text = "\t".repeat(numIndents + 1) + "\"" + property + "\": \"" + value + "\""
		if comma:
			text = text + ",\n"
		return text
	
func _ready():
	get_node("../Camera3D").lockMovement.connect(_lock_movement)
	get_parent().changeDirSignal.connect(_change_direction)
	
	hurtboxNode = CollisionShape3D.new()
	add_child(hurtboxNode)
	
	if player == 1:
		directionFacing = direction.RIGHT
	else:
		directionFacing = direction.LEFT
	
	var characterData = JSON.parse_string(read_from_file(CHARACTER_FILE))
	load_character(characterData)
	
	healthSignal.emit(health)
	
	map_motion_move()
	
	curMove = moves["Nothing"]
	update_hurtbox("Standing")
	
func map_motion_move():
	for moveName in moves:
		var move = moves[moveName]
		if motionMap.has(move.commandInputs):
			motionMap[move.commandInputs].append(move)
		else:
			motionMap[move.commandInputs] = [move]

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	update_state()
	
	#if sliding or otherPlayer.sliding:
		#if abs(position.x - otherPlayer.position.x) > hurtboxNode.shape.size.x + EPSILON:
			#sliding = false
			#otherPlayer.sliding = false
			#velocity.x = 0
			#otherPlayer.velocity.x = 0
	
	move_and_slide()
		#for i in get_slide_collision_count():
			#var collision = get_slide_collision(i)
			#for j in collision.get_collision_count():
				#var collider = collision.get_collider(j)
				#if collider == otherPlayer and player == 1:
					#velocity.x = SLIDE_VELOCITY * scale.x
					#otherPlayer.velocity.x = otherPlayer.SLIDE_VELOCITY * otherPlayer.scale.x
					#if position.y > otherPlayer.position.y + EPSILON:
						#position.y = otherPlayer.position.y + otherPlayer.hurtboxNode.shape.size.y
					#elif otherPlayer.position.y > position.y + EPSILON:
						#otherPlayer.position.y = position.y + hurtboxNode.shape.size.y
					#sliding = true

func play_sound(audioName):
	audio_player.stream = AudioStreamOggVorbis.load_from_file(AUDIO_PATH + audioName)
	audio_player.play(sounds[audioName])

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
		play_sound("Vine Boom.ogg")
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
		play_sound("TikTok snoring.ogg")
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
		play_sound("help.ogg")
		if length > SLOWMO_THRESHOLD:
			Engine.time_scale = SLOWMO_TIMESCALE
			slowmoTimer = round(length) * SLOWMO_LENGTH_MULTIPLIER
		
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
	
	# This is how you erase dictionary entries without undefined behaviour in GDScript apparently.
	for i in range(activeHitboxes.keys().size() - 1, -1, -1):
		var box = activeHitboxes.keys()[i]
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
	
	if anim_state.get_current_node() == "block_standing" and actionable:
		anim_state.travel("BlendSpace1D")
	
	if anim_state.get_current_node() == "block_crouching" and actionable:
		anim_state.travel("BlendSpace1D")
	
	if curMove != moves["Nothing"] and is_animation_finished():
		curMove = moves["Nothing"]
		anim_state.travel("BlendSpace1D")
		
	if anim_state.get_current_node() == "jump_idle" and is_on_floor():
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
	play_sound("aneurysm.ogg")
	
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
			if anim_state.get_current_node() != "jump_land":
				walk(0)
		direction.RIGHT, direction.LEFT:
			walk(speed)
		direction.UPLEFT, direction.UP, direction.UPRIGHT:
			velocity.x = 0
			anim_state.travel("jump")
			actionable = false
			actionableTimer = PREJUMP_FRAMES
			curMove.data = speed * JUMP_HORIZONTAL_SPEED
			play_sound("pipe.ogg")
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
	
	if input_dir.x > INPUT_THRESHOLD:
		if input_dir.y < -INPUT_THRESHOLD:
			curDir = direction.DOWNRIGHT
		elif input_dir.y > INPUT_THRESHOLD:
			curDir = direction.UPRIGHT
		else:
			curDir = direction.RIGHT
	elif input_dir.x < -INPUT_THRESHOLD:
		if input_dir.y < -INPUT_THRESHOLD:
			curDir = direction.DOWNLEFT
		elif input_dir.y > INPUT_THRESHOLD:
			curDir = direction.UPLEFT
		else:
			curDir = direction.LEFT
	else:
		if input_dir.y < -INPUT_THRESHOLD:
			curDir = direction.DOWN
		elif input_dir.y > INPUT_THRESHOLD:
			curDir = direction.UP
		else:
			curDir = direction.NEUTRAL
	
	# This is how you erase elements of an array without undefined behaviour in GDScript apparently.
	for i in range(inputBuffer.size() - 1, -1, -1):
		var input = inputBuffer[i]
		if input.lifetime >= INPUT_BUFFER_SIZE:
			inputBuffer.erase(input)
		input.lifetime += 1
	
	if curInput.inputButton == button.NONE and bufInput.inputButton != button.NONE:
		curInput = bufInput
		curFlags.append(inputFlag.BUFFERED_ACTIVATE)
		inputBuffer.clear()
	
	if !is_jumping() and curMove == moves["Nothing"] and curInput.inputButton == button.NONE and actionable:
		handle_movement(curInput, WALK_SPEED * input_dir.x)
	else:
		var curMotion = inputBuffer.duplicate(true)
		curMotion.append(curInput)
		
		var potentialMoves = []
		for motion in motionMap:
			if are_same_motions(curMotion, motion) and motion in motionMap:
				potentialMoves.append_array(motionMap[motion])
		if is_jumping():
			for move in potentialMoves:
				if move.moveState == move.state.JUMPING:
					execute_move(move)
					break
		else:
			for move in potentialMoves:
				if move.moveState == move.state.STANDING:
					if !actionable:
						if move.moveName in curMove.cancelMoves:
							actionable = true
							actionableTimer = 0
							execute_move(move)
							curFlags.append(inputFlag.CANCELLED)
						else:
							if actionableTimer <= INPUT_BUFFER_SIZE:
								curFlags.append(inputFlag.BUFFERED)
							else:
								curFlags.append(inputFlag.DROPPED)
						inputBuffer.append(curInput)
						inputSignal.emit(str(curInput), curFlags)
						return
					execute_move(move)
					break
	if curFlags != [inputFlag.BUFFERED_ACTIVATE]:
		inputSignal.emit(str(curInput), curFlags)

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

func save_character():
	write_to_file(CHARACTER_FILE, budget_stringify(0))

func budget_stringify(numIndents):
	var text = hitbox.print_property("characterName", str(FIGHTER_NAME), true, numIndents)
	text = text + hitbox.print_property("maxHealth", str(MAX_HEALTH), true, numIndents)
	text = text + hitbox.print_property("walkSpeed", str(WALK_SPEED), true, numIndents)
	text = text + hitbox.print_property("jumpSpeedVertical", str(JUMP_VELOCITY), true, numIndents)
	text = text + hitbox.print_property("jumpSpeedHorizontal", str(JUMP_HORIZONTAL_SPEED), true, numIndents)
	text = text + hitbox.print_property("prejump", str(PREJUMP_FRAMES), true, numIndents)
	text = text + hitbox.print_property("landing", str(LAND_FRAMES), true, numIndents)
	text = text + "\t".repeat(numIndents + 1) + "\"hurtboxes\": " + stringify_hurtboxes(numIndents + 1) + ",\n"
	text = text + stringify_moves(numIndents)
	return hitbox.create_section(text, numIndents)

func stringify_hurtboxes(numIndents):
	var text = ""
	
	for hurtbox in hurtboxes:
		var curText = ""
		curText = curText + hitbox.print_property("state", hurtbox, true, numIndents)
		curText = curText + hitbox.print_property("size", str(hurtboxes[hurtbox].size), true, numIndents)
		curText = curText + hitbox.print_property("location", str(hurtboxes[hurtbox].location), false, numIndents)
		text = text + "\t".repeat(numIndents + 1) + hitbox.create_section(curText, numIndents + 1)
		if hurtbox != hurtboxes.keys()[-1]:
			text = text + ","
		text = text + "\n"
	
	text = commandMove.create_array(text, numIndents)
	
	return text

func stringify_moves(numIndents):
	var text = ""
	for move in moves:
		text = text + moves[move].budget_stringify(numIndents + 2)
		if move != moves.keys()[-1]:
			text = text + ","
		text = text + "\n"
	
	text = "\t".repeat(numIndents + 1) + "\"moves\": " + commandMove.create_array(text, numIndents + 1)
	return text

func load_character(data):
	FIGHTER_NAME = data["characterName"]
	MAX_HEALTH = int(data["maxHealth"])
	WALK_SPEED = float(data["walkSpeed"])
	JUMP_VELOCITY = float(data["jumpSpeedVertical"])
	JUMP_HORIZONTAL_SPEED = float(data["jumpSpeedHorizontal"])
	PREJUMP_FRAMES = int(data["prejump"])
	LAND_FRAMES = int(data["landing"])
	hurtboxes = load_hurtboxes(data["hurtboxes"])
	moves = load_moves(data["moves"])

func load_hurtboxes(hurtboxData):
	var parsedHurtboxes = {}
	for loadedHurtbox in hurtboxData:
		var parsedSize = parse_vector(loadedHurtbox["size"])
		var parsedLocation = parse_vector(loadedHurtbox["location"])
		var parsedHurtbox = hitbox.new(parsedSize, parsedLocation, 0)
		
		parsedHurtboxes[loadedHurtbox["state"]] = parsedHurtbox
	return parsedHurtboxes

func load_moves(moveData):
	var parsedMoves = {}
	for loadedMove in moveData:
		var parsedMove = commandMove.new(int(loadedMove["startup"]), int(loadedMove["active"]), int(loadedMove["recovery"]), \
			loadedMove["animationName"], loadedMove["name"])
		parsedMove.moveState = loadedMove["state"]
		parsedMove.commandInputs = load_inputs(loadedMove["inputs"])
		parsedMove.cancelMoves = loadedMove["cancellableInto"]
		parsedMove.animationName = loadedMove["animationName"]
		parsedMove.hitboxes = load_hitboxes(loadedMove["hitboxes"])
		parsedMoves[parsedMove.moveName] = parsedMove
	return parsedMoves

func load_inputs(inputData):
	var parsedInputs = []
	for loadedInput in inputData:
		# Named enums in godot are constant dictionaries
		var parsedInput = motionInput.new(direction[loadedInput["direction"]], button[loadedInput["button"]])
		parsedInputs.append(parsedInput)
	return parsedInputs

func load_hitboxes(hitboxData):
	var parsedHitboxes = {}
	for loadedHitbox in hitboxData:
		var parsedSize = parse_vector(loadedHitbox["size"])
		var parsedLocation = parse_vector(loadedHitbox["location"])
		var parsedHitbox = hitbox.new(parsedSize, parsedLocation, int(loadedHitbox["lifespan"]))
		
		parsedHitbox.damage = int(loadedHitbox["damage"])
		parsedHitbox.chipDamage = int(loadedHitbox["chipDamage"])
		parsedHitbox.hitlag = int(loadedHitbox["hitlag"])
		parsedHitbox.hitstun = int(loadedHitbox["hitstun"])
		parsedHitbox.blockstun = int(loadedHitbox["blockstun"])
		
		var parsedKnockback = parse_vector(loadedHitbox["knockback"])
		var parsedBlockKnockback = parse_vector(loadedHitbox["blockKnockback"])
		
		parsedHitbox.knockback = parsedKnockback
		parsedHitbox.blockKnockback = parsedBlockKnockback
		
		parsedHitboxes[parsedHitbox] = int(loadedHitbox["firstActiveFrame"])
	return parsedHitboxes

func parse_vector(string):
	var vecString = String(string)
	vecString = vecString.replace("(", "")
	vecString = vecString.replace(")", "")
	vecString = vecString.replace(" ", "")
	var stringArr = vecString.split(",")
	var floatArr = []
	for stringle in stringArr:
		floatArr.append(float(stringle))
	if floatArr.size() == 2:
		return Vector2(floatArr[0], floatArr[1])
	else:
		return Vector3(floatArr[0], floatArr[1], floatArr[2])

func write_to_file(path:String, content:String):
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)

func read_from_file(path:String):
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	return content
