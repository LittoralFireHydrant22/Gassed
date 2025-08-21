# Add this temporarily to your NPC script to debug
extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $IneractionArea
@onready var interaction_prompt: Label = $InteractionPrompt

var is_player_nearby: bool = false

func _ready():
	print("NPC ready!")
	
	# Start animation
	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("mining"):
			animated_sprite.play("mining")
			print("Mining animation started")
		else:
			print("No mining animation found")
	else:
		print("No AnimatedSprite2D found")
	
	# Hide interaction prompt
	if interaction_prompt:
		interaction_prompt.visible = false
		interaction_prompt.text = "[E] to interact"
		print("Interaction prompt set up")
	else:
		print("No interaction prompt found")
	
	# Connect area signals
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_entered)
		interaction_area.body_exited.connect(_on_interaction_area_exited)
		print("Interaction area connected")
	else:
		print("No interaction area found")

func _input(event):
	# Test if the interact action is working at all
	if Input.is_action_just_pressed("interact"):
		print("Interact key pressed! Player nearby: ", is_player_nearby)
		if is_player_nearby:
			print("Interacting with NPC!")

func _on_interaction_area_entered(body):
	print("Something entered interaction area: ", body.name)
	print("Body groups: ", body.get_groups())
	
	if body.is_in_group("player"):
		print("Player detected!")
		is_player_nearby = true
		if interaction_prompt:
			interaction_prompt.visible = true
		print("Should show interaction prompt now")
	else:
		print("Not a player")

func _on_interaction_area_exited(body):
	print("Something left interaction area: ", body.name)
	
	if body.is_in_group("player"):
		print("Player left!")
		is_player_nearby = false
		if interaction_prompt:
			interaction_prompt.visible = false
			
