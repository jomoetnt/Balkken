extends Label


var fighterName = "../../KillerBean"

var lines:Array[String]

# Called when the node enters the scene tree for the first time.
func _ready():
	get_node(fighterName).inputSignal.connect(_add_input)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("show_inputs"):
		visible = not visible
	
func _add_input(inputString):
	inputString = inputString.replace("NEUTRAL + ", "")
	if inputString == "":
		return
	lines.insert(0, inputString)
	if lines.size() >= 10:
		lines = lines.slice(0, 9, 1, false)
	text = ""
	for line in lines:
		text = text + line + "\n"
