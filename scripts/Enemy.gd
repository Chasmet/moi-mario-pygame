extends CharacterBody2D

var speed: float = 90.0
var direction: int = -1

func _ready() -> void:
	speed = 70.0 + randf() * 50.0
	direction = -1 if randf() > 0.5 else 1

func _physics_process(delta: float) -> void:
	velocity.x = direction * speed
	velocity.y += 1400.0 * delta
	move_and_slide()

	if is_on_wall():
		direction *= -1

	if global_position.x < 80 or global_position.x > 4500:
		direction *= -1
