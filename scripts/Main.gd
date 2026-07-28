extends Node2D

const MAX_LEVEL: int = 10
const GROUND_TOP: float = 620.0
const SAVE_PATH: String = "user://super_chk_bros_save.cfg"

const LEVEL_NAMES: Array[String] = [
	"Côte ensoleillée",
	"Jungle des lianes",
	"Dunes rouges",
	"Montagne glacée",
	"Grotte du gardien",
	"Usine mécanique",
	"Ville nocturne",
	"Volcan interdit",
	"Royaume des nuages",
	"Forteresse finale"
]

const ENEMY_TEXTURE_PATHS: Array[String] = [
	"res://ennemi 1.png",
	"res://ennemi.png.png",
	"res://ennemis 2.png",
	"res://ennemis 3.png",
	"res://ennemis 4.png",
	"res://ennemis 5.png",
	"res://ennemis 6.png",
	"res://ennemis 7.png",
	"res://ennemis 9.png",
	"res://ennemis 10.png",
	"res://ennemis 11.png",
	"res://ennemis 12.png",
	"res://ennemis 13.png",
	"res://ennemis 14.png",
	"res://ennemis 15.png"
]

@onready var world: Node2D = $World
@onready var score_label: Label = $UI/HUD/ScoreLabel
@onready var lives_label: Label = $UI/HUD/LivesLabel
@onready var coin_label: Label = $UI/HUD/CoinLabel
@onready var level_label: Label = $UI/HUD/LevelLabel
@onready var high_label: Label = $UI/HUD/HighLabel
@onready var boss_label: Label = $UI/HUD/BossLabel
@onready var message_label: Label = $UI/HUD/MessageLabel
@onready var progress_bar: ProgressBar = $UI/HUD/ProgressBar
@onready var ui_layer: CanvasLayer = $UI

var player: CharacterBody2D
var camera: Camera2D
var current_goal: Area2D

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var enemy_textures: Array[Texture2D] = []
var ground_segments: Array[Dictionary] = []
var player_texture: Texture2D
var friend_texture: Texture2D

var score: int = 0
var lives: int = 5
var coins: int = 0
var current_level: int = 1
var unlocked_level: int = 1
var high_score: int = 0
var boss_alive: int = 0
var level_width: float = 3600.0
var respawn_position: Vector2 = Vector2(120.0, 560.0)
var transitioning: bool = false
var paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_resources()
	_load_save()
	_create_player()
	_create_mobile_controls()
	update_hud()
	load_level(1)


func _process(_delta: float) -> void:
	if player != null and is_instance_valid(player):
		var ratio: float = player.global_position.x / maxf(level_width, 1.0)
		progress_bar.value = clampf(ratio * 100.0, 0.0, 100.0)


func _load_resources() -> void:
	if ResourceLoader.exists("res://player.png"):
		player_texture = load("res://player.png") as Texture2D
	if ResourceLoader.exists("res://ami passseur 1.png"):
		friend_texture = load("res://ami passseur 1.png") as Texture2D

	for path in ENEMY_TEXTURE_PATHS:
		if ResourceLoader.exists(path):
			var texture: Texture2D = load(path) as Texture2D
			if texture != null:
				enemy_textures.append(texture)


func _load_save() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		high_score = int(config.get_value("progress", "high_score", 0))
		unlocked_level = clampi(int(config.get_value("progress", "unlocked_level", 1)), 1, MAX_LEVEL)


func _save_progress() -> void:
	high_score = maxi(high_score, score)
	var config: ConfigFile = ConfigFile.new()
	config.set_value("progress", "high_score", high_score)
	config.set_value("progress", "unlocked_level", unlocked_level)
	config.save(SAVE_PATH)


