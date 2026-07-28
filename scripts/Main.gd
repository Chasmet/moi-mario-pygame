extends Node2D

@onready var score_label = $UI/HUD/ScoreLabel
@onready var lives_label = $UI/HUD/LivesLabel
@onready var level_label = $UI/HUD/LevelLabel
@onready var player = $World/Player

var score := 0
var lives := 3
var current_level := 1
const MAX_LEVEL := 10

func _ready():
	update_hud()
	load_level(current_level)

func update_hud():
	score_label.text = "SCORE %d" % score
	lives_label.text = "VIES %d" % lives
	level_label.text = "NIVEAU %d" % current_level

func add_score(points: int):
	score += points
	update_hud()

func lose_life():
	lives -= 1
	update_hud()
	if lives <= 0:
		game_over()
	else:
		# Respawn player
		player.global_position = Vector2(100, 400)
		player.velocity = Vector2.ZERO

func next_level():
	current_level += 1
	if current_level > MAX_LEVEL:
		win_game()
	else:
		update_hud()
		load_level(current_level)

func load_level(level: int):
	# Clear old platforms / enemies
	for child in $World.get_children():
		if child.name.begins_with("Platform") or child.name.begins_with("Enemy") or child.name.begins_with("Coin") or child.name.begins_with("Flag"):
			child.queue_free()

	# Simple procedural level based on level number
	var ground = create_platform(Vector2(0, 600), Vector2(3000 + level * 400, 80))
	ground.name = "Platform_Ground"

	# Platforms
	var base_x = 200
	for i in range(8 + level):
		var px = base_x + i * (180 + level * 10)
		var py = 480 - (i % 4) * 80 - randi() % 40
		var p = create_platform(Vector2(px, py), Vector2(120 + randi() % 60, 24))
		p.name = "Platform_%d" % i

	# Enemies
	for i in range(3 + level):
		var ex = 400 + i * (250 + level * 20)
		var enemy = create_enemy(Vector2(ex, 540))
		enemy.name = "Enemy_%d" % i

	# Coins
	for i in range(6 + level * 2):
		var cx = 250 + i * 140
		var cy = 350 - (i % 3) * 60
		var coin = create_coin(Vector2(cx, cy))
		coin.name = "Coin_%d" % i

	# Flag at the end
	var flag = create_flag(Vector2(2800 + level * 350, 500))
	flag.name = "Flag"

	# Reset player position
	player.global_position = Vector2(100, 400)
	player.velocity = Vector2.ZERO

func create_platform(pos: Vector2, size: Vector2) -> StaticBody2D:
	var body = StaticBody2D.new()
	body.position = pos
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var visual = ColorRect.new()
	visual.size = size
	visual.position = -size / 2
	visual.color = Color(0.6, 0.4, 0.2)
	body.add_child(visual)
	$World.add_child(body)
	return body

func create_enemy(pos: Vector2) -> CharacterBody2D:
	var enemy = CharacterBody2D.new()
	enemy.position = pos
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 24
	shape.shape = circle
	enemy.add_child(shape)
	var visual = ColorRect.new()
	visual.size = Vector2(48, 48)
	visual.position = Vector2(-24, -24)
	visual.color = Color(0.7, 0.2, 0.15)
	enemy.add_child(visual)
	# Simple movement script
	var script = load("res://scripts/Enemy.gd")
	if script:
		enemy.set_script(script)
	$World.add_child(enemy)
	return enemy

func create_coin(pos: Vector2) -> Area2D:
	var coin = Area2D.new()
	coin.position = pos
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 14
	shape.shape = circle
	coin.add_child(shape)
	var visual = ColorRect.new()
	visual.size = Vector2(28, 28)
	visual.position = Vector2(-14, -14)
	visual.color = Color(1.0, 0.85, 0.1)
	coin.add_child(visual)
	coin.body_entered.connect(_on_coin_collected.bind(coin))
	$World.add_child(coin)
	return coin

func create_flag(pos: Vector2) -> Area2D:
	var flag = Area2D.new()
	flag.position = pos
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(40, 120)
	shape.shape = rect
	flag.add_child(shape)
	var visual = ColorRect.new()
	visual.size = Vector2(20, 120)
	visual.position = Vector2(-10, -60)
	visual.color = Color(0.1, 0.7, 0.2)
	flag.add_child(visual)
	flag.body_entered.connect(_on_flag_reached)
	$World.add_child(flag)
	return flag

func _on_coin_collected(body, coin):
	if body == player:
		add_score(100)
		coin.queue_free()

func _on_flag_reached(body):
	if body == player:
		add_score(1000)
		next_level()

func game_over():
	print("GAME OVER - Score final: ", score)
	# Simple restart
	lives = 3
	score = 0
	current_level = 1
	update_hud()
	load_level(1)

func win_game():
	print("VICTOIRE ! CHK NOIR a terminé les 10 niveaux !")
	lives = 3
	score = 0
	current_level = 1
	update_hud()
	load_level(1)
