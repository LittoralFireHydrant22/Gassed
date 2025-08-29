# GasMask.gd - Each gas mask manages itself
extends Sprite2D

signal collected(value)
signal gas_mask_collected
@export var collection_value: int = 1
@onready var area = $Area2D

# Static variables shared by all gas mask instances
static var all_gas_masks: Array[Sprite2D] = []
static var visible_masks: Array[Sprite2D] = []
static var recently_collected: Array[Sprite2D] = []  # NEW: Track recently collected masks
static var max_visible: int = 3
static var is_initialized: bool = false

func _ready():
	if area:
		area.body_entered.connect(_on_body_entered)
	
	# Add this mask to the global list
	all_gas_masks.append(self)
	
	# Initialize the system when all masks are ready
	if not is_initialized:
		call_deferred("initialize_system")

func initialize_system():
	# Only run this once for the first mask that loads
	if is_initialized:
		return
	is_initialized = true
	
	# Hide all masks initially
	for mask in all_gas_masks:
		mask.visible = false
	
	# Show random masks up to max_visible
	show_initial_masks()

func show_initial_masks():
	var available_masks = all_gas_masks.duplicate()
	
	# First, always show the mask at position 46,33
	var priority_mask = null
	for mask in available_masks:
		if abs(mask.position.x - 46) < 1 and abs(mask.position.y - 33) < 1:
			priority_mask = mask
			break
	
	if priority_mask:
		priority_mask.visible = true
		visible_masks.append(priority_mask)
		available_masks.erase(priority_mask)
	
	# Then show random masks for the remaining slots
	var remaining_slots = max_visible - visible_masks.size()
	for i in range(min(remaining_slots, available_masks.size())):
		if available_masks.size() > 0:
			var random_index = randi() % available_masks.size()
			var selected_mask = available_masks[random_index]
			available_masks.remove_at(random_index)
			
			selected_mask.visible = true
			visible_masks.append(selected_mask)

func _on_body_entered(body):
	if body.has_method("collect_item") or body.is_in_group("player"):
		collect()

func collect():
	# Only collect if this mask is currently visible
	if not visible:
		return
		
	# Emit the gas mask signal for the counter
	gas_mask_collected.emit()
	
	# Emit signal (useful for updating UI, playing sounds, etc.)
	collected.emit(collection_value)
	
	# Remove this mask from visible list
	var index = visible_masks.find(self)
	if index >= 0:
		visible_masks.remove_at(index)
	
	# Add this mask to recently collected (prevent immediate respawn)
	recently_collected.append(self)
	
	# Hide this mask
	visible = false
	
	# Show a new random mask
	show_new_random_mask()

func show_new_random_mask():
	# Get masks that aren't currently visible AND weren't recently collected
	var available_masks = all_gas_masks.filter(func(mask): 
		return not mask.visible and not recently_collected.has(mask))
	
	# If no masks available (all recently collected), clear the recently collected list
	if available_masks.size() == 0:
		recently_collected.clear()
		available_masks = all_gas_masks.filter(func(mask): return not mask.visible)
	
	# Show a random available mask
	if available_masks.size() > 0 and visible_masks.size() < max_visible:
		var random_index = randi() % available_masks.size()
		var selected_mask = available_masks[random_index]
		
		selected_mask.visible = true
		visible_masks.append(selected_mask)
		
		# Limit recently_collected size to prevent it from growing too large
		# Keep it smaller than total masks to ensure we always have options
		if recently_collected.size() >= all_gas_masks.size() - max_visible:
			recently_collected.remove_at(0)  # Remove oldest entry

# Optional: Reset all masks (useful for new game/level)
static func reset_all_masks():
	visible_masks.clear()
	recently_collected.clear()  # NEW: Clear the recently collected list
	for mask in all_gas_masks:
		mask.visible = false
	
	# Show initial masks again
	if all_gas_masks.size() > 0:
		all_gas_masks[0].show_initial_masks()
