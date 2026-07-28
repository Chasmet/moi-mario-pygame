extends CharacterBody2D

const SPEED = 280.0
const JUMP_VELOCITY = -520.0
const GRAVITY = 1400.0

var facing_right := true

func _physics_process(delta):
	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Horizontal movement
	var direction = Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
		facing_right = direction > 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 0.2)

	move_and_slide()

	# Fall death
	if global_position.y > 900:
		var main = get_tree().get_root().get_node_or_null("Main")
		if main:
			main.lose_life()
