extends CharacterBody2D

signal defeated(points: int, was_boss: bool)

@onready var sprite: Sprite2D = $Sprite2D

var patrol_left := 0.0
var patrol_right := 1000.0
var speed := 90.0
var direction := -1.0
var flying := false
var boss := false
var health := 1
var base_y := 0.0
var elapsed := 0.0
var gravity := 1650.0
var points := 250
var active := true
var base_scale := Vector2.ONE

func _ready() -> void:
	base_y = global_position.y
	if sprite:
		base_scale = sprite.scale
		sprite.flip_h = direction > 0.0

func configure(left_limit: float, right_limit: float, move_speed: float, is_flying: bool, is_boss: bool, hit_points: int) -> void:
	patrol_left = left_limit
	patrol_right = right_limit
	speed = move_speed * (0.72 if is_boss else 1.0)
	flying = is_flying
	boss = is_boss
	health = hit_points
	points = 1800 if boss else 250
	base_y = global_position.y
	direction = -1.0 if int(global_position.x) % 2 == 0 else 1.0

func _physics_process(delta: float) -> void:
	if not active:
		return
	elapsed += delta

	if flying:
		velocity.x = direction * speed
		velocity.y = cos(elapsed * 2.4) * 72.0
	else:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.y = min(velocity.y, 900.0)
		velocity.x = direction * speed

	move_and_slide()

	if global_position.x <= patrol_left:
		direction = 1.0
	elif global_position.x >= patrol_right:
		direction = -1.0
	if is_on_wall():
		direction *= -1.0

	if flying:
		global_position.y = base_y + sin(elapsed * 2.4) * 42.0

	if sprite:
		sprite.flip_h = direction > 0.0
		var pulse := 1.0 + sin(elapsed * (3.0 if boss else 5.0)) * (0.025 if boss else 0.012)
		sprite.scale = sprite.scale.lerp(base_scale * pulse, min(1.0, delta * 6.0))

	if global_position.y > 960.0:
		queue_free()

func stomp() -> void:
	if not active:
		return
	health -= 1
	if health <= 0:
		active = false
		collision_layer = 0
		collision_mask = 0
		defeated.emit(points, boss)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(1.35, 0.18), 0.18)
		tween.tween_property(self, "modulate:a", 0.0, 0.22)
		tween.chain().tween_callback(queue_free)
	else:
		direction *= -1.0
		velocity.y = -260.0
		modulate = Color("#ff7468")
		var tween := create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.22)
