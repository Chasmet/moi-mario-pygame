extends Node2D

const MAX_LEVEL := 10
const GROUND_TOP := 620.0
const SAVE_PATH := "user://super_chk_bros_save.cfg"

const LEVEL_NAMES := [
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

const ENEMY_TEXTURES := [
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
var rng := RandomNumberGenerator.new()

var score := 0
var lives := 5
var coins := 0
var current_level := 1
var unlocked_level := 1
var high_score := 0
var level_width := 3600.0
var respawn_position := Vector2(120, 560)
var boss_alive := 0
var transitioning := false
var paused := false
var current_goal: Area2D
var ground_segments: Array[Dictionary] = []
var enemy_textures: Array[Texture2D] = []
var player_texture: Texture2D
var friend_texture: Texture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_resources()
	_load_save()
	_create_player()
	_create_mobile_controls()
	update_hud()
	load_level(current_level)

func _process(_delta: float) -> void:
	if player and is_instance_valid(player):
		progress_bar.value = clamp((player.global_position.x / max(level_width, 1.0)) * 100.0, 0.0, 100.0)

func _load_resources() -> void:
	if ResourceLoader.exists("res://player.png"):
		player_texture = load("res://player.png")
	if ResourceLoader.exists("res://ami passseur 1.png"):
		friend_texture = load("res://ami passseur 1.png")
	for path in ENEMY_TEXTURES:
		if ResourceLoader.exists(path):
			var texture := load(path) as Texture2D
			if texture:
				enemy_textures.append(texture)

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = int(cfg.get_value("progress", "high_score", 0))
		unlocked_level = clamp(int(cfg.get_value("progress", "unlocked_level", 1)), 1, MAX_LEVEL)

func _save_progress() -> void:
	if score > high_score:
		high_score = score
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "high_score", high_score)
	cfg.set_value("progress", "unlocked_level", unlocked_level)
	cfg.save(SAVE_PATH)

func _create_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.collision_layer = 1
	player.collision_mask = 1 | 2
	player.floor_snap_length = 14.0
	player.floor_max_angle = deg_to_rad(48.0)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, 68)
	shape.shape = rect
	player.add_child(shape)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = player_texture
	if player_texture:
		_fit_sprite(sprite, Vector2(62, 86))
	else:
		sprite.texture = _make_fallback_texture(Color("#1f9cf0"), Vector2i(48, 72))
	player.add_child(sprite)

	var player_script := load("res://scripts/Player.gd")
	player.set_script(player_script)

	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.position = Vector2(120, -40)
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
	current_level = clamp(level, 1, MAX_LEVEL)
	rng.seed = 7341 + current_level * 981
	boss_alive = 0
	coins = 0
	respawn_position = Vector2(120, 560)
	_clear_level()
	await get_tree().process_frame

	level_width = 3200.0 + current_level * 360.0
	var theme := _get_theme(current_level)
	_create_background(theme)
	_build_ground(theme)
	_build_elevated_platforms(theme)
	_place_level_objects(theme)
	_create_goal(theme)
	_reset_player_for_level()

	show_message("NIVEAU %d\n%s" % [current_level, LEVEL_NAMES[current_level - 1]], 1.5)
	update_hud()
	transitioning = false

func _clear_level() -> void:
	for child in world.get_children():
		if child != player:
			child.queue_free()
	ground_segments.clear()
	current_goal = null

func _reset_player_for_level() -> void:
	if not player or not is_instance_valid(player):
		return
	player.global_position = respawn_position
	player.velocity = Vector2.ZERO
	player.call("configure", self, respawn_position, level_width)
	if camera:
		camera.limit_right = int(level_width)
		camera.position = Vector2(120, -40)