func _create_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.collision_layer = 1
	player.collision_mask = 1 | 2
	player.floor_snap_length = 14.0
	player.floor_max_angle = deg_to_rad(48.0)

	var collision: CollisionShape2D = CollisionShape2D.new()
	var body_shape: RectangleShape2D = RectangleShape2D.new()
	body_shape.size = Vector2(44.0, 68.0)
	collision.shape = body_shape
	player.add_child(collision)

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite2D"
	if player_texture != null:
		sprite.texture = player_texture
		_fit_sprite(sprite, Vector2(62.0, 86.0))
	else:
		sprite.texture = _make_fallback_texture(Color("#1f9cf0"), Vector2i(48, 72))
	player.add_child(sprite)

	var player_script: Script = load("res://scripts/Player.gd") as Script
	player.set_script(player_script)

	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.position = Vector2(120.0, -40.0)
	camera.zoom = Vector2(1.05, 1.05)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	camera.limit_left = 0
	camera.limit_top = -250
	camera.limit_bottom = 900
	player.add_child(camera)

	world.add_child(player)
	player.call("configure", self, respawn_position, level_width)


func load_level(level: int) -> void:
	if transitioning:
		return
	transitioning = true
	get_tree().paused = false
	paused = false
	current_level = clampi(level, 1, MAX_LEVEL)
	rng.seed = 7341 + current_level * 981
	boss_alive = 0
	coins = 0
	respawn_position = Vector2(120.0, 560.0)

	_clear_level()
	await get_tree().process_frame

	level_width = 3200.0 + float(current_level) * 360.0
	var theme: Dictionary = _get_theme(current_level)
	_create_background(theme)
	_build_ground(theme)
	_build_elevated_platforms(theme)
	_place_level_objects(theme)
	_create_goal(theme)
	_reset_player_for_level()
	update_hud()
	show_message("NIVEAU %d\n%s" % [current_level, LEVEL_NAMES[current_level - 1]], 1.4)
	transitioning = false


func _clear_level() -> void:
	for child in world.get_children():
		if child != player:
			child.queue_free()
	ground_segments.clear()
	current_goal = null


func _reset_player_for_level() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.global_position = respawn_position
	player.velocity = Vector2.ZERO
	player.call("configure", self, respawn_position, level_width)
	if camera != null:
		camera.limit_right = int(level_width)
		camera.position = Vector2(120.0, -40.0)


func _get_theme(level: int) -> Dictionary:
	var themes: Array[Dictionary] = [
		{"sky": Color("#55bde8"), "horizon": Color("#bdefff"), "ground": Color("#8a532b"), "top": Color("#4fbe50"), "accent": Color("#ffe36c"), "hazard": Color("#36a9e1")},
		{"sky": Color("#55a86c"), "horizon": Color("#b6e39a"), "ground": Color("#5a3a24"), "top": Color("#278d43"), "accent": Color("#ffcf4a"), "hazard": Color("#254d2b")},
		{"sky": Color("#e8a85b"), "horizon": Color("#ffe0a1"), "ground": Color("#a95d2d"), "top": Color("#d89a43"), "accent": Color("#fff0a8"), "hazard": Color("#7c3c25")},
		{"sky": Color("#7eaee4"), "horizon": Color("#e6f7ff"), "ground": Color("#52718a"), "top": Color("#d6f6ff"), "accent": Color("#a6e8ff"), "hazard": Color("#2f6d9d")},
		{"sky": Color("#242a46"), "horizon": Color("#514a6b"), "ground": Color("#3a3441"), "top": Color("#7f778a"), "accent": Color("#e7b85a"), "hazard": Color("#15131d")},
		{"sky": Color("#6f7f8d"), "horizon": Color("#c1cbd2"), "ground": Color("#4c5358"), "top": Color("#d3a62b"), "accent": Color("#58e0ff"), "hazard": Color("#a72e24")},
		{"sky": Color("#171d4f"), "horizon": Color("#684a9c"), "ground": Color("#353451"), "top": Color("#31d4c5"), "accent": Color("#ff5ad6"), "hazard": Color("#131329")},
		{"sky": Color("#5c1d19"), "horizon": Color("#d34e22"), "ground": Color("#3b2926"), "top": Color("#8e3725"), "accent": Color("#ffb82e"), "hazard": Color("#ff401f")},
		{"sky": Color("#65bde8"), "horizon": Color("#f4fbff"), "ground": Color("#77889b"), "top": Color("#f1f5f7"), "accent": Color("#ffd369"), "hazard": Color("#7ac5e8")},
		{"sky": Color("#1b1028"), "horizon": Color("#5a1f36"), "ground": Color("#29212f"), "top": Color("#b13f4d"), "accent": Color("#f5c55d"), "hazard": Color("#e11d35")}
	]
	return themes[level - 1]


