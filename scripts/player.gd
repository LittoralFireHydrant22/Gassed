extends CharacterBody2D

enum State { IDLE, RUNNING, JUMPING, FALLING, DASHING }

@export var input_left: String = "ui_left"
@export var input_right: String = "ui_right"
@export var input_jump: String = "ui_accept"
@export var input_dash: String = "ui_select"
@export var speed: float = 105.0
@export var jump_velocity: float = -300.0
@export var dash_speed: float = 210.0
@export var dash_time: float = 0.3
@export var dash_cooldown: float = 1.0
@export var friction_multiplier: float = 8.0  # How quickly character stops sliding
@export var air_control: float = 0.8  # How much control you have in the air (0.0 to 1.0)
@export var coyote_time: float = 0.1  # Grace period for jumping after leaving ground
@export var jump_buffer_time: float = 0.15  # Buffer for early jump inputs
@export var screen_boundary_action: String = "respawn"  # "respawn", "clamp", "wrap", or "none"
@export var respawn_position: Vector2 = Vector2(100, 100)  # Where to respawn player

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_state: State = State.IDLE
var can_double_jump: bool = false
var has_double_jumped: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var screen_size: Vector2
var respawn_flag: bool = false  # Flag to handle respawn over multiple frames

# Signals for screen boundary events
signal player_left_screen
signal player_respawned
signal checkpoint_reached(position: Vector2)

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	screen_size = get_viewport().get_visible_rect().size
	print("Initial respawn position: ", respawn_position)
	print("Screen boundary action: ", screen_boundary_action)

func _physics_process(delta: float):
	# Handle respawn flag first, before any other processing
	if respawn_flag:
		force_respawn()
		return
	
	# Update timers
	update_timers(delta)
	
	# Apply gravity when not on floor and not dashing
	if not is_on_floor() and current_state != State.DASHING:
		velocity.y += gravity * delta
	
	# Handle coyote time
	handle_coyote_time()
	
	# Handle input, update movement, and play animations
	handle_input()
	update_movement(delta)
	play_animation()
	move_and_slide()
	
	# Check screen boundaries
	check_screen_boundaries()
	
	# Reset double jump when landing
	if is_on_floor() and not was_on_floor:
		can_double_jump = false
		has_double_jumped = false
	
	was_on_floor = is_on_floor()

func update_timers(delta: float):
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	if coyote_timer > 0:
		coyote_timer -= delta
	
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta

func handle_coyote_time():
	# Start coyote timer when leaving the ground
	if was_on_floor and not is_on_floor() and current_state != State.JUMPING:
		coyote_timer = coyote_time

func handle_input():
	var moving = Input.is_action_pressed(input_left) or Input.is_action_pressed(input_right)
	
	# Handle jump buffer
	if Input.is_action_just_pressed(input_jump):
		jump_buffer_timer = jump_buffer_time
	
	# Manual respawn for testing (press R key)
	if Input.is_action_just_pressed("ui_cancel"):  # ESC key
		print("Manual respawn triggered")
		respawn_player()
	
	match current_state:
		State.IDLE, State.RUNNING:
			if not is_on_floor():
				current_state = State.FALLING
			elif can_jump() and jump_buffer_timer > 0:
				jump()
				jump_buffer_timer = 0
			elif Input.is_action_just_pressed(input_dash) and can_dash():
				start_dash()
			elif moving:
				current_state = State.RUNNING
			else:
				# Only switch to idle if we're actually moving slow enough
				if current_state == State.RUNNING and abs(velocity.x) < 10:
					current_state = State.IDLE
				elif current_state == State.IDLE:
					current_state = State.IDLE
				else:
					current_state = State.RUNNING
		
		State.JUMPING, State.FALLING:
			if can_jump() and jump_buffer_timer > 0:
				if is_double_jump_available():
					double_jump()
				elif can_coyote_jump():
					jump()
				jump_buffer_timer = 0
			elif Input.is_action_just_pressed(input_dash) and can_dash():
				start_dash()
			elif is_on_floor():
				current_state = State.IDLE if abs(velocity.x) < 10 else State.RUNNING
		
		State.DASHING:
			dash_timer -= get_physics_process_delta_time()
			if dash_timer <= 0:
				current_state = State.FALLING if not is_on_floor() else State.IDLE

func check_screen_boundaries():
	var camera = get_viewport().get_camera_2d()
	var screen_rect: Rect2
	
	if camera:
		# Get camera boundaries
		var cam_pos = camera.get_screen_center_position()
		var cam_size = get_viewport().get_visible_rect().size / camera.zoom
		screen_rect = Rect2(cam_pos - cam_size / 2, cam_size)
	else:
		# Fallback to viewport size if no camera
		screen_rect = Rect2(Vector2.ZERO, screen_size)
	
	var player_pos = global_position
	var is_outside = (
		player_pos.x < screen_rect.position.x or
		player_pos.x > screen_rect.position.x + screen_rect.size.x or
		player_pos.y < screen_rect.position.y or
		player_pos.y > screen_rect.position.y + screen_rect.size.y
	)
	
	# Debug print to see if detection is working
	if is_outside:
		print("Player left screen at position: ", player_pos)
		print("Screen rect: ", screen_rect)
		print("Boundary action: ", screen_boundary_action)
		player_left_screen.emit()
		handle_screen_boundary()