func _get_theme(level: int) -> Dictionary:
	var themes := [
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
	_create_visual_rect(world, Vector2(level_width * 0.5, 280), Vector2(level_width + 500, 900), theme["sky"], -30)

	var horizon := Polygon2D.new()
	horizon.z_index = -29
	horizon.color = theme["horizon"]
	var points := PackedVector2Array()
	points.append(Vector2(-100, 520))
	var x := -100.0
	while x <= level_width + 200:
		var height := 360.0 + sin(x * 0.006 + current_level) * 75.0 + rng.randf_range(-35.0, 35.0)
		points.append(Vector2(x, height))
		x += 180.0
	points.append(Vector2(level_width + 200, 760))
	points.append(Vector2(-100, 760))
	horizon.polygon = points
	world.add_child(horizon)

	var sun := Polygon2D.new()
	sun.position = Vector2(550 + current_level * 90, 145)
	sun.polygon = _regular_polygon(58.0, 32)
	sun.color = Color(theme["accent"], 0.78)
	sun.z_index = -28
	world.add_child(sun)

	for i in range(18 + current_level * 2):
		var deco := Polygon2D.new()
		deco.position = Vector2(rng.randf_range(100.0, level_width - 100.0), rng.randf_range(90.0, 390.0))
		deco.polygon = _regular_polygon(rng.randf_range(2.0, 6.0), 8)
		deco.color = Color(theme["accent"], rng.randf_range(0.25, 0.7))
		deco.z_index = -27
		world.add_child(deco)

func _build_ground(theme: Dictionary) -> void:
	var x := 0.0
	while x < level_width:
		var remaining := level_width - x
		var segment_width := 0.0
		if x < 1.0:
			segment_width = 720.0
		elif remaining < 780.0:
			segment_width = remaining
		else:
			segment_width = rng.randf_range(480.0, 760.0)

		_create_platform(Vector2(x + segment_width * 0.5, 670), Vector2(segment_width, 100), theme["ground"], theme["top"])
		ground_segments.append({"start": x, "end": x + segment_width, "top": GROUND_TOP})
		x += segment_width

		if level_width - x > 720.0:
			var max_gap := 130.0 + min(current_level * 4.0, 40.0)
			var gap := rng.randf_range(88.0, max_gap)
			_create_hazard(Vector2(x + gap * 0.5, 735), Vector2(gap, 170), theme["hazard"])
			x += gap

func _build_elevated_platforms(theme: Dictionary) -> void:
	for segment_index in range(ground_segments.size()):
		var segment: Dictionary = ground_segments[segment_index]
		var start_x: float = segment["start"]
		var end_x: float = segment["end"]
		if segment_index == 0:
			start_x += 260.0
		var count := 2 + int(current_level >= 3) + int(current_level >= 7)
		for i in range(count):
			var px := lerp(start_x + 90.0, end_x - 90.0, float(i + 1) / float(count + 1))
			var py := 500.0 - float((i + segment_index) % 3) * 85.0
			var pw := rng.randf_range(120.0, 205.0)
			_create_platform(Vector2(px, py), Vector2(pw, 24), theme["ground"].lightened(0.08), theme["top"])
			_create_coin_arc(Vector2(px, py - 60.0), 3 + int(current_level >= 6), 34.0)

		if current_level >= 4 and segment_index > 0 and segment_index % 2 == 0:
			var mx := (start_x + end_x) * 0.5
			_create_moving_platform(Vector2(mx, 330), Vector2(150, 22), theme["ground"].lightened(0.15), theme["top"], 115.0 + current_level * 6.0)

func _place_level_objects(theme: Dictionary) -> void:
	for segment_index in range(ground_segments.size()):
		var segment: Dictionary = ground_segments[segment_index]
		var start_x: float = segment["start"]
		var end_x: float = segment["end"]
		var usable := end_x - start_x

		if segment_index > 0:
			var enemy_count := 1 + int(current_level >= 4 and segment_index % 2 == 0)
			for i in range(enemy_count):
				var ex := start_x + usable * float(i + 1) / float(enemy_count + 1)
				var flying := current_level >= 6 and (i + segment_index) % 4 == 0
				var texture_index := (current_level * 2 + segment_index + i) % max(enemy_textures.size(), 1)
				_create_enemy(Vector2(ex, 570 if not flying else 410), start_x + 40, end_x - 40, texture_index, flying, false)

		var ground_coin_count := 3 + int(current_level >= 5)
		for i in range(ground_coin_count):
			var cx := start_x + usable * float(i + 1) / float(ground_coin_count + 1)
			_create_coin(Vector2(cx, 570 - float(i % 2) * 28.0), 100)

	var checkpoint_segment := ground_segments[int(ground_segments.size() * 0.52)]
	var checkpoint_x := float(checkpoint_segment["start"]) + 90.0
	_create_checkpoint(Vector2(checkpoint_x, 550))

	if current_level >= 3:
		var bonus_segment := ground_segments[min(ground_segments.size() - 1, 1 + current_level / 2)]
		_create_bonus(Vector2(float(bonus_segment["start"]) + 160.0, 530))

	if current_level == 5 or current_level == 10:
		var final_segment := ground_segments[ground_segments.size() - 1]
		var boss_x := max(float(final_segment["start"]) + 180.0, level_width - 560.0)
		boss_alive = 1
		var boss_texture := (current_level * 3) % max(enemy_textures.size(), 1)
		_create_enemy(Vector2(boss_x, 550), boss_x - 210.0, boss_x + 210.0, boss_texture, false, true)

func _create_goal(theme: Dictionary) -> void:
	var goal_x := level_width - 145.0
	current_goal = Area2D.new()
	current_goal.name = "Goal"
	current_goal.position = Vector2(goal_x, 535)
	current_goal.collision_layer = 16
	current_goal.collision_mask = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(70, 170)
	shape.shape = rect
	current_goal.add_child(shape)

	var pole := Polygon2D.new()
	pole.polygon = PackedVector2Array([Vector2(-5, 85), Vector2(5, 85), Vector2(5, -85), Vector2(-5, -85)])
	pole.color = Color("#f0f2f4")
	current_goal.add_child(pole)

	var banner := Polygon2D.new()
	banner.position = Vector2(37, -60)
	banner.polygon = PackedVector2Array([Vector2(-35, -24), Vector2(35, -24), Vector2(18, 0), Vector2(35, 24), Vector2(-35, 24)])
	banner.color = theme["accent"]
	current_goal.add_child(banner)

	if friend_texture:
		var friend := Sprite2D.new()
		friend.texture = friend_texture
		friend.position = Vector2(-70, 38)
		_fit_sprite(friend, Vector2(72, 88))
		current_goal.add_child(friend)

	current_goal.body_entered.connect(_on_goal_body_entered)
	world.add_child(current_goal)

func _create_platform(pos: Vector2, size: Vector2, base_color: Color, top_color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)

	_create_visual_rect(body, Vector2.ZERO, size, base_color, 0)
	_create_visual_rect(body, Vector2(0, -size.y * 0.5 + 5), Vector2(size.x, 10), top_color, 1)

	for i in range(max(1, int(size.x / 90.0))):
		var mark := Polygon2D.new()
		mark.position = Vector2(-size.x * 0.45 + i * 88.0, rng.randf_range(-size.y * 0.28, size.y * 0.28))
		mark.polygon = _regular_polygon(rng.randf_range(3.0, 7.0), 6)
		mark.color = base_color.darkened(0.12)
		body.add_child(mark)

	world.add_child(body)

func _create_moving_platform(pos: Vector2, size: Vector2, base_color: Color, top_color: Color, distance: float) -> void:
	var body := AnimatableBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 1
	body.sync_to_physics = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	_create_visual_rect(body, Vector2.ZERO, size, base_color, 0)
	_create_visual_rect(body, Vector2(0, -size.y * 0.5 + 4), Vector2(size.x, 8), top_color, 1)
	world.add_child(body)

	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(body, "position", pos + Vector2(0, -distance), 1.8)
	tween.tween_property(body, "position", pos, 1.8)

func _create_enemy(pos: Vector2, patrol_left: float, patrol_right: float, texture_index: int, flying: bool, boss: bool) -> void:
	var enemy := CharacterBody2D.new()
	enemy.position = pos
	enemy.collision_layer = 2
	enemy.collision_mask = 1

	var size := Vector2(50, 50)
	if boss:
		size = Vector2(92, 92)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	enemy.add_child(shape)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	if enemy_textures.size() > 0:
		sprite.texture = enemy_textures[texture_index % enemy_textures.size()]
		_fit_sprite(sprite, Vector2(62, 66) if not boss else Vector2(128, 128))
	else:
		sprite.texture = _make_fallback_texture(Color("#d83b2f"), Vector2i(int(size.x), int(size.y)))
	enemy.add_child(sprite)

	var enemy_script := load("res://scripts/Enemy.gd")
	enemy.set_script(enemy_script)
	world.add_child(enemy)
	enemy.call("configure", patrol_left, patrol_right, 78.0 + current_level * 9.0, flying, boss, 3 if boss else 1)
	enemy.connect("defeated", Callable(self, "_on_enemy_defeated"))

func _create_coin(pos: Vector2, value: int) -> void:
	var coin := Area2D.new()
	coin.position = pos
	coin.collision_layer = 4
	coin.collision_mask = 1

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14
	shape.shape = circle
	coin.add_child(shape)

	var glow := Polygon2D.new()
	glow.polygon = _regular_polygon(18.0, 18)
	glow.color = Color(1.0, 0.8, 0.1, 0.3)
	coin.add_child(glow)

	var visual := Polygon2D.new()
	visual.polygon = _regular_polygon(12.0, 18)
	visual.color = Color("#ffd83d")
	coin.add_child(visual)

	var inner := Polygon2D.new()
	inner.polygon = _regular_polygon(6.0, 12)
	inner.color = Color("#fff2a6")
	coin.add_child(inner)

	coin.body_entered.connect(_on_coin_body_entered.bind(coin, value))
	world.add_child(coin)

	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(coin, "position", pos + Vector2(0, -10), 0.65)
	tween.tween_property(coin, "position", pos, 0.65)

func _create_coin_arc(center: Vector2, count: int, spacing: float) -> void:
	for i in range(count):
		var offset := (float(i) - float(count - 1) * 0.5) * spacing
		var y := -abs(offset) * 0.20
		_create_coin(center + Vector2(offset, y), 100)

func _create_bonus(pos: Vector2) -> void:
	var bonus := Area2D.new()
	bonus.position = pos
	bonus.collision_layer = 4
	bonus.collision_mask = 1

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20
	shape.shape = circle
	bonus.add_child(shape)

	var star := Polygon2D.new()
	star.polygon = _star_polygon(22.0, 10.0, 5)
	star.color = Color("#ffec66")
	bonus.add_child(star)
	bonus.body_entered.connect(_on_bonus_body_entered.bind(bonus))
	world.add_child(bonus)

	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(star, "rotation", TAU, 1.5).from(0.0)

func _create_checkpoint(pos: Vector2) -> void:
	var checkpoint := Area2D.new()
	checkpoint.position = pos
	checkpoint.collision_layer = 8
	checkpoint.collision_mask = 1
	checkpoint.set_meta("activated", false)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48, 130)
	shape.shape = rect
	checkpoint.add_child(shape)

	var pole := Polygon2D.new()
	pole.polygon = PackedVector2Array([Vector2(-4, 65), Vector2(4, 65), Vector2(4, -65), Vector2(-4, -65)])
	pole.color = Color("#c8d0d8")
	checkpoint.add_child(pole)

	var light := Polygon2D.new()
	light.name = "Light"
	light.position = Vector2(0, -52)
	light.polygon = _regular_polygon(14.0, 12)
	light.color = Color("#ffad32")
	checkpoint.add_child(light)

	checkpoint.body_entered.connect(_on_checkpoint_body_entered.bind(checkpoint))
	world.add_child(checkpoint)