func _create_background(theme: Dictionary) -> void:
	var sky: Color = theme["sky"]
	var horizon_color: Color = theme["horizon"]
	var accent: Color = theme["accent"]
	_create_visual_rect(world, Vector2(level_width * 0.5, 280.0), Vector2(level_width + 500.0, 900.0), sky, -30)

	var horizon: Polygon2D = Polygon2D.new()
	horizon.z_index = -29
	horizon.color = horizon_color
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(-100.0, 520.0))
	var x: float = -100.0
	while x <= level_width + 200.0:
		var mountain_y: float = 360.0 + sin(x * 0.006 + float(current_level)) * 75.0 + rng.randf_range(-35.0, 35.0)
		points.append(Vector2(x, mountain_y))
		x += 180.0
	points.append(Vector2(level_width + 200.0, 760.0))
	points.append(Vector2(-100.0, 760.0))
	horizon.polygon = points
	world.add_child(horizon)

	var sun: Polygon2D = Polygon2D.new()
	sun.position = Vector2(550.0 + float(current_level) * 90.0, 145.0)
	sun.polygon = _regular_polygon(58.0, 32)
	sun.color = Color(accent, 0.78)
	sun.z_index = -28
	world.add_child(sun)

	var decoration_count: int = 18 + current_level * 2
	for _i in range(decoration_count):
		var decoration: Polygon2D = Polygon2D.new()
		decoration.position = Vector2(rng.randf_range(100.0, level_width - 100.0), rng.randf_range(90.0, 390.0))
		decoration.polygon = _regular_polygon(rng.randf_range(2.0, 6.0), 8)
		decoration.color = Color(accent, rng.randf_range(0.25, 0.7))
		decoration.z_index = -27
		world.add_child(decoration)


func _build_ground(theme: Dictionary) -> void:
	var ground_color: Color = theme["ground"]
	var top_color: Color = theme["top"]
	var hazard_color: Color = theme["hazard"]
	var x: float = 0.0

	while x < level_width:
		var remaining: float = level_width - x
		var segment_width: float = 0.0
		if x < 1.0:
			segment_width = 720.0
		elif remaining < 780.0:
			segment_width = remaining
		else:
			segment_width = rng.randf_range(480.0, 760.0)

		_create_platform(Vector2(x + segment_width * 0.5, 670.0), Vector2(segment_width, 100.0), ground_color, top_color)
		ground_segments.append({"start": x, "end": x + segment_width})
		x += segment_width

		if level_width - x > 720.0:
			var max_gap: float = 130.0 + minf(float(current_level) * 4.0, 40.0)
			var gap: float = rng.randf_range(88.0, max_gap)
			_create_hazard(Vector2(x + gap * 0.5, 735.0), Vector2(gap, 170.0), hazard_color)
			x += gap


func _build_elevated_platforms(theme: Dictionary) -> void:
	var ground_color: Color = theme["ground"]
	var top_color: Color = theme["top"]

	for segment_index in range(ground_segments.size()):
		var segment: Dictionary = ground_segments[segment_index]
		var start_x: float = float(segment["start"])
		var end_x: float = float(segment["end"])
		if segment_index == 0:
			start_x += 260.0

		var count: int = 2 + int(current_level >= 3) + int(current_level >= 7)
		for platform_index in range(count):
			var fraction: float = float(platform_index + 1) / float(count + 1)
			var platform_x: float = lerpf(start_x + 90.0, end_x - 90.0, fraction)
			var platform_y: float = 500.0 - float((platform_index + segment_index) % 3) * 85.0
			var platform_width: float = rng.randf_range(120.0, 205.0)
			_create_platform(
				Vector2(platform_x, platform_y),
				Vector2(platform_width, 24.0),
				ground_color.lightened(0.08),
				top_color
			)
			_create_coin_arc(Vector2(platform_x, platform_y - 60.0), 3 + int(current_level >= 6), 34.0)

		if current_level >= 4 and segment_index > 0 and segment_index % 2 == 0:
			var moving_x: float = (start_x + end_x) * 0.5
			_create_moving_platform(
				Vector2(moving_x, 330.0),
				Vector2(150.0, 22.0),
				ground_color.lightened(0.15),
				top_color,
				115.0 + float(current_level) * 6.0
			)


