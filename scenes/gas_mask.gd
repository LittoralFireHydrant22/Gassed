extends Sprite2D

signal collected(value)  # Optional: emit signal when collected

@export var collection_value: int = 1  # Points, coins, etc.
@onready var area = $Area2D  # Reference to child Area2D

func _ready():
	# Connect the body_entered signal to our collection function
	area.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Check if the body that entered is the player
	if body.has_method("collect_item") or body.is_in_group("player"):
		collect()

func collect():
	# Emit signal (useful for updating UI, playing sounds, etc.)
	collected.emit(collection_value)
	
	# Optional: Add collection effect
	print("Item collected!")
	
	# Remove the collectible from the scene
	queue_free()
