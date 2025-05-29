extends CharacterBody2D

enum State { IDLE, RUNNING, JUMPING, FALLING, DASHING }

@export var input_left: String = "ui_left"
@export var input_right: String = "ui_right"
@export var input_jump: String = "ui_accept"
@export var input_dash: String = "ui_select"

@export var speed: float = 175.0
@export var jump_velocity: float = -400.0
@export var dash_speed: float = 350.0
@export var dash_time: float = 0.3
@export var dash_cooldown: float = 1.0  # Time (in seconds) before next dash is allowed

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_state: State = State.IDLE
var can_double_jump: bool = false
var has_double_jumped: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0  # Tracks cooldown time
var dash_direction: Vector2 = Vector2.ZERO

@onready var animated_sprite = $AnimatedSprite2D

func _physics_process(delta: float):
	# Update cooldown timer
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	# Apply gravity when not on floor
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Handle input, update movement, and play animations
	handle_input()
	update_movement(delta)
	play_animation()
	move_and_slide()

func handle_input():
	var moving = Input.is_action_pressed(input_left) or Input.is_action_pressed(input_right)
	
	match current_state:
		State.IDLE, State.RUNNING:
			if not is_on_floor():
				current_state = State.FALLING
			elif Input.is_action_just_pressed(input_jump):
				jump()
			elif Input.is_action_just_pressed(input_dash) and dash_cooldown_timer <= 0:
				start_dash()
			elif moving:
				current_state = State.RUNNING
			else:
				current_state = State.IDLE
		
		State.JUMPING, State.FALLING:
			if Input.is_action_just_pressed(input_jump) and can_double_jump:
				double_jump()
			elif Input.is_action_just_pressed(input_dash) and dash_cooldown_timer <= 0:
				start_dash()
			elif is_on_floor():
				current_state = State.IDLE if abs(velocity.x) < 10 else State.RUNNING
		
		State.DASHING:
			dash_timer -=  get_physics_process_delta_time()
			if dash_timer <= 0:
				current_state = State.FALLING if not is_on_floor() else State.IDLE

func update_movement(delta: float):
	var direction = Input.get_axis(input_left, input_right)
	
	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, speed * 3 * delta)
		State.RUNNING:
			velocity.x = direction * speed
			animated_sprite.flip_h = direction < 0
		State.JUMPING, State.FALLING:
			if direction != 0:
				velocity.x = direction * speed
				animated_sprite.flip_h = direction <0
		State.FALLING:
			if direction == 0:
				velocity.x = direction * speed
			animated_sprite.flip_h = direction <0
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
	# Only dash if there's a valid direction
	if direction != 0:
		dash_direction = Vector2(direction, 0)
		dash_timer = dash_time
		dash_cooldown_timer = dash_cooldown  # Start cooldown
		current_state = State.DASHING
