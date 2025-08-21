# Method 1: Using Marker2D nodes (recommended)
# GasMaskSpawner.gd
extends Node2D

@export var gas_mask_scene: PackedScene  # Drag your gas mask scene here
@export var spawn_points: Array[Marker2D] = []  # Drag spawn point markers here
@export var max_gas_masks: int = 3  # How many gas masks to spawn at once

var active_gas_masks: Array = []

func _ready():
	spawn_gas_masks()

func spawn_gas_masks():
	print("Starting to spawn gas masks...")
	print("Gas mask scene: ", gas_mask_scene)
	print("Spawn points count: ", spawn_points.size())
	print("Max gas masks: ", max_gas_masks)
	
	# Clear any existing gas masks
	clear_gas_masks()
	
	# Check if we have everything we need
	if not gas_mask_scene:
		print("ERROR: No gas mask scene assigned!")
		return
	
	if spawn_points.is_empty():
		print("ERROR: No spawn points assigned!")
		return
	
	# Get random spawn points
	var available_points = spawn_points.duplicate()
	available_points.shuffle()
	
	# Spawn gas masks up to max_gas_masks or available points
	var spawn_count = min(max_gas_masks, available_points.size())
	print("Will spawn ", spawn_count, " gas masks")
	
	for i in range(spawn_count):
		var spawn_point = available_points[i]
		print("Spawning at position: ", spawn_point.global_position)
		
		var gas_mask = gas_mask_scene.instantiate()
		print("Gas mask created, initial position: ", gas_mask.position)
		
		# Add to scene FIRST, then position
		get_parent().add_child(gas_mask)
		
		# Try setting position directly instead of global_position
		gas_mask.position = Vector2(200, 200)  # Fixed position for testing
		print("Gas mask position after setting to (200,200): ", gas_mask.position)
		print("Gas mask global_position: ", gas_mask.global_position)
		
		# Connect to the collected signal to track when it's picked up
		if gas_mask.has_signal("gas_mask_collected"):
			gas_mask.gas_mask_collected.connect(_on_gas_mask_collected)
		else:
			print("WARNING: Gas mask doesn't have gas_mask_collected signal!")
		
		print("Gas mask final position: ", gas_mask.global_position)
		print("Gas mask visible: ", gas_mask.visible)
		print("Gas mask scale: ", gas_mask.scale)
		active_gas_masks.append(gas_mask)
		print("Gas mask spawned successfully!")

# Method 2: Using Vector2 positions (alternative approach)
# Uncomment and use this version if you prefer code-based positions:

# @export var gas_mask_scene: PackedScene
# @export var spawn_positions: Array[Vector2] = [
# 	Vector2(100, 200),
# 	Vector2(300, 150), 
# 	Vector2(500, 400),
# 	Vector2(200, 600),
# 	Vector2(700, 300)
# ]
# @export var max_gas_masks: int = 3

# func spawn_gas_masks():
# 	clear_gas_masks()
# 	
# 	var available_positions = spawn_positions.duplicate()
# 	available_positions.shuffle()
# 	
# 	var spawn_count = min(max_gas_masks, available_positions.size())
# 	
# 	for i in range(spawn_count):
# 		var gas_mask = gas_mask_scene.instantiate()
# 		gas_mask.global_position = available_positions[i]
# 		gas_mask.gas_mask_collected.connect(_on_gas_mask_collected)
# 		get_parent().add_child(gas_mask)
# 		active_gas_masks.append(gas_mask)

func _on_gas_mask_collected():
	# Remove from tracking (the gas mask will queue_free itself)
	active_gas_masks = active_gas_masks.filter(func(mask): return is_instance_valid(mask))
	
	# Optional: Respawn after a delay
	# get_tree().create_timer(5.0).timeout.connect(spawn_gas_masks)

func clear_gas_masks():
	for gas_mask in active_gas_masks:
		if is_instance_valid(gas_mask):
			gas_mask.queue_free()
	active_gas_masks.clear()

# Call this if you want to respawn gas masks
func respawn_gas_masks():
	spawn_gas_masks()
