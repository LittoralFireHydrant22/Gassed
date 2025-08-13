extends Sprite2D

signal collected(value)  # Optional: emit signal when collected
signal gas_mask_collected  # NEW: Signal specifically for gas mask counter

@export var collection_value: int = 1  # Points, coins, etc.
@onready var area = $Area2D  # Reference to child Area2D

func _ready():
	# Connect the body_entered signal to our collection function
	if area:
		area.body_entered.connect(_on_body_entered)

func _on_body_entered(body):  # Fixed function name
	# Check if the body that entered is the player
	if body.has_method("collect_item") or body.is_in_group("player"):
		collect()

func collect():
	# NEW: Emit the gas mask signal for the counter
	gas_mask_collected.emit()
	
	# Emit signal (useful for updating UI, playing sounds, etc.)
	collected.emit(collection_value)
	
	# Remove the collectible from the scene
	queue_free()
