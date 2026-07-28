extends CharacterBody2D

const MAX_SPEED: float = 315.0
const ACCELERATION: float = 2850.0
const AIR_ACCELERATION: float = 2050.0
const FRICTION: float = 3300.0
const AIR_DECELERATION: float = 1050.0
const GRAVITY: float = 1680.0
const JUMP_SPEED: float = -720.0
const STOMP_BOUNCE: float = -520.0
const MAX_FALL_SPEED: float = 900.0
const COYOTE_TIME: float = 0.20
const JUMP_BUFFER_TIME: float = 0.22
const APEX_GRAVITY_MULTIPLIER: float = 0.62
const FALL_GRAVITY_MULTIPLIER: float = 1.08
const CROUCH_SPEED_MULTIPLIER: float = 0.46
const CROUCH_HEIGHT_RATIO: float = 0.62
const JOYSTICK_AXIS_DEADZONE: float = 0.16

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var camera_node: Camera2D = $Camera2D

var main_controller: Node
var spawn_position: Vector2 = Vector2.ZERO
var world_right: float = 3600.0
var mobile_left: bool = false
var mobile_right: bool = false
var mobile_axis: Vector2 = Vector2.ZERO
var jump_queued: bool = false
var coyote_timer: float = 0.0
var jump_buffer: float = 0.0
var invincible_timer: float = 0.0
var base_scale: Vector2 = Vector2.ONE
var base_sprite_position: Vector2 = Vector2.ZERO
var standing_collision_size: Vector2 = Vector2(50.0, 78.0)
var crouch_collision_size: Vector2 = Vector2(50.0, 48.0)
var standing_collision_position: Vector2 = Vector2.ZERO
var crouching: bool = false
var looking_up: bool = false


func _ready() -> void:
	floor_snap_length = 18.0
	floor_stop_on_slope = true
	if sprite != null:
		base_scale = sprite.scale
		base_sprite_position = sprite.position
	if collision_shape != null:
		standing_collision_position = collision_shape.position
		var rectangle: RectangleShape2D = collision_shape.shape as RectangleShape2D
		if rectangle != null:
			standing_collision_size = rectangle.size
			crouch_collision_size = Vector2(standing_collision_size.x, standing_collision_size.y * CROUCH_HEIGHT_RATIO)


func configure(controller: Node, spawn: Vector2, bounds: float) -> void:
	main_controller = controller
	spawn_position = spawn
	world_right = bounds


func set_spawn(spawn: Vector2) -> void:
	spawn_position = spawn


func set_mobile_left(pressed: bool) -> void:
	mobile_left = pressed


func set_mobile_right(pressed: bool) -> void:
	mobile_right = pressed


func set_mobile_axis(value: Vector2) -> void:
	mobile_axis = value.limit_length(1.0)


func request_jump() -> void:
	jump_queued = true
	jump_buffer = JUMP_BUFFER_TIME


func apply_v3_dimensions(sprite_size: Vector2, collision_size: Vector2) -> void:
	if sprite != null and sprite.texture != null:
		var texture_size: Vector2 = sprite.texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			var factor: float = minf(sprite_size.x / texture_size.x, sprite_size.y / texture_size.y)
			sprite.scale = Vector2.ONE * factor
			base_scale = sprite.scale
			base_sprite_position = sprite.position

	standing_collision_size = collision_size
	crouch_collision_size = Vector2(collision_size.x, collision_size.y * CROUCH_HEIGHT_RATIO)
	if collision_shape != null:
		standing_collision_position = collision_shape.position
		_apply_collision_dimensions(crouching)

	floor_snap_length = 18.0


func set_invincible(duration: float) -> void:
	invincible_timer = maxf(invincible_timer, duration)


func is_invincible() -> bool:
	return invincible_timer > 0.0


func _physics_process(delta: float) -> void:
	_update_invincibility(delta)
	_update_stance()
	_update_vertical_motion(delta)
	_update_jump_buffer(delta)
	_try_jump()
	_apply_variable_jump_height()

	var direction: float = _get_move_direction()
	_update_horizontal_motion(delta, direction)

	var was_falling: bool = velocity.y > 70.0
	move_and_slide()
	global_position.x = clampf(global_position.x, 26.0, world_right - 26.0)

	_handle_enemy_collisions(was_falling)

	if global_position.y > 920.0 and invincible_timer <= 0.0:
		if main_controller != null and main_controller.has_method("lose_life"):
			main_controller.call("lose_life")

	_update_camera_look(delta)
	_update_visual(delta, direction)


func _update_stance() -> void:
	var horizontal_strength: float = absf(mobile_axis.x)
	var vertical_strength: float = absf(mobile_axis.y)
	var vertical_dominant: bool = vertical_strength >= 0.42 and vertical_strength >= horizontal_strength * 0.85
	var next_crouching: bool = is_on_floor() and vertical_dominant and mobile_axis.y > 0.0
	var next_looking_up: bool = is_on_floor() and vertical_dominant and mobile_axis.y < 0.0

	_set_crouching(next_crouching)
	looking_up = next_looking_up and not crouching


func _set_crouching(next_crouching: bool) -> void:
	if crouching == next_crouching:
		return
	crouching = next_crouching
	_apply_collision_dimensions(crouching)


