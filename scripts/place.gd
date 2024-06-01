extends Node3D

signal changeDirSignal
var players

# Called when the node enters the scene tree for the first time.
func _ready():
	players = find_children("*", "fighter", false, true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	update_facing()
			

func update_facing():
	if (players[0].directionFacing == players[0].direction.RIGHT and players[0].position.x > players[1].position.x) or \
	(players[0].directionFacing == players[0].direction.LEFT and players[0].position.x < players[1].position.x):
		changeDirSignal.emit()