func _place_level_objects(_theme: Dictionary) -> void:
	for segment_index in range(ground_segments.size()):
		var segment: Dictionary = ground_segments[segment_index]
		var start_x: float = float(segment["start"])
		var end_x: float = float(segment["end"])
		var usable_width: float = end_x - start_x

		if segment_index > 0:
			var enemy_count: int = 1 + int(current_level >= 4 and segment_index % 2 == 0)
			for enemy_index in range(enemy_count):
				var enemy_fraction: float = float(enemy_index + 1) / float(enemy_count + 1)
				var enemy_x: float = start_x + usable_width * enemy_fraction
				var flying: bool = current_level >= 6 and (enemy_index + segment_index) % 4 == 0
				var texture_count: int = maxi(enemy_textures.size(), 1)
				var texture_index: int = (current_level * 2 + segment_index + enemy_index) % texture_count
				var enemy_y: float = 410.0 if flying else 570.0
				_create_enemy(Vector2(enemy_x, enemy_y), start_x + 40.0, end_x - 40.0, texture_index, flying, false)

		var ground_coin_count: int = 3 + int(current_level >= 5)
		for coin_index in range(ground_coin_count):
			var coin_fraction: float = float(coin_index + 1) / float(ground_coin_count + 1)
			var coin_x: float = start_x + usable_width * coin_fraction
			var coin_y: float = 570.0 - float(coin_index % 2) * 28.0
			_create_coin(Vector2(coin_x, coin_y), 100)

	var checkpoint_index: int = clampi(int(float(ground_segments.size()) * 0.52), 0, ground_segments.size() - 1)
	var checkpoint_segment: Dictionary = ground_segments[checkpoint_index]
	var checkpoint_x: float = float(checkpoint_segment["start"]) + 90.0
	_create_checkpoint(Vector2(checkpoint_x, 550.0))

	if current_level >= 3:
		var bonus_index: int = mini(ground_segments.size() - 1, 1 + int(float(current_level) / 2.0))
		var bonus_segment: Dictionary = ground_segments[bonus_index]
		_create_bonus(Vector2(float(bonus_segment["start"]) + 160.0, 530.0))

	if current_level == 5 or current_level == 10:
		var final_segment: Dictionary = ground_segments[ground_segments.size() - 1]
		var boss_x: float = maxf(float(final_segment["start"]) + 180.0, level_width - 560.0)
		var texture_count: int = maxi(enemy_textures.size(), 1)
		var boss_texture: int = (current_level * 3) % texture_count
		boss_alive = 1
		_create_enemy(Vector2(boss_x, 550.0), boss_x - 210.0, boss_x + 210.0, boss_texture, false, true)


func _create_goal(theme: Dictionary) -> void:
	var accent: Color = theme["accent"]
	var goal_x: float = level_width - 145.0
	current_goal = Area2D.new()
	current_goal.name = "Goal"
	current_goal.position = Vector2(goal_x, 535.0)
	current_goal.collision_layer = 16
	current_goal.collision_mask = 1

	var collision: CollisionShape2D = CollisionShape2D.new()
	var goal_shape: RectangleShape2D = RectangleShape2D.new()
	goal_shape.size = Vector2(70.0, 170.0)
	collision.shape = goal_shape
	current_goal.add_child(collision)

	var pole: Polygon2D = Polygon2D.new()
	pole.polygon = PackedVector2Array([
		Vector2(-5.0, 85.0),
		Vector2(5.0, 85.0),
		Vector2(5.0, -85.0),
		Vector2(-5.0, -85.0)
	])
	pole.color = Color("#f0f2f4")
	current_goal.add_child(pole)

	var banner: Polygon2D = Polygon2D.new()
	banner.position = Vector2(37.0, -60.0)
	banner.polygon = PackedVector2Array([
		Vector2(-35.0, -24.0),
		Vector2(35.0, -24.0),
		Vector2(18.0, 0.0),
		Vector2(35.0, 24.0),
		Vector2(-35.0, 24.0)
	])
	banner.color = accent
	current_goal.add_child(banner)

	if friend_texture != null:
		var friend: Sprite2D = Sprite2D.new()
		friend.texture = friend_texture
		friend.position = Vector2(-70.0, 38.0)
		_fit_sprite(friend, Vector2(72.0, 88.0))
		current_goal.add_child(friend)

	current_goal.body_entered.connect(_on_goal_body_entered)
	world.add_child(current_goal)