func handle_screen_boundary():
	match screen_boundary_action:
		"respawn":
			respawn_player()
		"clamp":
			clamp_to_screen()
		"wrap":
			wrap_around_screen()
		"none":
			pass  # Do nothing, let other systems handle it

func respawn_player():
	print("=== RESPAWN DEBUG ===")
	print("Before respawn - Player position: ", global_position)
	print("Respawn position variable: ", respawn_position)
	print("Setting global_position to: ", Vector2(100, 100))
	
	# Force set to exactly (100, 100) for testing
	global_position = Vector2(100, 100)
	position = Vector2(100, 100)  # Try both global_position and position
	
	velocity = Vector2.ZERO
	current_state = State.IDLE
	can_double_jump = false
	has_double_jumped = false
	dash_cooldown_timer = 0.0
	
	print("After respawn - Player position: ", global_position)
	print("After respawn - Local position: ", position)
	print("=== END RESPAWN DEBUG ===")
	
	player_respawned.emit()

func clamp_to_screen():
	var camera = get_viewport().get_camera_2d()
	var screen_rect: Rect2
	
	if camera:
		var cam_pos = camera.get_screen_center_position()
		var cam_size = get_viewport().get_visible_rect().size / camera.zoom
		screen_rect = Rect2(cam_pos - cam_size / 2, cam_size)
	else:
		screen_rect = Rect2(Vector2.ZERO, screen_size)
	
	# Add small margin to prevent player from getting stuck at edge
	var margin = 10.0
	global_position.x = clamp(global_position.x, 
		screen_rect.position.x + margin, 
		screen_rect.position.x + screen_rect.size.x - margin)
	global_position.y = clamp(global_position.y, 
		screen_rect.position.y + margin, 
		screen_rect.position.y + screen_rect.size.y - margin)

func wrap_around_screen():
	var camera = get_viewport().get_camera_2d()
	var screen_rect: Rect2
	
	if camera:
		var cam_pos = camera.get_screen_center_position()
		var cam_size = get_viewport().get_visible_rect().size / camera.zoom
		screen_rect = Rect2(cam_pos - cam_size / 2, cam_size)
	else:
		screen_rect = Rect2(Vector2.ZERO, screen_size)
	
	# Wrap horizontally
	if global_position.x < screen_rect.position.x:
		global_position.x = screen_rect.position.x + screen_rect.size.x
	elif global_position.x > screen_rect.position.x + screen_rect.size.x:
		global_position.x = screen_rect.position.x
	
	# Wrap vertically
	if global_position.y < screen_rect.position.y:
		global_position.y = screen_rect.position.y + screen_rect.size.y
	elif global_position.y > screen_rect.position.y + screen_rect.size.y:
		global_position.y = screen_rect.position.y

func can_jump() -> bool:
	return Input.is_action_just_pressed(input_jump)

func is_double_jump_available() -> bool:
	return can_double_jump and not has_double_jumped

func can_coyote_jump() -> bool:
	return coyote_timer > 0

func can_dash() -> bool:
	return dash_cooldown_timer <= 0

func update_movement(delta: float):
	var direction = Input.get_axis(input_left, input_right)
	
	match current_state:
		State.IDLE:
			# Stop sliding quickly when idle
			velocity.x = move_toward(velocity.x, 0, speed * friction_multiplier * delta)
		State.RUNNING:
			if direction != 0:
				velocity.x = direction * speed
				animated_sprite.flip_h = direction < 0
			else:
				# Quick stop when releasing movement keys
				velocity.x = move_toward(velocity.x, 0, speed * friction_multiplier * delta)
				# Switch to idle if stopped
				if abs(velocity.x) < 5:
					current_state = State.IDLE
		State.JUMPING, State.FALLING:
			if direction != 0:
				# Reduced air control for more realistic physics
				var target_velocity = direction * speed * air_control
				velocity.x = move_toward(velocity.x, target_velocity, speed * air_control * 2 * delta)
				animated_sprite.flip_h = direction < 0
			else:
				# Slight air friction when no input
				velocity.x = move_toward(velocity.x, 0, speed * 0.5 * delta)
		State.DASHING:
			velocity = dash_direction * dash_speed

func play_animation():
	match current_state:
		State.IDLE: animated_sprite.play("idle")
		State.RUNNING: animated_sprite.play("run")
		State.JUMPING: animated_sprite.play("jump_up")
		State.FALLING: animated_sprite.play("jump_down")
		State.DASHING: animated_sprite.play("dash")

func jump():
	velocity.y = jump_velocity
	can_double_jump = true
	has_double_jumped = false
	current_state = State.JUMPING

func double_jump():
	velocity.y = jump_velocity * 0.8
	has_double_jumped = true
	can_double_jump = false

func start_dash():
	var direction = Input.get_axis(input_left, input_right)
	# Default to facing direction if no input
	if direction == 0:
		direction = 1 if not animated_sprite.flip_h else -1
	
	dash_direction = Vector2(direction, 0)
	dash_timer = dash_time
	dash_cooldown_timer = dash_cooldown
	current_state = State.DASHING

# Checkpoint system
func set_checkpoint(new_position: Vector2):
	respawn_position = new_position
	checkpoint_reached.emit(new_position)
	print("Checkpoint set at: ", new_position)

func set_checkpoint_to_current_position():
	set_checkpoint(global_position)
