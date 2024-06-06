extends PanelContainer

const HEALTH_VELOCITY = 5.0

var fighterName = "../../KillerBean"

@onready var style:StyleBoxFlat = get("theme_override_styles/panel")
var whichSide = SIDE_LEFT

var maxHealth:int
var targetMargin:float

@export var player = 1

# Called when the node enters the scene tree for the first time.
func _ready():
	if player == 2:
		fighterName = fighterName + "2"
		whichSide = SIDE_RIGHT
	var playerNode = get_node(fighterName)
	playerNode.healthSignal.connect(_update_health)
	maxHealth = playerNode.health
	_update_health(playerNode.health)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	style.set_content_margin(whichSide, lerp(style.get_margin(whichSide), targetMargin, delta * HEALTH_VELOCITY / Engine.time_scale))

func _update_health(healthInt):
	targetMargin = size.x - healthInt * size.x / (maxHealth as float)
