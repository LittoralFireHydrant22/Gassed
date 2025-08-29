extends Node

class_name GasMaskManager

@export var max_visible: int = 3
@export var respawn_delay: float = 1.0

var all_gas_masks: Array[Node2D] = []
var visible_masks: Array[Node2D] = []
var available_masks: Array[Node2D] = []

func _ready():
	# This will be called automatically when the node is added to the scene
	pass

func initialize(gas_masks: Array[Node2D]):
	"""Initialize the manager with all gas mask nodes"""
	all_gas_masks = gas_masks
	available_masks = all_gas_masks.duplicate()
	
	# Hide all masks initially
	hide_all_masks()
	
	# Show initial random masks
	show_random_masks()

func hide_all_masks():
	"""Hide all gas masks"""
	for mask in all_gas_masks:
		if mask != null:
			mask.visible = false

func show_random_masks():
	"""Show initial set of random masks"""
	for i in range(max_visible):
		if available_masks.size() > 0:
			show_new_random_mask()

func show_new_random_mask():
	"""Show a new random mask"""
	if visible_masks.size() >= max_visible:
		return # Already at max capacity
	
	# Refill available masks if empty
	if available_masks.size() == 0:
		available_masks = all_gas_masks.filter(func(mask): return not visible_masks.has(mask))
	
	if available_masks.size() > 0:
		var random_index = randi() % available_masks.size()
		var selected_mask = available_masks[random_index]
		available_masks.remove_at(random_index)
		
		selected_mask.visible = true
		visible_masks.append(selected_mask)

func collect_mask(mask: Node2D):
	"""Called when a mask is collected - with delay"""
	var index = visible_masks.find(mask)
	if index >= 0:
		# Hide the collected mask
		mask.visible = false
		
		# Remove from visible masks
		visible_masks.remove_at(index)
		
		# Spawn a new mask after delay
		if respawn_delay > 0:
			await get_tree().create_timer(respawn_delay).timeout
		show_new_random_mask()

func collect_mask_immediate(mask: Node2D):
	"""Called when a mask is collected - immediate respawn"""
	var index = visible_masks.find(mask)
	if index >= 0:
		mask.visible = false
		visible_masks.remove_at(index)
		show_new_random_mask()

func get_visible_masks() -> Array[Node2D]:
	"""Get currently visible masks"""
	return visible_masks

func respawn_all_masks():
	"""Reset and respawn all masks (useful for level reset)"""
	visible_masks.clear()
	available_masks = all_gas_masks.duplicate()
	hide_all_masks()
	show_random_masks()

# Signal to emit when a mask is collected (optional)
signal mask_collected(mask: Node2D)
