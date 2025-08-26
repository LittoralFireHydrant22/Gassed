# Gas Mask Spawner - attach to a Node in your main scene
extends Node

# Maximum number of gas masks on the map at once
const MAX_GAS_MASKS: int = 3

# Keep track of active gas masks and markers
var active_gas_masks: Array[Node] = []
var spawn_markers: Array[Marker2D] = []
var available_markers: Array[Marker2D] = []

# Path to your gas mask scene - UPDATE THIS PATH!
const GAS_MASK_SCENE_PATH = "res://scenes/gas_mask.tscn"

func _ready():
	# Find all gas mask spawn markers in the scene
	find_spawn_markers()
	
	if spawn_markers.is_empty():
		print("No gas mask spawn markers found!")
		print("To fix this:")
		print("1. Add Marker2D nodes to your scene where you want gas masks to spawn")
		print("2. Either name them with 'GasMask' in the name, or")
		print("3. Add them to the 'gas_mask_spawns' group in the editor")
		return
	
	# Debug: Print all marker positions
	print("Found ", spawn_markers.size(), " spawn markers:")
	for i in range(spawn_markers.size()):
		print("  Marker ", i, ": ", spawn_markers[i].name, " at ", spawn_markers[i].global_position)
	
	# Initialize available markers
	available_markers = spawn_markers.duplicate()
	
	# Spawn initial gas masks
	for i in range(MAX_GAS_MASKS):
		spawn_gas_mask()
	
	print("Gas mask spawner ready with ", spawn_markers.size(), " spawn points!")

func find_spawn_markers():
	spawn_markers.clear()
	
	# Method 1: Find markers by group name (RECOMMENDED)
	var group_nodes = get_tree().get_nodes_in_group("gas_mask_spawns")
	for node in group_nodes:
		if node is Marker2D:
			spawn_markers.append(node)
			print("Found marker in group: ", node.name)
	
	# Method 2: If no group markers found, search by name pattern
	if spawn_markers.is_empty():
		print("No markers found in 'gas_mask_spawns' group. Searching by name...")
		find_markers_by_name_pattern()
	
	# Method 3: If still no markers, find ALL Marker2D nodes
	if spawn_markers.is_empty():
		print("No named markers found. Using all Marker2D nodes...")
		find_all_marker2d_nodes()

func find_markers_by_name_pattern():
	# Look for Marker2D nodes with specific names
	var name_patterns = ["GasMask", "gasmask", "gas_mask", "GasSpawn", "spawn"]
	
	var all_nodes = get_all_nodes_recursive(get_tree().current_scene)
	for node in all_nodes:
		if node is Marker2D:
			for pattern in name_patterns:
				if pattern.to_lower() in node.name.to_lower():
					spawn_markers.append(node)
					print("Found marker by name: ", node.name)
					break

func find_all_marker2d_nodes():
	# As fallback, use ALL Marker2D nodes in the scene
	var all_nodes = get_all_nodes_recursive(get_tree().current_scene)
	for node in all_nodes:
		if node is Marker2D:
			spawn_markers.append(node)
			print("Found Marker2D: ", node.name)

func get_all_nodes_recursive(node: Node) -> Array:
	var nodes = [node]
	for child in node.get_children():
		nodes.append_array(get_all_nodes_recursive(child))
	return nodes

func spawn_gas_mask():
	# Don't spawn if we're at the limit or no markers available
	if active_gas_masks.size() >= MAX_GAS_MASKS or available_markers.is_empty():
		print("Cannot spawn gas mask. Active: ", active_gas_masks.size(), "/", MAX_GAS_MASKS, " Available markers: ", available_markers.size())
		return
	
	# Pick a random available marker
	var random_index = randi() % available_markers.size()
	var spawn_marker = available_markers[random_index]
	
	print("Spawning gas mask at marker: ", spawn_marker.name, " position: ", spawn_marker.global_position)
	
	# Remove marker from available list
	available_markers.remove_at(random_index)
	
	# Load and spawn your gas mask scene
	var gas_mask_scene = load(GAS_MASK_SCENE_PATH)
	
	# Check if scene loaded successfully
	if gas_mask_scene == null:
		print("ERROR: Could not load gas mask scene from path: ", GAS_MASK_SCENE_PATH)
		print("Make sure:")
		print("1. The path is correct")
		print("2. The gas_mask.tscn file exists in res://scenes/")
		print("3. The scene file is not corrupted")
		available_markers.append(spawn_marker)  # Put marker back in available list
		return
	
	var gas_mask = gas_mask_scene.instantiate()
	
	# Add to scene tree first
	get_tree().current_scene.add_child(gas_mask)
	
	# Set position after adding to tree
	gas_mask.global_position = spawn_marker.global_position
	
	# Ensure visibility
	gas_mask.visible = true
	gas_mask.modulate = Color.WHITE
	
	# Set z_index if it's a Node2D
	if gas_mask is Node2D:
		gas_mask.z_index = 10
	
	print("Gas mask spawned successfully at: ", gas_mask.global_position)
	
	# Track the gas mask
	active_gas_masks.append(gas_mask)
	
	# Try to connect to pickup signals (try common signal names)
	var connected = false
	var signal_names = ["gas_mask_collected", "collected", "picked_up", "pickup", "body_entered"]
	
	for signal_name in signal_names:
		if gas_mask.has_signal(signal_name):
			gas_mask.connect(signal_name, _on_gas_mask_picked_up.bind(gas_mask, spawn_marker))
			print("Connected to signal: ", signal_name)
			connected = true
			break
	
	if not connected:
		print("Warning: No pickup signal found on gas mask. Available signals:")
		for signal_info in gas_mask.get_signal_list():
			print("  - ", signal_info.name)

func _on_gas_mask_picked_up(gas_mask, original_marker):
	print("Gas mask picked up at: ", gas_mask.global_position)
	
	# Remove from tracking
	if gas_mask in active_gas_masks:
		active_gas_masks.erase(gas_mask)
	
	# Make the marker available again
	if original_marker not in available_markers:
		available_markers.append(original_marker)
	
	# Spawn a new gas mask after a delay
	await get_tree().create_timer(2.0).timeout
	spawn_gas_mask()

# Debug functions you can call from other scripts or debugger
func debug_show_markers():
	print("=== SPAWN MARKERS DEBUG ===")
	print("Total markers: ", spawn_markers.size())
	print("Available markers: ", available_markers.size())
	for i in range(spawn_markers.size()):
		var marker = spawn_markers[i]
		print("Marker ", i, ": ", marker.name, " at ", marker.global_position)
		print("  Available: ", marker in available_markers)

func debug_show_active_masks():
	print("=== ACTIVE GAS MASKS DEBUG ===")
	print("Active gas masks: ", active_gas_masks.size())
	for i in range(active_gas_masks.size()):
		var mask = active_gas_masks[i]
		print("Mask ", i, ": ", mask.name, " at ", mask.global_position)

func force_spawn():
	print("Force spawning gas mask...")
	spawn_gas_mask()

# Call this to respawn all gas masks
func respawn_all():
	# Clear existing
	for mask in active_gas_masks:
		if mask and is_instance_valid(mask):
			mask.queue_free()
	active_gas_masks.clear()
	available_markers = spawn_markers.duplicate()
	
	# Respawn
	for i in range(MAX_GAS_MASKS):
		spawn_gas_mask()
