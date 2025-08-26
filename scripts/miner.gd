extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $IneractionArea
@onready var interaction_prompt: Label = $InteractionPrompt
var is_player_nearby: bool = false

func _ready():
	# Start animation
	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("mining"):
			animated_sprite.play("mining")
	
	# Hide interaction prompt
	if interaction_prompt:
		interaction_prompt.visible = false
		interaction_prompt.text = "[E] to interact"
	
	# Connect area signals
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_entered)
		interaction_area.body_exited.connect(_on_interaction_area_exited)

func _input(event):
	if Input.is_action_just_pressed("interact") and is_player_nearby:
		# Add your interaction logic here
		pass

func _on_interaction_area_entered(body):
	if body.is_in_group("player"):
		is_player_nearby = true
		if interaction_prompt:
			interaction_prompt.visible = true

func _on_interaction_area_exited(body):
	if body.is_in_group("player"):
		is_player_nearby = false
		if interaction_prompt:
			interaction_prompt.visible = false
