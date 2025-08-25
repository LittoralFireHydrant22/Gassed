# Gas Spawn Manager - attach to a Node in your main scene
extends Node

@onready var spawn_timer: Timer = Timer.new()

# Spawn settings
const MIN_SPAWN_TIME: float = 15.0
const MAX_SPAWN_TIME: float = 45.0
const GAS_SPAWN_CHANCE: float = 0.7  # 70% chance to spawn gas when timer triggers

func _ready():
	# We'll create gas clouds manually instead of loading a scene file
	
	# Set up spawn timer
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	# Start the first spawn cycle
	schedule_next_spawn()
	
	print("Gas spawn manager ready!")

func schedule_next_spawn():
	var next_spawn_time = randf_range(MIN_SPAWN_TIME, MAX_SPAWN_TIME)
	spawn_timer.wait_time = next_spawn_time
	spawn_timer.one_shot = true
	spawn_timer.start()
	
	print("Next gas spawn in: ", next_spawn_time, " seconds")

func _on_spawn_timer_timeout():
	# Random chance to spawn gas
	if randf() < GAS_SPAWN_CHANCE:
		attempt_gas_spawn()
	else:
		print("Gas spawn skipped this time")
	
	# Schedule next spawn
	schedule_next_spawn()

func attempt_gas_spawn():
	# Find all miners in the scene
	var miners = get_tree().get_nodes_in_group("miners")
	
	if miners.is_empty():
		print("No miners found for gas spawn")
		return
	
	# Pick a random miner
	var target_miner = miners[randi() % miners.size()]
	
	if not is_instance_valid(target_miner):
		print("Target miner is invalid")
		return
	
	# Spawn gas cloud at miner's position
	spawn_gas_cloud(target_miner.global_position)

func spawn_gas_cloud(position: Vector2):
	print("Spawning gas cloud at: ", position)
	
	# Create gas cloud manually (since we don't have the scene file yet)
	var gas_cloud = create_gas_cloud_node()
	get_tree().current_scene.add_child(gas_cloud)
	gas_cloud.global_position = position
	
	# Connect to miner killed signal if needed
	if gas_cloud.has_signal("miner_killed"):
		gas_cloud.miner_killed.connect(_on_miner_killed)

func create_gas_cloud_node() -> Area2D:
	# Create the gas cloud node structure manually
	var gas_cloud = Area2D.new()
	gas_cloud.name = "GasCloud"
	
	# Add the gas cloud script
	var gas_script = GDScript.new()
	gas_script.source_code = '''
extends Area2D

@onready var gas_sprite: Sprite2D = $GasSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var death_timer: Timer = Timer.new()
@onready var expansion_timer: Timer = Timer.new()
@onready var warning_timer: Timer = Timer.new()

const GAS_DEATH_TIME: float = 20.0
const EXPANSION_TIME: float = 2.0
const WARNING_TIME: float = 3.0
var gas_radius: float = 50.0
var max_gas_radius: float = 150.0

var entities_in_gas: Array[Node] = []
var entity_timers: Dictionary = {}

func _ready():
	add_child(death_timer)
	add_child(expansion_timer) 
	add_child(warning_timer)
	
	death_timer.wait_time = GAS_DEATH_TIME
	death_timer.one_shot = true
	death_timer.timeout.connect(_on_death_timer_timeout)
	
	expansion_timer.wait_time = 0.1
	expansion_timer.timeout.connect(_on_expansion_timer_timeout)
	
	warning_timer.wait_time = WARNING_TIME
	warning_timer.one_shot = true
	warning_timer.timeout.connect(_on_warning_timer_timeout)
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	start_gas_cloud()

func start_gas_cloud():
	if gas_sprite:
		gas_sprite.modulate = Color.YELLOW
		gas_sprite.modulate.a = 0.3
	warning_timer.start()

func _on_warning_timer_timeout():
	if gas_sprite:
		gas_sprite.modulate = Color.GREEN
		gas_sprite.modulate.a = 0.6
	expansion_timer.start()
	death_timer.start()

func _on_expansion_timer_timeout():
	if gas_radius < max_gas_radius:
		gas_radius += 2.0
		if gas_sprite:
			var scale_factor = gas_radius / 50.0
			gas_sprite.scale = Vector2(scale_factor, scale_factor)
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = gas_radius
	else:
		expansion_timer.stop()

func _on_death_timer_timeout():
	for entity in entities_in_gas:
		if is_instance_valid(entity):
			kill_entity(entity)
	dissipate_gas()

func _on_body_entered(body):
	if body.is_in_group("player") or body.is_in_group("miners"):
		entities_in_gas.append(body)
		var entity_timer = Timer.new()
		add_child(entity_timer)
		entity_timer.wait_time = GAS_DEATH_TIME
		entity_timer.one_shot = true
		entity_timer.timeout.connect(func(): kill_entity_if_still_in_gas(body))
		entity_timer.start()
		entity_timers[body] = entity_timer
		if body.has_method("set_modulate"):
			body.modulate = Color.GREEN

func _on_body_exited(body):
	if body in entities_in_gas:
		entities_in_gas.erase(body)
		if body in entity_timers:
			var timer = entity_timers[body]
			if is_instance_valid(timer):
				timer.queue_free()
			entity_timers.erase(body)
		if is_instance_valid(body) and body.has_method("set_modulate"):
			body.modulate = Color.WHITE

func kill_entity_if_still_in_gas(entity):
	if entity in entities_in_gas:
		kill_entity(entity)

func kill_entity(entity):
	if not is_instance_valid(entity):
		return
	if entity in entities_in_gas:
		entities_in_gas.erase(entity)
	if entity in entity_timers:
		entity_timers.erase(entity)
	entity.queue_free()

func dissipate_gas():
	var tween = create_tween()
	if gas_sprite:
		tween.tween_property(gas_sprite, "modulate:a", 0.0, 3.0)
	tween.tween_callback(queue_free)
'''
	gas_script.reload()
	gas_cloud.set_script(gas_script)
	
	# Add sprite
	var sprite = Sprite2D.new()
	sprite.name = "GasSprite"
	gas_cloud.add_child(sprite)
	
	# Create a simple gas texture
	var texture = ImageTexture.new()
	var image = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	
	# Create a simple green circle for gas
	for x in range(100):
		for y in range(100):
			var distance = Vector2(x - 50, y - 50).length()
			if distance <= 50:
				var alpha = 1.0 - (distance / 50.0)
				image.set_pixel(x, y, Color(0, 1, 0, alpha * 0.6))
	
	texture.set_image(image)
	sprite.texture = texture
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 50.0
	collision.shape = circle_shape
	gas_cloud.add_child(collision)
	
	return gas_cloud

func _on_miner_killed(miner):
	print("Miner killed by gas: ", miner.name)
	# Add score, statistics, or other game logic here

# Manual spawn function for testing
func spawn_gas_at_player():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		spawn_gas_cloud(player.global_position)