func _create_platform(position_value: Vector2, size: Vector2, base_color: Color, top_color: Color) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 1

	var collision: CollisionShape2D = CollisionShape2D.new()
	var platform_shape: RectangleShape2D = RectangleShape2D.new()
	platform_shape.size = size
	collision.shape = platform_shape
	body.add_child(collision)

	_create_visual_rect(body, Vector2.ZERO, size, base_color, 0)
	_create_visual_rect(body, Vector2(0.0, -size.y * 0.5 + 5.0), Vector2(size.x, 10.0), top_color, 1)
	world.add_child(body)


func _create_moving_platform(position_value: Vector2, size: Vector2, base_color: Color, top_color: Color, travel: float) -> void:
	var body: AnimatableBody2D = AnimatableBody2D.new()
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 1
	body.sync_to_physics = true

	var collision: CollisionShape2D = CollisionShape2D.new()
	var platform_shape: RectangleShape2D = RectangleShape2D.new()
	platform_shape.size = size
	collision.shape = platform_shape
	body.add_child(collision)

	_create_visual_rect(body, Vector2.ZERO, size, base_color, 0)
	_create_visual_rect(body, Vector2(0.0, -size.y * 0.5 + 4.0), Vector2(size.x, 8.0), top_color, 1)
	world.add_child(body)

	var tween: Tween = create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(body, "position", position_value + Vector2(0.0, -travel), 1.8)
	tween.tween_property(body, "position", position_value, 1.8)


func _create_enemy(position_value: Vector2, patrol_left: float, patrol_right: float, texture_index: int, flying: bool, boss: bool) -> void:
	var enemy: CharacterBody2D = CharacterBody2D.new()
	enemy.position = position_value
	enemy.collision_layer = 2
	enemy.collision_mask = 1

	var collision_size: Vector2 = Vector2(92.0, 92.0) if boss else Vector2(50.0, 50.0)
	var collision: CollisionShape2D = CollisionShape2D.new()
	var enemy_shape: RectangleShape2D = RectangleShape2D.new()
	enemy_shape.size = collision_size
	collision.shape = enemy_shape
	enemy.add_child(collision)

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite2D"
	if not enemy_textures.is_empty():
		sprite.texture = enemy_textures[texture_index % enemy_textures.size()]
		var target_size: Vector2 = Vector2(128.0, 128.0) if boss else Vector2(62.0, 66.0)
		_fit_sprite(sprite, target_size)
	else:
		sprite.texture = _make_fallback_texture(Color("#d83b2f"), Vector2i(int(collision_size.x), int(collision_size.y)))
	enemy.add_child(sprite)

	var enemy_script: Script = load("res://scripts/Enemy.gd") as Script
	enemy.set_script(enemy_script)
	world.add_child(enemy)

	var hit_points: int = 3 if boss else 1
	enemy.call("configure", patrol_left, patrol_right, 78.0 + float(current_level) * 9.0, flying, boss, hit_points)
	enemy.connect("defeated", Callable(self, "_on_enemy_defeated"))


func _create_coin(position_value: Vector2, value: int) -> void:
	var coin: Area2D = Area2D.new()
	coin.position = position_value
	coin.collision_layer = 4
	coin.collision_mask = 1

	var collision: CollisionShape2D = CollisionShape2D.new()
	var coin_shape: CircleShape2D = CircleShape2D.new()
	coin_shape.radius = 14.0
	collision.shape = coin_shape
	coin.add_child(collision)

	var glow: Polygon2D = Polygon2D.new()
	glow.polygon = _regular_polygon(18.0, 18)
	glow.color = Color(1.0, 0.8, 0.1, 0.3)
	coin.add_child(glow)

	var visual: Polygon2D = Polygon2D.new()
	visual.polygon = _regular_polygon(12.0, 18)
	visual.color = Color("#ffd83d")
	coin.add_child(visual)

	var inner: Polygon2D = Polygon2D.new()
	inner.polygon = _regular_polygon(6.0, 12)
	inner.color = Color("#fff2a6")
	coin.add_child(inner)

	coin.body_entered.connect(_on_coin_body_entered.bind(coin, value))
	world.add_child(coin)

	var tween: Tween = create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(coin, "position", position_value + Vector2(0.0, -10.0), 0.65)
	tween.tween_property(coin, "position", position_value, 0.65)