func _create_hazard(pos: Vector2, size: Vector2, color: Color) -> void:
	var hazard := Area2D.new()
	hazard.position = pos
	hazard.collision_layer = 8
	hazard.collision_mask = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	hazard.add_child(shape)

	_create_visual_rect(hazard, Vector2.ZERO, size, color, -1)
	var spike_count := max(1, int(size.x / 24.0))
	for i in range(spike_count):
		var spike := Polygon2D.new()
		spike.position = Vector2(-size.x * 0.5 + 12 + i * 24, -size.y * 0.5)
		spike.polygon = PackedVector2Array([Vector2(-11, 0), Vector2(0, -22), Vector2(11, 0)])
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
	lives = min(lives + 1, 9)
	add_score(500)
	show_message("VIE BONUS !", 0.8)
	Input.vibrate_handheld(70)
	bonus.queue_free()
	update_hud()

func _on_checkpoint_body_entered(body: Node, checkpoint: Area2D) -> void:
	if body != player or bool(checkpoint.get_meta("activated", false)):
		return
	checkpoint.set_meta("activated", true)
	respawn_position = checkpoint.global_position + Vector2(55, 20)
	player.call("set_spawn", respawn_position)
	var light := checkpoint.get_node_or_null("Light") as Polygon2D
	if light:
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
		boss_alive = max(0, boss_alive - 1)
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
	if score > high_score:
		high_score = score
	update_hud()

