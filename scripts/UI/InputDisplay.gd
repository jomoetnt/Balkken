extends Label


var fighterName = "../../KillerBean"
var fighterNode

@export var player = 1

var lines:Array[String]

# Called when the node enters the scene tree for the first time.
func _ready():
	if player == 2:
		fighterName = fighterName + "2"
	fighterNode = get_node(fighterName)
	fighterNode.inputSignal.connect(_add_input)
	text = ""

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("show_inputs"):
		visible = not visible
	
func _add_input(inputString, flags):
	inputString = inputString.replace("NEUTRAL + NONE", "")
	inputString = inputString.replace("NEUTRAL + ", "")
	inputString = inputString.replace(" + NONE", "")
	
	if inputString == "":
		return
		
	if fighterNode.inputFlag.CANCELLED in flags:
		inputString = inputString + " (cancelled)"
	if fighterNode.inputFlag.BUFFERED in flags:
		inputString = inputString + " (buffered)"
	if fighterNode.inputFlag.DROPPED in flags:
		inputString = inputString + " (dropped)"
	
	lines.insert(0, inputString)
	if lines.size() >= 10:
		lines = lines.slice(0, 9, 1, false)
	text = ""
	for line in lines:
		text = text + line + "\n"