func _create_coin_arc(center: Vector2, count: int, spacing: float) -> void:
	for index in range(count):
		var offset: float = (float(index) - float(count - 1) * 0.5) * spacing
		var height_offset: float = -absf(offset) * 0.20
		_create_coin(center + Vector2(offset, height_offset), 100)


func _create_bonus(position_value: Vector2) -> void:
	var bonus: Area2D = Area2D.new()
	bonus.position = position_value
	bonus.collision_layer = 4
	bonus.collision_mask = 1

	var collision: CollisionShape2D = CollisionShape2D.new()
	var bonus_shape: CircleShape2D = CircleShape2D.new()
	bonus_shape.radius = 20.0
	collision.shape = bonus_shape
	bonus.add_child(collision)

	var star: Polygon2D = Polygon2D.new()
	star.polygon = _star_polygon(22.0, 10.0, 5)
	star.color = Color("#ffec66")
	bonus.add_child(star)
	bonus.body_entered.connect(_on_bonus_body_entered.bind(bonus))
	world.add_child(bonus)

	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(star, "rotation", TAU, 1.5).from(0.0)


func _create_checkpoint(position_value: Vector2) -> void:
	var checkpoint: Area2D = Area2D.new()
	checkpoint.position = position_value
	checkpoint.collision_layer = 8
	checkpoint.collision_mask = 1
	checkpoint.set_meta("activated", false)

	var collision: CollisionShape2D = CollisionShape2D.new()
	var checkpoint_shape: RectangleShape2D = RectangleShape2D.new()
	checkpoint_shape.size = Vector2(48.0, 130.0)
	collision.shape = checkpoint_shape
	checkpoint.add_child(collision)

	var pole: Polygon2D = Polygon2D.new()
	pole.polygon = PackedVector2Array([
		Vector2(-4.0, 65.0),
		Vector2(4.0, 65.0),
		Vector2(4.0, -65.0),
		Vector2(-4.0, -65.0)
	])
	pole.color = Color("#c8d0d8")
	checkpoint.add_child(pole)

	var light: Polygon2D = Polygon2D.new()
	light.name = "Light"
	light.position = Vector2(0.0, -52.0)
	light.polygon = _regular_polygon(14.0, 12)
	light.color = Color("#ffad32")
	checkpoint.add_child(light)

	checkpoint.body_entered.connect(_on_checkpoint_body_entered.bind(checkpoint))
	world.add_child(checkpoint)


func _create_hazard(position_value: Vector2, size: Vector2, color: Color) -> void:
	var hazard: Area2D = Area2D.new()
	hazard.position = position_value
	hazard.collision_layer = 8
	hazard.collision_mask = 1

	var collision: CollisionShape2D = CollisionShape2D.new()
	var hazard_shape: RectangleShape2D = RectangleShape2D.new()
	hazard_shape.size = size
	collision.shape = hazard_shape
	hazard.add_child(collision)

	_create_visual_rect(hazard, Vector2.ZERO, size, color, -1)
	var spike_count: int = maxi(1, int(size.x / 24.0))
	for index in range(spike_count):
		var spike: Polygon2D = Polygon2D.new()
		spike.position = Vector2(-size.x * 0.5 + 12.0 + float(index) * 24.0, -size.y * 0.5)
		spike.polygon = PackedVector2Array([
			Vector2(-11.0, 0.0),
			Vector2(0.0, -22.0),
			Vector2(11.0, 0.0)
		])
		spike.color = color.lightened(0.22)
		hazard.add_child(spike)

	hazard.body_entered.connect(_on_hazard_body_entered)
	world.add_child(hazard)


