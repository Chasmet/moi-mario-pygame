extends CharacterBody2D

const MAX_SPEED := 340.0
const ACCELERATION := 2100.0
const AIR_ACCELERATION := 1250.0
const FRICTION := 2400.0
const GRAVITY := 1850.0
const JUMP_SPEED := -650.0
const STOMP_BOUNCE := -470.0
const MAX_FALL_SPEED := 980.0
const COYOTE_TIME := 0.13
const JUMP_BUFFER_TIME := 0.16

@onready var sprite: Sprite2D = $Sprite2D

var main_controller: Node
var spawn_position := Vector2.ZERO
var world_right := 3600.0
var mobile_left := false
var mobile_right := false
var jump_queued := false
var coyote_timer := 0.0
var jump_buffer := 0.0
var invincible_timer := 0.0
var base_scale := Vector2.ONE
var last_direction := 1.0

func _ready() -> void:
	floor_snap_length = 14.0
	floor_stop_on_slope = true
	if sprite:
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
	invincible_timer = max(invincible_timer, duration)

func is_invincible() -> bool:
	return invincible_timer > 0.0

func _physics_process(delta: float) -> void:
	if invincible_timer > 0.0:
		invincible_timer -= delta
		if sprite:
			sprite.visible = int(invincible_timer * 14.0) % 2 == 0
	elif sprite:
		sprite.visible = true

	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = max(0.0, coyote_timer - delta)
		velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

	if Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER_TIME
	if jump_queued:
		jump_buffer = JUMP_BUFFER_TIME
		jump_queued = false
	else:
		jump_buffer = max(0.0, jump_buffer - delta)

	if jump_buffer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_SPEED
		jump_buffer = 0.0
		coyote_timer = 0.0

	if Input.is_action_just_released("jump") and velocity.y < -240.0:
		velocity.y *= 0.52

	var direction := Input.get_axis("move_left", "move_right")
	if mobile_left:
		direction -= 1.0
	if mobile_right:
		direction += 1.0
	direction = clamp(direction, -1.0, 1.0)

	if abs(direction) > 0.01:
		last_direction = sign(direction)
		var acceleration := ACCELERATION if is_on_floor() else AIR_ACCELERATION
		velocity.x = move_toward(velocity.x, direction * MAX_SPEED, acceleration * delta)
	else:
		var deceleration := FRICTION if is_on_floor() else AIR_ACCELERATION * 0.35
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)

	var was_falling := velocity.y > 80.0
	move_and_slide()
	global_position.x = clamp(global_position.x, 18.0, world_right - 18.0)

	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider.has_method("stomp"):
			var above_enemy := global_position.y + 16.0 < collider.global_position.y
			if was_falling and above_enemy:
				collider.call("stomp")
				velocity.y = STOMP_BOUNCE
				if main_controller and main_controller.has_method("camera_shake"):
					main_controller.call("camera_shake", 4.0)
			elif invincible_timer <= 0.0 and main_controller and main_controller.has_method("lose_life"):
				main_controller.call("lose_life")
				break

	if global_position.y > 920.0 and invincible_timer <= 0.0:
		if main_controller and main_controller.has_method("lose_life"):
			main_controller.call("lose_life")

	_update_visual(delta, direction)

func _update_visual(delta: float, direction: float) -> void:
	if not sprite:
		return
	if abs(direction) > 0.01:
		sprite.flip_h = direction < 0.0
	var target_rotation := clamp(velocity.x / MAX_SPEED, -1.0, 1.0) * 0.055
	sprite.rotation = lerp(sprite.rotation, target_rotation, min(1.0, delta * 10.0))

	var stretch := clamp(abs(velocity.y) / MAX_FALL_SPEED, 0.0, 1.0)
	var target_scale := base_scale
	if not is_on_floor():
		target_scale = base_scale * Vector2(0.96 + stretch * 0.05, 1.04 - stretch * 0.04)
	elif abs(velocity.x) > 35.0:
		var bounce := sin(Time.get_ticks_msec() * 0.018) * 0.035
		target_scale = base_scale * Vector2(1.0 - bounce, 1.0 + bounce)
	sprite.scale = sprite.scale.lerp(target_scale, min(1.0, delta * 12.0))
