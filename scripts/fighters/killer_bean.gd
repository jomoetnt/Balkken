class_name KillerBeanFighter extends "fighter.gd"


func _ready():
	CHARACTER_FILE = "res://data/killer_bean.json"
	super._ready()
	moves["cry"].soundEffect = "cryman.ogg"
