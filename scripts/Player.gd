extends CharacterBody2D

const MAX_SPEED: float = 340.0
const ACCELERATION: float = 2100.0
const AIR_ACCELERATION: float = 1250.0
const FRICTION: float = 2400.0
const GRAVITY: float = 1850.0
const JUMP_SPEED: float = -650.0
const STOMP_BOUNCE: float = -470.0
const MAX_FALL_SPEED: float = 980.0
const COYOTE_TIME: float = 0.13
const JUMP_BUFFER_TIME: float = 0.16

@onready var sprite: Sprite2D = $Sprite2D

var main_controller: Node
var spawn_position: Vector2 = Vector2.ZERO
var world_right: float = 3600.0
var mobile_left: bool = false
var mobile_right: bool = false
var jump_queued: bool = false
var coyote_timer: float = 0.0
var jump_buffer: float = 0.0
var invincible_timer: float = 0.0
var base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	floor_snap_length = 14.0
	floor_stop_on_slope = true
	if sprite != null:
		base_scale = sprite.scale


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


func request_jump() -> void:
	jump_queued = true
	jump_buffer = JUMP_BUFFER_TIME


func set_invincible(duration: float) -> void:
	invincible_timer = maxf(invincible_timer, duration)


func is_invincible() -> bool:
	return invincible_timer > 0.0


func _physics_process(delta: float) -> void:
	_update_invincibility(delta)

	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

	if Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER_TIME
	if jump_queued:
		jump_buffer = JUMP_BUFFER_TIME
		jump_queued = false
	else:
		jump_buffer = maxf(0.0, jump_buffer - delta)

	if jump_buffer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_SPEED
		jump_buffer = 0.0
		coyote_timer = 0.0

	if Input.is_action_just_released("jump") and velocity.y < -240.0:
		velocity.y *= 0.52

	var direction: float = Input.get_axis("move_left", "move_right")
	if mobile_left:
		direction -= 1.0
	if mobile_right:
		direction += 1.0
	direction = clampf(direction, -1.0, 1.0)

	if absf(direction) > 0.01:
		var acceleration: float = ACCELERATION if is_on_floor() else AIR_ACCELERATION
		velocity.x = move_toward(velocity.x, direction * MAX_SPEED, acceleration * delta)
	else:
		var deceleration: float = FRICTION if is_on_floor() else AIR_ACCELERATION * 0.35
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)

	var was_falling: bool = velocity.y > 80.0
	move_and_slide()
	global_position.x = clampf(global_position.x, 18.0, world_right - 18.0)

	for index in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(index)
		var collider: Object = collision.get_collider()
		if collider != null and collider.has_method("stomp"):
			var collider_node: Node2D = collider as Node2D
			var above_enemy: bool = collider_node != null and global_position.y + 16.0 < collider_node.global_position.y
			if was_falling and above_enemy:
				collider.call("stomp")
				velocity.y = STOMP_BOUNCE
				if main_controller != null and main_controller.has_method("camera_shake"):
					main_controller.call("camera_shake", 4.0)
			elif invincible_timer <= 0.0 and main_controller != null and main_controller.has_method("lose_life"):
				main_controller.call("lose_life")
				break

	if global_position.y > 920.0 and invincible_timer <= 0.0:
		if main_controller != null and main_controller.has_method("lose_life"):
			main_controller.call("lose_life")

	_update_visual(delta, direction)


func _update_invincibility(delta: float) -> void:
	if invincible_timer > 0.0:
		invincible_timer = maxf(0.0, invincible_timer - delta)
		if sprite != null:
			sprite.visible = int(invincible_timer * 14.0) % 2 == 0
	elif sprite != null:
		sprite.visible = true


func _update_visual(delta: float, direction: float) -> void:
	if sprite == null:
		return

	if absf(direction) > 0.01:
		sprite.flip_h = direction < 0.0

	var target_rotation: float = clampf(velocity.x / MAX_SPEED, -1.0, 1.0) * 0.055
	sprite.rotation = lerpf(sprite.rotation, target_rotation, minf(1.0, delta * 10.0))

	var stretch: float = clampf(absf(velocity.y) / MAX_FALL_SPEED, 0.0, 1.0)
	var target_scale: Vector2 = base_scale
	if not is_on_floor():
		target_scale = base_scale * Vector2(0.96 + stretch * 0.05, 1.04 - stretch * 0.04)
	elif absf(velocity.x) > 35.0:
		var bounce: float = sin(float(Time.get_ticks_msec()) * 0.018) * 0.035
		target_scale = base_scale * Vector2(1.0 - bounce, 1.0 + bounce)

	sprite.scale = sprite.scale.lerp(target_scale, minf(1.0, delta * 12.0))
