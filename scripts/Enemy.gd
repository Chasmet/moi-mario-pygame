extends CharacterBody2D

var speed := 80.0
var direction := -1

func _ready():
	speed = 60.0 + randf() * 40.0
	direction = -1 if randf() > 0.5 else 1

func _physics_process(delta):
	velocity.x = direction * speed
	velocity.y += 1200 * delta
	move_and_slide()

	if is_on_wall():
		direction *= -1

	# Simple bounds
	if global_position.x < 50 or global_position.x > 4000:
		direction *= -1
