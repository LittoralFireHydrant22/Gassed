extends CharacterBody2D

enum State { IDLE, RUNNING, JUMPING, FALLING, DASHING }

@export var input_left: String = "ui_left"
@export var input_right: String = "ui_right"
@export var input_jump: String = "ui_accept"
@export var input_dash: String = "ui_select"
@export var speed: float = 105.0
@export var jump_velocity: float = -300.0
@export var dash_speed: float = 280.0
@export var dash_time: float = 0.3
@export var dash_cooldown: float = 2.0
@export var friction_multiplier: float = 8.0
@export var air_control: float = 0.9
@export var coyote_time: float = 0.15  # Increased for easier testing
@export var jump_buffer_time: float = 0.1
@export var screen_boundary_action: String = "respawn"
@export var respawn_position: Vector2 = Vector2(50, 50)

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
var can_coyote_jump_flag: bool = false  # Simple flag for coyote jumping
var left_ground_by_jumping: bool = false  # Track if we left ground by jumping
var screen_size: Vector2
var respawn_flag: bool = false

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
	
	# Reset states when landing
	if is_on_floor() and not was_on_floor:
		print("Landed on floor - resetting flags")
		can_double_jump = false
		has_double_jumped = false
		can_coyote_jump_flag = false  # Reset coyote jump when landing
		left_ground_by_jumping = false  # Reset jump flag when landing
		current_state = State.IDLE if abs(velocity.x) < 10 else State.RUNNING
	
	was_on_floor = is_on_floor()

func update_timers(delta: float):
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	if coyote_timer > 0:
		coyote_timer -= delta
	
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta

func handle_coyote_time():
	# When leaving the ground, start coyote timer only if we didn't jump
	if was_on_floor and not is_on_floor():
		if not left_ground_by_jumping:
			print("Left ground by walking - starting coyote timer")
			coyote_timer = coyote_time
			can_coyote_jump_flag = true  # Allow coyote jumping
		else:
			print("Left ground by jumping - no coyote time")
			can_coyote_jump_flag = false
		
		# Enable double jump when leaving ground
		if not can_double_jump and not has_double_jumped:
			can_double_jump = true

func handle_input():
	var moving = Input.is_action_pressed(input_left) or Input.is_action_pressed(input_right)
	
	# Handle jump buffer
	if Input.is_action_just_pressed(input_jump):
		jump_buffer_timer = jump_buffer_time
	
	# Manual respawn for testing (press ESC key)
	if Input.is_action_just_pressed("ui_cancel"):
		print("Manual respawn triggered")
		trigger_respawn()
	
	match current_state:
		State.IDLE, State.RUNNING:
			if not is_on_floor():
				current_state = State.FALLING
			elif can_jump() and jump_buffer_timer > 0:
				# Debug info
				print("Jump pressed - is_on_floor: ", is_on_floor(), " coyote_timer: ", coyote_timer, " can_coyote_jump_flag: ", can_coyote_jump_flag)
				# Check if we should do coyote jump or regular jump
				if can_coyote_jump():
					coyote_jump()
				else:
					regular_jump()
				jump_buffer_timer = 0
			elif Input.is_action_just_pressed(input_dash) and can_dash():
				start_dash()
			elif moving:
				current_state = State.RUNNING
			else:	
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
					coyote_jump()
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
		var cam_pos = camera.get_screen_center_position()
		var cam_size = get_viewport().get_visible_rect().size / camera.zoom
		screen_rect = Rect2(cam_pos - cam_size / 2, cam_size)
	else:
		screen_rect = Rect2(Vector2.ZERO, screen_size)
	
	var player_pos = global_position
	var is_outside = (
		player_pos.x < screen_rect.position.x or
		player_pos.x > screen_rect.position.x + screen_rect.size.x or
		player_pos.y < screen_rect.position.y or
		player_pos.y > screen_rect.position.y + screen_rect.size.y
	)
	
	if is_outside:
		print("Player left screen at position: ", player_pos)
		print("Screen rect: ", screen_rect)
		print("Boundary action: ", screen_boundary_action)
		player_left_screen.emit()
		handle_screen_boundary()