func _on_coin_body_entered(body: Node, coin: Area2D, value: int) -> void:
	if body != player or not is_instance_valid(coin):
		return
	coins += 1
	add_score(value)
	Input.vibrate_handheld(25)
	coin.queue_free()


func _on_bonus_body_entered(body: Node, bonus: Area2D) -> void:
	if body != player or not is_instance_valid(bonus):
		return
	lives = mini(lives + 1, 9)
	add_score(500)
	show_message("VIE BONUS !", 0.8)
	Input.vibrate_handheld(70)
	bonus.queue_free()
	update_hud()


func _on_checkpoint_body_entered(body: Node, checkpoint: Area2D) -> void:
	if body != player or bool(checkpoint.get_meta("activated", false)):
		return
	checkpoint.set_meta("activated", true)
	respawn_position = checkpoint.global_position + Vector2(55.0, 20.0)
	player.call("set_spawn", respawn_position)
	var light: Polygon2D = checkpoint.get_node_or_null("Light") as Polygon2D
	if light != null:
		light.color = Color("#55ff8a")
	add_score(300)
	show_message("POINT DE CONTRÔLE", 0.8)


func _on_hazard_body_entered(body: Node) -> void:
	if body == player:
		lose_life()


func _on_goal_body_entered(body: Node) -> void:
	if body != player or transitioning:
		return
	if boss_alive > 0:
		show_message("BOSS À VAINCRE !", 1.0)
		camera_shake(7.0)
		return
	_complete_level()


func _on_enemy_defeated(points: int, was_boss: bool) -> void:
	add_score(points)
	if was_boss:
		boss_alive = maxi(0, boss_alive - 1)
		boss_label.visible = false
		show_message("BOSS VAINCU !", 1.2)
		camera_shake(12.0)
		Input.vibrate_handheld(180)
	else:
		camera_shake(3.0)


func _complete_level() -> void:
	if transitioning:
		return
	transitioning = true
	add_score(1500 + coins * 25 + lives * 100)
	if current_level >= unlocked_level and current_level < MAX_LEVEL:
		unlocked_level = current_level + 1
	_save_progress()

	if current_level >= MAX_LEVEL:
		show_message("VICTOIRE TOTALE !\nLES 10 NIVEAUX SONT TERMINÉS", 3.0)
		await get_tree().create_timer(3.2).timeout
		score = 0
		lives = 5
		current_level = 1
		transitioning = false
		load_level(1)
	else:
		show_message("NIVEAU TERMINÉ !", 1.3)
		await get_tree().create_timer(1.4).timeout
		current_level += 1
		transitioning = false
		load_level(current_level)


func add_score(points: int) -> void:
	score += points
	high_score = maxi(high_score, score)
	update_hud()


func lose_life() -> void:
	if transitioning or player == null or not is_instance_valid(player):
		return
	if bool(player.call("is_invincible")):
		return

	lives -= 1
	update_hud()
	camera_shake(10.0)
	Input.vibrate_handheld(140)

	if lives <= 0:
		transitioning = true
		_save_progress()
		show_message("GAME OVER\nSCORE %d" % score, 2.4)
		await get_tree().create_timer(2.5).timeout
		score = 0
		lives = 5
		coins = 0
		current_level = 1
		transitioning = false
		load_level(1)
	else:
		player.global_position = respawn_position
		player.velocity = Vector2.ZERO
		player.call("set_invincible", 1.6)
		show_message("VIE PERDUE", 0.65)


func update_hud() -> void:
	score_label.text = "SCORE %06d" % score
	lives_label.text = "VIES %d" % lives
	coin_label.text = "PIÈCES %d" % coins
	level_label.text = "NIVEAU %d/10" % current_level
	high_label.text = "RECORD %06d" % high_score
	boss_label.visible = boss_alive > 0
	boss_label.text = "BOSS"


func show_message(text: String, duration: float = 1.0) -> void:
	message_label.text = text
	message_label.modulate = Color.WHITE
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(duration)
	tween.tween_property(message_label, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func():
		if message_label.text == text:
			message_label.text = ""
			message_label.modulate.a = 1.0
	)


