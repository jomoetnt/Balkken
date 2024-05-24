extends CharacterBody3D


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
	else:
		input_dir = Input.get_vector("p2_left", "p2_right", "p2_down", "p2_up")
	
	# Handle 
	if input_dir.x > 0:
		if input_dir.y == 0:
			curDir = dirList.RIGHT
		elif input_dir.y > 0:
			curDir = dirList.UPRIGHT
		else:
			curDir = dirList.DOWNRIGHT
	elif input_dir.x < 0:
		if input_dir.y == 0:
			curDir = dirList.LEFT
		elif input_dir.y > 0:
			curDir = dirList.UPLEFT
		else:
			curDir = dirList.DOWNLEFT
	else:
		if input_dir.y == 0:
			curDir = dirList.NEUTRAL
		elif input_dir.y > 0:
			curDir = dirList.UP
		else:
			curDir = dirList.DOWN
	
	process_input(curDir, SPEED * input_dir.x)

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
	anim_state.travel("crouch")
	
func walk(speed):
	anim_state.travel("BlendSpace1D")
	velocity.x = speed
	if player == 1:
		animation_tree.set("parameters/BlendSpace1D/blend_position", speed / SPEED)
	else:
		animation_tree.set("parameters/BlendSpace1D/blend_position", -speed / SPEED)

func process_input(dir:dirList, speed):
	match dir:
		dirList.UP:
			if anim_state.get_current_node() == "jump_idle" || anim_state.get_current_node() == "jump" || anim_state.get_current_node() == "jump_land":
				return
			jump()
		dirList.UPRIGHT:
			if anim_state.get_current_node() == "jump_idle" || anim_state.get_current_node() == "jump" || anim_state.get_current_node() == "jump_land":
				return
			velocity.x = speed * 2
			jump()
		dirList.UPLEFT:
			if anim_state.get_current_node() == "jump_idle" || anim_state.get_current_node() == "jump" || anim_state.get_current_node() == "jump_land":
				return
			velocity.x = speed * 2
			jump()
		dirList.DOWN:
			crouch()
		dirList.DOWNLEFT:
			crouch()
		dirList.DOWNRIGHT:
			crouch()
		dirList.LEFT:
			if anim_state.get_current_node() == "jump_idle" || anim_state.get_current_node() == "jump" || anim_state.get_current_node() == "jump_land":
				return
			walk(speed)
		dirList.RIGHT:
			if anim_state.get_current_node() == "jump_idle" || anim_state.get_current_node() == "jump" || anim_state.get_current_node() == "jump_land":
				return
			walk(speed)
		dirList.NEUTRAL:
			if anim_state.get_current_node() == "jump_idle" || anim_state.get_current_node() == "jump" || anim_state.get_current_node() == "jump_land":
				return
			walk(0)
