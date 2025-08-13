# GameTimer.gd - Attach this to a Label node
extends Label

@export var countdown_minutes: float = 5.0
@export var auto_start: bool = true  # Set to false so you can manually start

var time_remaining: float
var is_running: bool = false

signal timer_finished

func _ready():
	time_remaining = countdown_minutes * 60.0
	
	# Style the timer
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 16)
	
	update_display()
	
	if auto_start:
		start_timer()

func _process(delta):
	if is_running:
		time_remaining -= delta
		
		if time_remaining <= 0:
			time_remaining = 0
			is_running = false
			timer_finished.emit()
		
		update_display()

func update_display():
	var minutes = int(time_remaining) / 60
	var seconds = int(time_remaining) % 60
	text = "%02d:%02d" % [minutes, seconds]
	
	# Color warnings
	if time_remaining <= 10:
		modulate = Color.RED
	elif time_remaining <= 30:
		modulate = Color.YELLOW
	else:
		modulate = Color.WHITE

func start_timer():
	is_running = true
	
func stop_timer():
	is_running = false

func reset_timer():
	time_remaining = countdown_minutes * 60.0
	is_running = false
	update_display()

func get_time_remaining() -> float:
	return time_remaining
