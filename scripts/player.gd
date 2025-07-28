extends CharacterBody2D

enum State { IDLE, RUNNING, JUMPING, FALLING, DASHING }

@export var input_left: String = "ui_left"
@export var input_right: String = "ui_right"
@export var input_jump: String = "ui_accept"
@export var input_dash: String = "ui_select"
@export var speed: float = 150.0
@export var jump_velocity: float = -300.0
@export var dash_speed: float = 350.0
@export var dash_time: float = 0.25
@export var dash_cooldown: float = 2.0
@export var friction_multiplier: float = 8.0
@export var air_control: float = 1
@export var coyote_time: float = 0.15 
@export var jump_buffer_time: float = 0.2
@export var screen_boundary_action: String = "respawn"
@export var respawn_position: Vector2 = Vector2(50, 50)

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_state: State = State.IDLE
var jumps_remaining: int = 2  # Total jumps allowed (ground + air)
var max_jumps: int = 2  # Maximum total jumps
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var can_coyote_jump_flag: bool = false
var left_ground_by_jumping: bool = false
var screen_size: Vector2
var respawn_flag: bool = false

signal player_left_screen
signal player_respawned
signal checkpoint_reached(position: Vector2)

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	screen_size = get_viewport().get_visible_rect().size

func _physics_process(delta: float):
	if respawn_flag:
		force_respawn()
		return
	
	update_timers(delta)
	
	if not is_on_floor() and current_state != State.DASHING:
		velocity.y += gravity * delta
	
	handle_coyote_time()
	handle_input()
	update_movement(delta)
	play_animation()
	move_and_slide()
	check_screen_boundaries()
	
	if is_on_floor() and not was_on_floor:
		jumps_remaining = max_jumps  # Reset jumps when landing
		can_coyote_jump_flag = false
		left_ground_by_jumping = false
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
	if was_on_floor and not is_on_floor():
		if not left_ground_by_jumping:
			coyote_timer = coyote_time
			can_coyote_jump_flag = true
		else:
			can_coyote_jump_flag = false
		
		# Give jumps when leaving ground only if they haven't been used
		if jumps_remaining == max_jumps and not left_ground_by_jumping:
			jumps_remaining = max_jumps

func handle_input():
	var moving = Input.is_action_pressed(input_left) or Input.is_action_pressed(input_right)
	
	if Input.is_action_just_pressed(input_jump):
		jump_buffer_timer = jump_buffer_time
	
	if Input.is_action_just_pressed("ui_cancel"):
		trigger_respawn()
	
	match current_state:
		State.IDLE, State.RUNNING:
			if not is_on_floor():
				current_state = State.FALLING
			elif can_jump() and jump_buffer_timer > 0:
				if can_coyote_jump():
					coyote_jump()
				elif can_perform_jump():
					perform_jump()
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
				if can_perform_jump():
					perform_jump()
				jump_buffer_timer = 0
			elif Input.is_action_just_pressed(input_dash) and can_dash():
				start_dash()
			elif is_on_floor():
				current_state = State.IDLE if abs(velocity.x) < 10 else State.RUNNING
		
		State.DASHING:
			if can_jump() and jump_buffer_timer > 0:
				cancel_dash_with_jump()
				jump_buffer_timer = 0
			else:
				dash_timer -= get_physics_process_delta_time()
				if dash_timer <= 0:
					current_state = State.FALLING if not is_on_floor() else State.IDLE

func cancel_dash_with_jump():
	dash_timer = 0.0
	var horizontal_momentum = velocity.x * 0.5
	velocity.y = jump_velocity
	velocity.x = horizontal_momentum
	
	if can_perform_jump():
		perform_jump()
	elif can_coyote_jump():
		coyote_jump()
		return
	else:
		# No jumps available, just preserve momentum
		pass
	
	left_ground_by_jumping = true
	current_state = State.JUMPING

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
	respawn_flag = true

func force_respawn():
	velocity = Vector2.ZERO
	current_state = State.IDLE
	jumps_remaining = max_jumps
	can_coyote_jump_flag = false
	left_ground_by_jumping = false
	dash_cooldown_timer = 0.0
	dash_timer = 0.0
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	
	global_position = respawn_position
	move_and_slide()
	was_on_floor = is_on_floor()
	
	if is_on_floor():
		current_state = State.IDLE
	else:
		current_state = State.FALLING
	
	respawn_flag = false
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
	
	if global_position.x < screen_rect.position.x:
		global_position.x = screen_rect.position.x + screen_rect.size.x
	elif global_position.x > screen_rect.position.x + screen_rect.size.x:
		global_position.x = screen_rect.position.x
	
	if global_position.y < screen_rect.position.y:
		global_position.y = screen_rect.position.y + screen_rect.size.y
	elif global_position.y > screen_rect.position.y + screen_rect.size.y:
		global_position.y = screen_rect.position.y

func can_jump() -> bool:
	return Input.is_action_just_pressed(input_jump)

func can_perform_jump() -> bool:
	return jumps_remaining > 0

func can_coyote_jump() -> bool:
	return coyote_timer > 0 and can_coyote_jump_flag

func can_dash() -> bool:
	return dash_cooldown_timer <= 0

func regular_jump():
	perform_jump()

func perform_jump():
	# Calculate jump strength based on remaining jumps (first jump stronger)
	var jump_strength = jump_velocity * (0.7 + (jumps_remaining * 0.15))
	velocity.y = jump_strength
	jumps_remaining -= 1
	left_ground_by_jumping = true
	current_state = State.JUMPING

func coyote_jump():
	velocity.y = jump_velocity
	jumps_remaining = max_jumps - 1  # Use one jump for coyote jump
	can_coyote_jump_flag = false
	coyote_timer = 0
	left_ground_by_jumping = true
	current_state = State.JUMPING



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

func set_checkpoint(new_position: Vector2):
	respawn_position = new_position
	checkpoint_reached.emit(new_position)

func set_checkpoint_to_current_position():
	set_checkpoint(global_position)