func handle_screen_boundary():
	match screen_boundary_action:
		"respawn":
			trigger_respawn()
		"clamp":
			clamp_to_screen()
		"wrap":
			wrap_around_screen()
		"none":
			pass

func trigger_respawn():
	print("=== RESPAWN TRIGGERED ===")
	print("Setting respawn flag")
	respawn_flag = true

func force_respawn():
	print("=== FORCE RESPAWN EXECUTING ===")
	print("Before: position =", position, "global_position =", global_position)
	
	# Stop all movement and reset state
	velocity = Vector2.ZERO
	current_state = State.IDLE
	can_double_jump = false
	has_double_jumped = false
	can_coyote_jump_flag = false
	left_ground_by_jumping = false  # Reset jump flag
	dash_cooldown_timer = 0.0
	dash_timer = 0.0
	coyote_timer = 0.0  # Clear coyote timer
	jump_buffer_timer = 0.0
	
	# Force position to respawn point
	global_position = respawn_position
	
	# Call move_and_slide to update physics state
	move_and_slide()
	
	# IMPORTANT: Set was_on_floor to match the actual floor state after respawn
	was_on_floor = is_on_floor()
	
	# Force update state based on actual floor detection
	if is_on_floor():
		current_state = State.IDLE
	else:
		current_state = State.FALLING
	
	print("After: position =", position, "global_position =", global_position, "is_on_floor =", is_on_floor())
	
	# Clear the respawn flag
	respawn_flag = false
	
	player_respawned.emit()
	print("=== RESPAWN COMPLETE ===")

func clamp_to_screen():
	var camera = get_viewport().get_camera_2d()
	var screen_rect: Rect2
	
	if camera:
		var cam_pos = camera.get_screen_center_position()
		var cam_size = get_viewport().get_visible_rect().size / camera.zoom
		screen_rect = Rect2(cam_pos - cam_size / 2, cam_size)
	else:
		screen_rect = Rect2(Vector2.ZERO, screen_size)
	
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
	var result = coyote_timer > 0 and can_coyote_jump_flag
	if result:
		print("Coyote jump available - timer: ", coyote_timer, " flag: ", can_coyote_jump_flag)
	return result

func can_dash() -> bool:
	return dash_cooldown_timer <= 0

func regular_jump():
	print("Regular jump")
	velocity.y = jump_velocity
	can_double_jump = true
	has_double_jumped = false
	left_ground_by_jumping = true  # Mark that we left ground by jumping
	current_state = State.JUMPING

func coyote_jump():
	print("Coyote jump!")
	velocity.y = jump_velocity
	can_double_jump = true
	has_double_jumped = false
	can_coyote_jump_flag = false  # Disable coyote jumping after use
	coyote_timer = 0  # Clear timer
	left_ground_by_jumping = true  # Mark that we left ground by jumping
	current_state = State.JUMPING

func double_jump():
	print("Double jump!")
	velocity.y = jump_velocity * 0.8
	has_double_jumped = true
	can_double_jump = false
	left_ground_by_jumping = true  # Mark that we left ground by jumping

func update_movement(delta: float):
	var direction = Input.get_axis(input_left, input_right)
	
	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, speed * friction_multiplier * delta)
		State.RUNNING:
			if direction != 0:
				velocity.x = direction * speed
				animated_sprite.flip_h = direction < 0
			else:
				velocity.x = move_toward(velocity.x, 0, speed * friction_multiplier * delta)
				if abs(velocity.x) < 5:
					current_state = State.IDLE
		State.JUMPING, State.FALLING:
			if direction != 0:
				var target_velocity = direction * speed * air_control
				velocity.x = move_toward(velocity.x, target_velocity, speed * air_control * 2 * delta)
				animated_sprite.flip_h = direction < 0
			else:
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

func start_dash():
	var direction = Input.get_axis(input_left, input_right)
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
