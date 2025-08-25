extends Node2D

# Get reference to the AnimationPlayer
@onready var animation_player = $exclamation
@onready var exclamation_sprite = $exclamation/Sprite2D  # Adjust path as needed
@onready var miner_parent = get_parent()  # Get the miner node

var is_in_gas: bool = false
var original_color: Color = Color.WHITE
var gas_start_time: float = 0.0
const GAS_DEATH_TIME: float = 20.0  # Match your gas system's death time

func _ready():
	# Set default white color
	if exclamation_sprite:
		exclamation_sprite.modulate = original_color
	
	# Play the animation
	animation_player.play("default")
	
	# Connect to the miner's gas detection if the miner has these signals
	if miner_parent:
		# Try to connect to gas-related signals from the miner
		if miner_parent.has_signal("entered_gas"):
			miner_parent.entered_gas.connect(_on_miner_entered_gas)
		if miner_parent.has_signal("exited_gas"):
			miner_parent.exited_gas.connect(_on_miner_exited_gas)

# Check the miner's modulate color and update gradient continuously
func _process(_delta):
	if miner_parent:
		# If the miner is green (in gas), start/continue gas exposure
		if miner_parent.modulate == Color.GREEN:
			if not is_in_gas:
				_on_miner_entered_gas()
			else:
				_update_danger_gradient()
		# If the miner is back to normal color, they escaped
		elif miner_parent.modulate == Color.WHITE and is_in_gas:
			_on_miner_exited_gas()

func _on_miner_entered_gas():
	is_in_gas = true
	gas_start_time = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["minute"] * 60
	print("Miner entered gas - starting danger gradient!")

func _on_miner_exited_gas():
	is_in_gas = false
	gas_start_time = 0.0
	if exclamation_sprite:
		exclamation_sprite.modulate = original_color
	print("Miner safe - exclamation turned WHITE!")

func _update_danger_gradient():
	if not exclamation_sprite or not is_in_gas:
		return
	
	# Calculate how long the miner has been in gas
	var current_time = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["minute"] * 60
	var time_in_gas = current_time - gas_start_time
	
	# Handle time wrapping (if seconds roll over)
	if time_in_gas < 0:
		time_in_gas += 60
	
	# Calculate danger level (0.0 = safe, 1.0 = about to die)
	var danger_level = clamp(time_in_gas / GAS_DEATH_TIME, 0.0, 1.0)
	
	# Create gradient from white to bright red
	var danger_color = Color.WHITE.lerp(Color.RED, danger_level)
	
	# Make it more intense as death approaches
	if danger_level > 0.7:
		# Flash effect when very close to death
		var flash_intensity = sin(Time.get_time_dict_from_system()["second"] * 10.0) * 0.3 + 0.7
		danger_color = Color.RED * flash_intensity
	elif danger_level > 0.5:
		# Bright red when halfway to death
		danger_color = Color(1.0, 0.3, 0.3)  # Bright red
	
	exclamation_sprite.modulate = danger_color
	
	# Debug output (remove this later)
	if int(time_in_gas) != int(time_in_gas - get_process_delta_time()):
		print("Danger level: ", snappedf(danger_level * 100, 0.1), "% - Time in gas: ", snappedf(time_in_gas, 0.1), "s")
