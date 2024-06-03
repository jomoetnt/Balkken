extends Camera3D

const CAMERA_SPEED = 5.0
const MIN_Z = 2.5
const MAX_Z = 4.5
const EPSILON = 1

var player1:CharacterBody3D
var player2:CharacterBody3D

var aspectRatio:float
var maxDistance:float

var zooming = 0

signal lockMovement()

# Called when the node enters the scene tree for the first time.
func _ready():
	for node in get_parent_node_3d().get_children():
		if node is CharacterBody3D:
			if node.player == 1:
				player1 = node
			else:
				player2 = node
	
	aspectRatio = get_viewport().size.x as float / get_viewport().size.y
	maxDistance = 2 * tan(deg_to_rad(fov / 2)) * MAX_Z * aspectRatio

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if player1 == null or player2 == null:
		return
	var distance = abs(player2.position.x - player1.position.x)
	var targetPos = get_target_position(distance)
		
	if zooming == 0:
		if distance >= maxDistance - EPSILON:
			lockMovement.emit()
		
		# Camera smoothing
		position = position.lerp(targetPos, delta * CAMERA_SPEED)
		
		rotation = Vector3.ZERO
		
		if player1.slowmoTimer > 0:
			zooming = 1
		elif player2.slowmoTimer > 0:
			zooming = 2
	elif zooming == 1:
		zoom(player1)
		if player1.slowmoTimer == 0:
			zooming = 0
			position = get_target_position(distance)
	elif zooming == 2:
		zoom(player2)	
		if player2.slowmoTimer == 0:
			zooming = 0
			position = get_target_position(distance)

func zoom(player):
	var targetPos = Vector3(0, 0, 0)
	var targetRot = Vector3(0, 0, 0)
	targetPos.z = player.position.z + 1.2
	targetPos.y = player.position.y + 0.6
	targetRot.x = deg_to_rad(-20)
	if player.directionFacing == player.direction.RIGHT:
		targetPos.x = player.position.x + 2
		targetRot.y = deg_to_rad(75)
	else:
		targetPos.x = player.position.x - 2
		targetRot.y = deg_to_rad(-75)
	position = targetPos
	rotation = targetRot

func get_target_position(distance):
	var avgHeight = (player1.position.y + player2.position.y) / 2
	var cameraX = (player1.position.x + player2.position.x) / 2
	# Interpolation to range of z values (2 to 5)
	var cameraZ = lerp(MIN_Z, MAX_Z, distance / maxDistance)
	
	var targetPos = Vector3(cameraX, avgHeight, cameraZ)
	return targetPos
