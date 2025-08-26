extends Sprite2D

func _ready():
	# Start with the sprite invisible
	modulate.a = 0.0
	
	# Create a tween to fade in over 5 minutes
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 300.0)
	
	# Create a timer to stop the tween after 1 minute
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 60.0  # 1 minute
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout.bind(tween))
	timer.start()

func _on_timer_timeout(tween):
	tween.kill()  # St
