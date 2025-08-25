extends Control

# Gas mask counter variables
var gas_masks: int = 0
const MAX_GAS_MASKS: int = 3

# UI References (assign these in the editor or get them in _ready())
@onready var counter_label: Label = $CounterLabel
@onready var mask_icons: Array[Sprite2D] = []

# Optional: Sound effects (add these later when you have audio files)
# @onready var pickup_sound: AudioStreamPlayer = $PickupSound
# @onready var max_sound: AudioStreamPlayer = $MaxSound

func _ready():
	# Get mask icon references (UI display masks)
	mask_icons = [
		$MaskIcon1,
		$MaskIcon2,
		$MaskIcon3
	]
	
	# Don't stack them - spread them out so you can see all 3
	for i in range(mask_icons.size()):
		if mask_icons[i]:
			# Position masks horizontally with some spacing
			mask_icons[i].position.x = i * 60  # Adjust spacing as needed
			# Make sure all masks start dimmed
			mask_icons[i].modulate = Color(0.3, 0.3, 0.3, 0.5)
	
	# Connect to gas mask pickup signals - look for nodes starting with "GasMask"
	var all_nodes = get_tree().get_nodes_in_group("gas_masks")
	if all_nodes.is_empty():
		# If no group found, search by name pattern
		all_nodes = []
		var scene_root = get_tree().current_scene
		_find_gas_mask_nodes(scene_root, all_nodes)
	
	for mask in all_nodes:
		if mask.has_signal("gas_mask_collected"):
			mask.gas_mask_collected.connect(add_gas_mask)
	
	# Initialize display
	update_display()

# Add a gas mask
func add_gas_mask() -> bool:
	if gas_masks < MAX_GAS_MASKS:
		gas_masks += 1
		update_display()
		
		# Play pickup sound (add later when you have audio)
		# if pickup_sound:
		#     pickup_sound.play()
		
		return true
	else:
		# Inventory full
		# if max_sound:
		#     max_sound.play()
		
		return false

# Remove/use a gas mask
func use_gas_mask() -> bool:
	if gas_masks > 0:
		gas_masks -= 1
		update_display()
		return true
	else:
		return false

# Update the UI display
func update_display():
	# Update counter label
	if counter_label:
		counter_label.text = str(gas_masks) + " / " + str(MAX_GAS_MASKS)
	
	# Light up masks as you collect them
	for i in range(mask_icons.size()):
		if mask_icons[i]:
			if (i + 1) <= gas_masks:
				# Mask is "collected" - light it up!
				mask_icons[i].modulate = Color.WHITE
			else:
				# Mask not collected yet - dim/grayed out
				mask_icons[i].modulate = Color(0.3, 0.3, 0.3, 0.5)

# Check if inventory is full
func is_full() -> bool:
	return gas_masks >= MAX_GAS_MASKS

# Check if inventory is empty
func is_empty() -> bool:
	return gas_masks <= 0

# Get current count
func get_count() -> int:
	return gas_masks

# Set count directly (useful for loading save data)
func set_count(count: int):
	gas_masks = clamp(count, 0, MAX_GAS_MASKS)
	update_display()

# Helper function to find gas mask nodes by name pattern
func _find_gas_mask_nodes(node: Node, result_array: Array):
	# Check if current node name starts with "GasMask" but exclude our UI icons
	if node.name.begins_with("GasMask") and node != self and not is_ancestor_of(node):
		result_array.append(node)
	
	# Recursively check all children
	for child in node.get_children():
		_find_gas_mask_nodes(child, result_array)

# Example: Connect to pickup area
func _on_pickup_area_entered(body):
	if body.name == "player":
		add_gas_mask()

# Example: Connect to use input
func _input(event):
	if event.is_action_pressed("use_gas_mask"):
		use_gas_mask()