func lose_life() -> void:
	if transitioning or not player or not is_instance_valid(player):
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
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(duration)
	tween.tween_property(message_label, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func():
		if message_label.text == text:
			message_label.text = ""
			message_label.modulate.a = 1.0
	)

func camera_shake(strength: float) -> void:
	if not camera:
		return
	var original := Vector2(120, -40)
	var tween := create_tween()
	for i in range(5):
		tween.tween_property(camera, "position", original + Vector2(rng.randf_range(-strength, strength), rng.randf_range(-strength, strength)), 0.035)
	tween.tween_property(camera, "position", original, 0.06)

func _create_mobile_controls() -> void:
	var left := _make_button("◀", Vector2(28, -150), Vector2(120, 120), false)
	left.button_down.connect(Callable(self, "_set_mobile_left").bind(true))
	left.button_up.connect(Callable(self, "_set_mobile_left").bind(false))
	ui_layer.add_child(left)

	var right := _make_button("▶", Vector2(162, -150), Vector2(120, 120), false)
	right.button_down.connect(Callable(self, "_set_mobile_right").bind(true))
	right.button_up.connect(Callable(self, "_set_mobile_right").bind(false))
	ui_layer.add_child(right)

	var jump := _make_button("SAUT", Vector2(-168, -160), Vector2(140, 130), true)
	jump.button_down.connect(_mobile_jump)
	ui_layer.add_child(jump)

	var pause_button := _make_button("II", Vector2(-78, 18), Vector2(60, 54), true, true)
	pause_button.pressed.connect(_toggle_pause)
	ui_layer.add_child(pause_button)

