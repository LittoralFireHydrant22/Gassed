extends Node2D

# Get reference to the AnimationPlayer
@onready var animation_player = $exclamation

func _ready():
	# Play a specific animation by name
	animation_player.play("default")
