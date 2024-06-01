extends Label

var fighterName = "../../KillerBean"

@export var player = 1

# Called when the node enters the scene tree for the first time.
func _ready():
	if player == 2:
		fighterName = fighterName + "2"
	var playerNode = get_node(fighterName)
	playerNode.healthSignal.connect(_update_health)
	_update_health(playerNode.health)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func _update_health(healthInt):
	text = "Health: " + str(healthInt)