func camera_shake(strength: float) -> void:
	if camera == null:
		return
	var original: Vector2 = Vector2(120.0, -40.0)
	var tween: Tween = create_tween()
	for _index in range(5):
		var random_offset: Vector2 = Vector2(
			rng.randf_range(-strength, strength),
			rng.randf_range(-strength, strength)
		)
		tween.tween_property(camera, "position", original + random_offset, 0.035)
	tween.tween_property(camera, "position", original, 0.06)


func _create_mobile_controls() -> void:
	var left_button: Button = _make_button("◀", Vector2(28.0, -150.0), Vector2(120.0, 120.0), false)
	left_button.button_down.connect(_set_mobile_left.bind(true))
	left_button.button_up.connect(_set_mobile_left.bind(false))
	ui_layer.add_child(left_button)

	var right_button: Button = _make_button("▶", Vector2(162.0, -150.0), Vector2(120.0, 120.0), false)
	right_button.button_down.connect(_set_mobile_right.bind(true))
	right_button.button_up.connect(_set_mobile_right.bind(false))
	ui_layer.add_child(right_button)

	var jump_button: Button = _make_button("SAUT", Vector2(-168.0, -160.0), Vector2(140.0, 130.0), true)
	jump_button.button_down.connect(_mobile_jump)
	ui_layer.add_child(jump_button)

	var pause_button: Button = _make_button("II", Vector2(-78.0, 18.0), Vector2(60.0, 54.0), true, true)
	pause_button.pressed.connect(_toggle_pause)
	ui_layer.add_child(pause_button)


func _make_button(text_value: String, offset_position: Vector2, button_size: Vector2, right_anchor: bool, top_anchor: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.size = button_size
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("#ffe36c"))

	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.04, 0.06, 0.10, 0.56)
	normal_style.border_color = Color(1.0, 1.0, 1.0, 0.42)
	normal_style.set_border_width_all(3)
	normal_style.set_corner_radius_all(28)

	var pressed_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.18, 0.55, 0.88, 0.78)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", normal_style)
	button.add_theme_stylebox_override("pressed", pressed_style)

	if right_anchor:
		button.anchor_left = 1.0
		button.anchor_right = 1.0
	else:
		button.anchor_left = 0.0
		button.anchor_right = 0.0

	if top_anchor:
		button.anchor_top = 0.0
		button.anchor_bottom = 0.0
	else:
		button.anchor_top = 1.0
		button.anchor_bottom = 1.0

	button.offset_left = offset_position.x
	button.offset_top = offset_position.y
	button.offset_right = offset_position.x + button_size.x
	button.offset_bottom = offset_position.y + button_size.y
	return button


func _set_mobile_left(pressed: bool) -> void:
	if player != null:
		player.call("set_mobile_left", pressed)


func _set_mobile_right(pressed: bool) -> void:
	if player != null:
		player.call("set_mobile_right", pressed)


func _mobile_jump() -> void:
	if player != null:
		player.call("request_jump")


func _toggle_pause() -> void:
	paused = not paused
	get_tree().paused = paused
	message_label.text = "PAUSE" if paused else ""
	message_label.modulate.a = 1.0


func _fit_sprite(sprite: Sprite2D, target_size: Vector2) -> void:
	if sprite.texture == null:
		return
	var texture_size: Vector2 = sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var factor: float = minf(target_size.x / texture_size.x, target_size.y / texture_size.y)
	sprite.scale = Vector2.ONE * factor


func _create_visual_rect(parent: Node, position_value: Vector2, size: Vector2, color: Color, z_value: int) -> Polygon2D:
	var visual: Polygon2D = Polygon2D.new()
	visual.position = position_value
	visual.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5)
	])
	visual.color = color
	visual.z_index = z_value
	parent.add_child(visual)
	return visual


func _regular_polygon(radius: float, sides: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(sides):
		var angle: float = TAU * float(index) / float(sides)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _star_polygon(outer_radius: float, inner_radius: float, point_count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(point_count * 2):
		var radius: float = outer_radius if index % 2 == 0 else inner_radius
		var angle: float = -PI * 0.5 + TAU * float(index) / float(point_count * 2)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _make_fallback_texture(color: Color, size: Vector2i) -> Texture2D:
	var image: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
