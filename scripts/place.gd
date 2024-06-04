extends Node3D

const SLIDE_VELOCITY = 3.0
const EPSILON = 0.3

signal changeDirSignal
var players:Array

# Called when the node enters the scene tree for the first time.
func _ready():
	players = find_children("*", "fighter", false, true)
	players[0].otherPlayer = players[1]
	players[1].otherPlayer = players[0]

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	update_facing()
	if players[0].slidingDirection != players[0].direction.NEUTRAL or players[1].slidingDirection != players[1].direction.NEUTRAL:
		return
	if (players[0].is_on_floor() and players[0].position.y > players[1].position.y + EPSILON) or (players[1].is_on_floor() and players[1].position.y > players[0].position.y + EPSILON):
		if players[0].position.x > players[1].position.x:
			players[0].slidingDirection = players[0].direction.RIGHT
			players[1].slidingDirection = players[1].direction.LEFT
		else:
			players[0].slidingDirection = players[0].direction.LEFT
			players[1].slidingDirection = players[1].direction.RIGHT

func update_facing():
	if (players[0].directionFacing == players[0].direction.RIGHT and players[0].position.x > players[1].position.x + players[1].hurtboxNode.shape.size.x) or \
	(players[0].directionFacing == players[0].direction.LEFT and players[0].position.x + players[0].hurtboxNode.shape.size.x < players[1].position.x):
		changeDirSignal.emit()
