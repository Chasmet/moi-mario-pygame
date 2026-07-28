extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -560.0
const GRAVITY = 1600.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction = Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 0.25)

	move_and_slide()

	# Collision avec ennemis
	for i in get_slide_collision_count():
		var coll = get_slide_collision(i)
		var collider = coll.get_collider()
		if collider and collider is CharacterBody2D and collider != self:
			if velocity.y > 0 and global_position.y < collider.global_position.y - 10:
				# Écraser l'ennemi
				var main = get_tree().get_root().get_node_or_null("Main")
				if main:
					main.add_score(250)
				collider.queue_free()
				velocity.y = -350
			else:
				var main = get_tree().get_root().get_node_or_null("Main")
				if main:
					main.lose_life()

	# Tomber dans le vide
	if global_position.y > 950:
		var main = get_tree().get_root().get_node_or_null("Main")
		if main:
			main.lose_life()
