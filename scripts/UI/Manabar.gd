extends Label

var fighterName = "../../KillerBean"
var fighterNode

@export var player = 1

# Called when the node enters the scene tree for the first time.
func _ready():
	if player == 2:
		fighterName = fighterName + "2"
	fighterNode = get_node(fighterName)


# temporary
func _process(_delta):
	text = "curMove: " + str(fighterNode.curMove)
