extends Node2D

@onready var score_label: Label = $UI/HUD/ScoreLabel
@onready var lives_label: Label = $UI/HUD/LivesLabel
@onready var level_label: Label = $UI/HUD/LevelLabel
@onready var message_label: Label = $UI/HUD/MessageLabel
@onready var world: Node2D = $World

var score: int = 0
var lives: int = 3
var current_level: int = 1
const MAX_LEVEL: int = 10

var player: CharacterBody2D
var camera: Camera2D

func _ready() -> void:
	randomize()
	create_player()
	update_hud()
	load_level(current_level)

func create_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.collision_layer = 1
	player.collision_mask = 1

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(40, 64)
	shape.shape = rect
	player.add_child(shape)

	var sprite = Sprite2D.new()
	var tex = load("res://player.png")
	if tex:
		sprite.texture = tex
		sprite.scale = Vector2(0.12, 0.12)
	else:
		var fallback = ColorRect.new()
		fallback.size = Vector2(40, 64)
		fallback.position = Vector2(-20, -32)
		fallback.color = Color(0.0, 0.65, 1.0)
		player.add_child(fallback)
	player.add_child(sprite)

	var script = load("res://scripts/Player.gd")
	if script:
		player.set_script(script)

	camera = Camera2D.new()
	camera.position = Vector2(0, -60)
	camera.zoom = Vector2(1.15, 1.15)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0
	camera.limit_left = 0
	camera.limit_top = -300
	camera.limit_bottom = 900
	player.add_child(camera)

	world.add_child(player)
	player.global_position = Vector2(120, 400)

func update_hud() -> void:
	score_label.text = "SCORE %d" % score
	lives_label.text = "VIES %d" % lives
	level_label.text = "NIVEAU %d" % current_level

func add_score(points: int) -> void:
	score += points
	update_hud()

func lose_life() -> void:
	lives -= 1
	update_hud()
	if lives <= 0:
		show_message("GAME OVER")
		await get_tree().create_timer(2.0).timeout
		restart_game()
	else:
		player.global_position = Vector2(120, 400)
		player.velocity = Vector2.ZERO

func next_level() -> void:
	current_level += 1
	if current_level > MAX_LEVEL:
		show_message("VICTOIRE ! 10 NIVEAUX")
		await get_tree().create_timer(3.0).timeout
		restart_game()
	else:
		show_message("NIVEAU %d" % current_level)
		await get_tree().create_timer(1.2).timeout
		message_label.text = ""
		update_hud()
		load_level(current_level)

func show_message(text: String) -> void:
	message_label.text = text

func restart_game() -> void:
	lives = 3
	score = 0
	current_level = 1
	message_label.text = ""
	update_hud()
	load_level(1)

func clear_level() -> void:
	for child in world.get_children():
		if child.name != "Player":
			child.queue_free()

func load_level(level: int) -> void:
	clear_level()
	await get_tree().process_frame

	var level_width = 2800 + level * 350

	# Sol principal
	create_platform(Vector2(level_width / 2.0, 650), Vector2(level_width + 200, 100), Color(0.45, 0.28, 0.12))

	# Plateformes
	var platform_count = 7 + level
	for i in range(platform_count):
		var px = 280.0 + i * (160.0 + level * 8)
		var py = 480.0 - (i % 5) * 70.0 - randi() % 50
		var pw = 110.0 + randi() % 70
		create_platform(Vector2(px, py), Vector2(pw, 22), Color(0.55, 0.35, 0.18))

	# Ennemis
	var enemy_count = 3 + level
	for i in range(enemy_count):
		var ex = 450.0 + i * (220.0 + level * 15)
		create_enemy(Vector2(ex, 580))

	# Pièces
	var coin_count = 8 + level * 2
	for i in range(coin_count):
		var cx = 220.0 + i * 130.0
		var cy = 320.0 - (i % 4) * 55.0
		create_coin(Vector2(cx, cy))

	# Drapeau de fin
	create_flag(Vector2(level_width - 150, 520))

	# Reset joueur
	if player:
		player.global_position = Vector2(120, 400)
		player.velocity = Vector2.ZERO
		if camera:
			camera.limit_right = int(level_width)

func create_platform(pos: Vector2, size: Vector2, color: Color) -> void:
	var body = StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 1

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)

	var visual = ColorRect.new()
	visual.size = size
	visual.position = -size / 2.0
	visual.color = color
	body.add_child(visual)

	# Bordure verte en haut
	var top = ColorRect.new()
	top.size = Vector2(size.x, 6)
	top.position = Vector2(-size.x / 2.0, -size.y / 2.0)
	top.color = Color(0.3, 0.7, 0.25)
	body.add_child(top)

	world.add_child(body)

func create_enemy(pos: Vector2) -> void:
	var enemy = CharacterBody2D.new()
	enemy.position = pos
	enemy.collision_layer = 2
	enemy.collision_mask = 1

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 22
	shape.shape = circle
	enemy.add_child(shape)

	var visual = ColorRect.new()
	visual.size = Vector2(44, 44)
	visual.position = Vector2(-22, -22)
	visual.color = Color(0.75, 0.2, 0.15)
	enemy.add_child(visual)

	var eyes = ColorRect.new()
	eyes.size = Vector2(28, 12)
	eyes.position = Vector2(-14, -10)
	eyes.color = Color(1, 1, 1)
	enemy.add_child(eyes)

	var script = load("res://scripts/Enemy.gd")
	if script:
		enemy.set_script(script)

	world.add_child(enemy)

func create_coin(pos: Vector2) -> void:
	var coin = Area2D.new()
	coin.position = pos
	coin.collision_layer = 4
	coin.collision_mask = 1

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12
	shape.shape = circle
	coin.add_child(shape)

	var visual = ColorRect.new()
	visual.size = Vector2(24, 24)
	visual.position = Vector2(-12, -12)
	visual.color = Color(1.0, 0.85, 0.1)
	coin.add_child(visual)

	coin.body_entered.connect(func(body):
		if body == player:
			add_score(100)
			coin.queue_free()
	)

	world.add_child(coin)

func create_flag(pos: Vector2) -> void:
	var flag = Area2D.new()
	flag.position = pos
	flag.collision_layer = 8
	flag.collision_mask = 1

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(30, 100)
	shape.shape = rect
	flag.add_child(shape)

	var pole = ColorRect.new()
	pole.size = Vector2(10, 100)
	pole.position = Vector2(-5, -50)
	pole.color = Color(0.15, 0.5, 0.2)
	flag.add_child(pole)

	var banner = ColorRect.new()
	banner.size = Vector2(40, 28)
	banner.position = Vector2(5, -50)
	banner.color = Color(1.0, 0.15, 0.2)
	flag.add_child(banner)

	flag.body_entered.connect(func(body):
		if body == player:
			add_score(1000)
			next_level()
	)

	world.add_child(flag)