func _apply_collision_dimensions(use_crouch_size: bool) -> void:
	if collision_shape == null:
		return
	var rectangle: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return

	var target_size: Vector2 = crouch_collision_size if use_crouch_size else standing_collision_size
	rectangle.size = target_size
	var bottom_offset: float = (standing_collision_size.y - target_size.y) * 0.5
	collision_shape.position = standing_collision_position + Vector2(0.0, bottom_offset)


func _update_vertical_motion(delta: float) -> void:
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		return

	coyote_timer = maxf(0.0, coyote_timer - delta)
	var gravity_multiplier: float = 1.0
	if absf(velocity.y) < 105.0:
		gravity_multiplier = APEX_GRAVITY_MULTIPLIER
	elif velocity.y > 0.0:
		gravity_multiplier = FALL_GRAVITY_MULTIPLIER
	velocity.y = minf(velocity.y + GRAVITY * gravity_multiplier * delta, MAX_FALL_SPEED)


func _update_jump_buffer(delta: float) -> void:
	var jump_requested: bool = Input.is_action_just_pressed("jump") or jump_queued
	jump_queued = false
	if jump_requested:
		jump_buffer = JUMP_BUFFER_TIME
	else:
		jump_buffer = maxf(0.0, jump_buffer - delta)


func _try_jump() -> void:
	if jump_buffer <= 0.0 or coyote_timer <= 0.0:
		return
	_set_crouching(false)
	looking_up = false
	velocity.y = JUMP_SPEED
	jump_buffer = 0.0
	coyote_timer = 0.0


func _apply_variable_jump_height() -> void:
	if Input.is_action_just_released("jump") and velocity.y < -180.0:
		velocity.y *= 0.62


func _get_move_direction() -> float:
	var direction: float = Input.get_axis("move_left", "move_right")
	var analog_horizontal: float = mobile_axis.x if absf(mobile_axis.x) >= JOYSTICK_AXIS_DEADZONE else 0.0
	direction += analog_horizontal
	if mobile_left:
		direction -= 1.0
	if mobile_right:
		direction += 1.0
	return clampf(direction, -1.0, 1.0)


func _update_horizontal_motion(delta: float, direction: float) -> void:
	if absf(direction) > 0.01:
		var acceleration: float = ACCELERATION if is_on_floor() else AIR_ACCELERATION
		var speed_multiplier: float = CROUCH_SPEED_MULTIPLIER if crouching else 1.0
		velocity.x = move_toward(velocity.x, direction * MAX_SPEED * speed_multiplier, acceleration * delta)
	else:
		var deceleration: float = FRICTION if is_on_floor() else AIR_DECELERATION
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)


func _handle_enemy_collisions(was_falling: bool) -> void:
	for index in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(index)
		var collider: Object = collision.get_collider()
		if collider == null or not collider.has_method("stomp"):
			continue

		var collider_node: Node2D = collider as Node2D
		var above_enemy: bool = collider_node != null and global_position.y + 22.0 < collider_node.global_position.y
		if was_falling and above_enemy:
			collider.call("stomp")
			velocity.y = STOMP_BOUNCE
			if main_controller != null and main_controller.has_method("camera_shake"):
				main_controller.call("camera_shake", 4.0)
		elif invincible_timer <= 0.0 and main_controller != null and main_controller.has_method("lose_life"):
			main_controller.call("lose_life")
			break


func _update_invincibility(delta: float) -> void:
	if invincible_timer > 0.0:
		invincible_timer = maxf(0.0, invincible_timer - delta)
		if sprite != null:
			sprite.visible = int(invincible_timer * 14.0) % 2 == 0
	elif sprite != null:
		sprite.visible = true


func _update_camera_look(delta: float) -> void:
	if camera_node == null:
		return

	var target_position: Vector2 = Vector2(100.0, -100.0)
	if looking_up:
		target_position.y = -190.0
	elif crouching:
		target_position.y = -55.0
	camera_node.position = camera_node.position.lerp(target_position, minf(1.0, delta * 7.5))


func _update_visual(delta: float, direction: float) -> void:
	if sprite == null:
		return

	if absf(direction) > 0.01:
		sprite.flip_h = direction < 0.0

	var target_rotation: float = clampf(velocity.x / MAX_SPEED, -1.0, 1.0) * 0.045
	if looking_up:
		target_rotation = -0.055
	sprite.rotation = lerpf(sprite.rotation, target_rotation, minf(1.0, delta * 11.0))

	var stretch: float = clampf(absf(velocity.y) / MAX_FALL_SPEED, 0.0, 1.0)
	var target_scale: Vector2 = base_scale
	var target_sprite_position: Vector2 = base_sprite_position
	if crouching:
		target_scale = base_scale * Vector2(1.08, 0.68)
		target_sprite_position.y += 14.0
	elif looking_up:
		target_scale = base_scale * Vector2(0.98, 1.04)
		target_sprite_position.y -= 4.0
	elif not is_on_floor():
		target_scale = base_scale * Vector2(0.97 + stretch * 0.04, 1.03 - stretch * 0.03)
	elif absf(velocity.x) > 35.0:
		var bounce: float = sin(float(Time.get_ticks_msec()) * 0.018) * 0.025
		target_scale = base_scale * Vector2(1.0 - bounce, 1.0 + bounce)

	sprite.scale = sprite.scale.lerp(target_scale, minf(1.0, delta * 13.0))
	sprite.position = sprite.position.lerp(target_sprite_position, minf(1.0, delta * 13.0))