func _make_button(text: String, pos: Vector2, size: Vector2, right_anchor: bool, top_anchor: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size = size
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("#ffe36c"))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.04, 0.06, 0.10, 0.56)
	normal.border_color = Color(1, 1, 1, 0.42)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(28)
	var pressed_style := normal.duplicate()
	pressed_style.bg_color = Color(0.18, 0.55, 0.88, 0.78)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
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

	button.offset_left = pos.x
	button.offset_top = pos.y
	button.offset_right = pos.x + size.x
	button.offset_bottom = pos.y + size.y
	return button

func _set_mobile_left(pressed: bool) -> void:
	if player:
		player.call("set_mobile_left", pressed)

func _set_mobile_right(pressed: bool) -> void:
	if player:
		player.call("set_mobile_right", pressed)

func _mobile_jump() -> void:
	if player:
		player.call("request_jump")

func _toggle_pause() -> void:
	paused = not paused
	get_tree().paused = paused
	message_label.text = "PAUSE" if paused else ""
	message_label.modulate.a = 1.0

func _fit_sprite(sprite: Sprite2D, target_size: Vector2) -> void:
	if not sprite.texture:
		return
	var texture_size := sprite.texture.get_size()
	if texture_size.x <= 0 or texture_size.y <= 0:
		return
	var factor := min(target_size.x / texture_size.x, target_size.y / texture_size.y)
	sprite.scale = Vector2.ONE * factor

func _create_visual_rect(parent: Node, pos: Vector2, size: Vector2, color: Color, z: int) -> Polygon2D:
	var visual := Polygon2D.new()
	visual.position = pos
	visual.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5)
	])
	visual.color = color
	visual.z_index = z
	parent.add_child(visual)
	return visual

func _regular_polygon(radius: float, sides: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := TAU * float(i) / float(sides)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _star_polygon(outer_radius: float, inner_radius: float, points_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(points_count * 2):
		var radius := outer_radius if i % 2 == 0 else inner_radius
		var angle := -PI * 0.5 + TAU * float(i) / float(points_count * 2)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _make_fallback_texture(color: Color, size: Vector2i) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
