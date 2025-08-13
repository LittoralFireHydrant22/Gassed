extends Sprite2D

signal collected(value)  # Optional: emit signal when collected
@export var collection_value: int = 1  # Points, coins, etc.
@onready var area = $Area2D  # Reference to child Area2D

func _ready():
	print("Collectible ready - connecting signals")
	# Connect the body_entered signal to our collection function
	if area:
		area.body_entered.connect(_on_body_entered)
		print("Signal connected successfully")
	else:
		print("ERROR: Area2D child not found!")

func _on_body_entered(body):  # Fixed function name (was *on*body_entered)
	print("Body entered area:", body.name, "Groups:", body.get_groups())
	# Check if the body that entered is the player
	if body.has_method("collect_item") or body.is_in_group("player"):
		print("Player detected - collecting item")
		collect()
	else:
		print("Not a player - body groups:", body.get_groups())

func collect():
	# Emit signal (useful for updating UI, playing sounds, etc.)
	collected.emit(collection_value)
	
	# Optional: Add collection effect
	print("Item collected! Value:", collection_value)
	
	# Remove the collectible from the scene
	queue_free()
