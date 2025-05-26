extends CharacterBody2D

enum State {IDLE, RUNNING, JUMPING, FALLING, DASHING}

@export var input_left: String = "ui_left"
@export var input_right: String = "ui_right"
@export var input_jump: String = "ui_accept"
@export var input_dash: String = "ui_select"

#controller variables
@export var speed: float = 200.0
@export var jump_velocity: float = -400.0
@export var dash_speed: float = 400.0
@export var dash_time: float = 0.3
@export var slide_time: float = 0.5

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_state: State = State.IDLE
var can_double_jump: bool = false
var has_double_jumped: bool = false
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var slide_timer: float = 0.0

@onready var normal_collision = $NormalCollision
 
@onready var animated_sprite = 
