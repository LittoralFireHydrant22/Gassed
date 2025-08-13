# ElapsedTimer.gd - Attach this to the root Control node of ElapsedTimer.tscn
extends Control

# Export variables - configurable in editor when you instance the scene
@export var show_milliseconds: bool = false
@export var auto_start: bool = true
@export var timer_title: String = "TIME"
@export var show_title: bool = true

# Node references
@onready var title_label = $VBox/TitleLabel
@onready var time_label = $VBox/TimeLabel

# Timer variables
var elapsed_time: float = 0.0
var is_running: bool = false
var is_paused: bool = false

# Signals that other scenes can connect to
signal timer_started
signal timer_stopped(final_time: float)
signal timer_paused
signal timer_resumed
signal timer_reset
signal time_milestone(time: float)  # Emitted every 30 seconds

func _ready():
	setup_timer_ui()
	
	if auto_start:
		start_timer()

func setup_timer_ui():
	# Configure title
	if show_title and title_label:
		title_label.text = timer_title
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 16)
		title_label.visible = true
	else:
		if title_label:
			title_label.visible = false
	
	# Configure time display
	if time_label:
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_label.add_theme_font_size_override("font_size", 32)
	
	# Initial display
	update_display()

func _process(delta):
	if is_running and not is_paused:
		var old_time = elapsed_time
		elapsed_time += delta
		update_display()
		
		# Emit milestone signals every 30 seconds
		if int(elapsed_time / 30) > int(old_time / 30):
			time_milestone.emit(elapsed_time)

func update_display():
	if not time_label:
		return
	
	var time_text: String
	
	if show_milliseconds:
		# Format as MM:SS.MS
		var minutes = int(elapsed_time) / 60
		var seconds = int(elapsed_time) % 60
		var milliseconds = int((elapsed_time - int(elapsed_time)) * 100)
		time_text = "%02d:%02d.%02d" % [minutes, seconds, milliseconds]
	else:
		# Format as MM:SS
		var minutes = int(elapsed_time) / 60
		var seconds = int(elapsed_time) % 60
		time_text = "%02d:%02d" % [minutes, seconds]
	
	time_label.text = time_text

# Public methods that other scenes can call
func start_timer():
	if not is_running:
		is_running = true
		is_paused = false
		timer_started.emit()
		print("Elapsed timer started")

func stop_timer():
	if is_running:
		is_running = false
		is_paused = false
		timer_stopped.emit(elapsed_time)
		print("Elapsed timer stopped at: ", get_formatted_time())

func pause_timer():
	if is_running and not is_paused:
		is_paused = true
		timer_paused.emit()
		print("Elapsed timer paused at: ", get_formatted_time())

func resume_timer():
	if is_running and is_paused:
		is_paused = false
		timer_resumed.emit()
		print("Elapsed timer resumed")

func reset_timer():
	elapsed_time = 0.0
	is_running = false
	is_paused = false
	update_display()
	timer_reset.emit()
	print("Elapsed timer reset")

func restart_timer():
	reset_timer()
	start_timer()

# Utility functions
func get_elapsed_time() -> float:
	return elapsed_time

func get_formatted_time() -> String:
	var minutes = int(elapsed_time) / 60
	var seconds = int(elapsed_time) % 60
	if show_milliseconds:
		var milliseconds = int((elapsed_time - int(elapsed_time)) * 100)
		return "%02d:%02d.%02d" % [minutes, seconds, milliseconds]
	else:
		return "%02d:%02d" % [minutes, seconds]

func get_elapsed_minutes() -> int:
	return int(elapsed_time) / 60

func get_elapsed_seconds() -> int:
	return int(elapsed_time)

func is_timer_running() -> bool:
	return is_running and not is_paused

func is_timer_paused() -> bool:
	return is_paused

# Bonus/penalty functions for gameplay
func subtract_time(bonus_seconds: float):
	# For speedrun bonuses (makes time better)
	elapsed_time = max(0, elapsed_time - bonus_seconds)
	update_display()
	print("Time bonus! -", bonus_seconds, " seconds")

func add_time_penalty(penalty_seconds: float):
	# For penalties (makes time worse)
	elapsed_time += penalty_seconds
	update_display()
	print("Time penalty! +", penalty_seconds, " seconds")
