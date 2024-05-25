extends Label


var fighterName = "../../KillerBean"

# Called when the node enters the scene tree for the first time.
func _ready():
	get_node(fighterName).inputSignal.connect(_add_input)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func _add_input(inputString):
	inputString = inputString.replace("NEUTRAL + ", "")
	if inputString == "":
		return
	text = inputString + "\n" + text
