extends Node

const GAME_HEIGHT_RATIO: float = 0.70
const CONTROL_HEIGHT_RATIO: float = 0.30

var main_scene: Node
var ui_layer: CanvasLayer
var control_panel: ColorRect
var control_title: Label
var touch_buttons: Dictionary = {}
var configured: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_input_action("pause_game")
	get_tree().node_added.connect(_on_node_added)
	get_viewport().size_changed.connect(_layout_interface)
	call_deferred("_try_configure_current_scene")


func _process(_delta: float) -> void:
	if configured and Input.is_action_just_pressed("pause_game"):
		_toggle_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_all_mobile_actions()


func _on_node_added(node: Node) -> void:
	if node.name == "Main":
		call_deferred("_configure_scene", node)


func _try_configure_current_scene() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null and scene.name == "Main":
		_configure_scene(scene)


func _configure_scene(scene: Node) -> void:
	if scene == null or not is_instance_valid(scene):
		return

	var found_ui: CanvasLayer = scene.get_node_or_null("UI") as CanvasLayer
	if found_ui == null:
		call_deferred("_configure_scene", scene)
		return

	main_scene = scene
	ui_layer = found_ui
	_remove_old_buttons()
	_create_control_panel()
	_create_touch_controls()
	_configure_camera()
	configured = true
	_layout_interface()
	_release_old_mobile_flags()


func _remove_old_buttons() -> void:
	if ui_layer == null:
		return
	for child in ui_layer.get_children():
		if child is Button or child is TouchScreenButton or child.name == "MobileControlPanel":
			child.queue_free()


func _create_control_panel() -> void:
	control_panel = ColorRect.new()
	control_panel.name = "MobileControlPanel"
	control_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	control_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	control_panel.color = Color("#090f1d")
	control_panel.anchor_left = 0.0
	control_panel.anchor_top = GAME_HEIGHT_RATIO
	control_panel.anchor_right = 1.0
	control_panel.anchor_bottom = 1.0
	control_panel.offset_left = 0.0
	control_panel.offset_top = 0.0
	control_panel.offset_right = 0.0
	control_panel.offset_bottom = 0.0
	ui_layer.add_child(control_panel)

	var separator: ColorRect = ColorRect.new()
	separator.name = "Separator"
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	separator.color = Color("#35a9ff")
	separator.anchor_left = 0.0
	separator.anchor_top = 0.0
	separator.anchor_right = 1.0
	separator.anchor_bottom = 0.0
	separator.offset_left = 0.0
	separator.offset_top = 0.0
	separator.offset_right = 0.0
	separator.offset_bottom = 5.0
	control_panel.add_child(separator)

	control_title = Label.new()
	control_title.name = "ControlTitle"
	control_title.text = "COMMANDES"
	control_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	control_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control_title.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0, 0.75))
	control_title.add_theme_font_size_override("font_size", 20)
	control_panel.add_child(control_title)


func _create_touch_controls() -> void:
	if ui_layer == null:
		return

	touch_buttons.clear()
	touch_buttons["left"] = _make_touch_button("MoveLeft", "move_left", "◀", 160, Color("#1b3d63"), Color("#2d8ed8"))
	touch_buttons["right"] = _make_touch_button("MoveRight", "move_right", "▶", 160, Color("#1b3d63"), Color("#2d8ed8"))
	touch_buttons["jump"] = _make_touch_button("Jump", "jump", "SAUT", 184, Color("#693c16"), Color("#e38b26"))
	touch_buttons["pause"] = _make_touch_button("Pause", "pause_game", "II", 104, Color("#303743"), Color("#68788c"))

	for key in touch_buttons:
		ui_layer.add_child(touch_buttons[key])


func _make_touch_button(node_name: String, action_name: StringName, text_value: String, diameter: int, normal_color: Color, pressed_color: Color) -> TouchScreenButton:
	var button: TouchScreenButton = TouchScreenButton.new()
	button.name = node_name
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.action = action_name
	button.passby_press = true
	button.texture_normal = _make_circle_texture(diameter, normal_color, Color(1.0, 1.0, 1.0, 0.42), 5)
	button.texture_pressed = _make_circle_texture(diameter, pressed_color, Color(1.0, 0.92, 0.48, 0.95), 7)

	var touch_shape: CircleShape2D = CircleShape2D.new()
	touch_shape.radius = float(diameter) * 0.5
	button.shape = touch_shape

	var label: Label = Label.new()
	label.name = "Label"
	label.text = text_value
	label.position = Vector2(-float(diameter) * 0.5, -30.0)
	label.size = Vector2(float(diameter), 60.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_font_size_override("font_size", 31 if text_value != "SAUT" else 25)
	button.add_child(label)
	return button


func _make_circle_texture(diameter: int, fill_color: Color, border_color: Color, border_width: int) -> Texture2D:
	var image: Image = Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var radius: float = float(diameter) * 0.5 - 1.0
	var center: Vector2 = Vector2(float(diameter - 1) * 0.5, float(diameter - 1) * 0.5)
	var inner_radius: float = radius - float(border_width)

	for y in range(diameter):
		for x in range(diameter):
			var distance: float = Vector2(float(x), float(y)).distance_to(center)
			if distance <= radius:
				image.set_pixel(x, y, border_color if distance >= inner_radius else fill_color)

	return ImageTexture.create_from_image(image)


func _layout_interface() -> void:
	if not configured or main_scene == null or not is_instance_valid(main_scene):
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var panel_top: float = viewport_size.y * GAME_HEIGHT_RATIO
	var panel_height: float = viewport_size.y * CONTROL_HEIGHT_RATIO
	var common_y: float = panel_top + panel_height * 0.62

	_layout_touch_button("left", Vector2(viewport_size.x * 0.16, common_y), clampf(panel_height / 400.0, 0.82, 1.15))
	_layout_touch_button("right", Vector2(viewport_size.x * 0.39, common_y), clampf(panel_height / 400.0, 0.82, 1.15))
	_layout_touch_button("jump", Vector2(viewport_size.x * 0.82, common_y), clampf(panel_height / 400.0, 0.82, 1.15))
	_layout_touch_button("pause", Vector2(viewport_size.x * 0.60, panel_top + panel_height * 0.28), clampf(panel_height / 400.0, 0.82, 1.08))

	if control_title != null:
		control_title.position = Vector2(viewport_size.x * 0.35, 14.0)
		control_title.size = Vector2(viewport_size.x * 0.30, 42.0)

	_layout_hud(viewport_size)
	_configure_camera()


func _layout_touch_button(key: String, center_position: Vector2, scale_value: float) -> void:
	var button: TouchScreenButton = touch_buttons.get(key) as TouchScreenButton
	if button == null:
		return
	button.position = center_position
	button.scale = Vector2.ONE * scale_value


func _layout_hud(viewport_size: Vector2) -> void:
	if main_scene == null:
		return

	var font_size: int = clampi(int(viewport_size.x / 30.0), 18, 25)
	var side_width: float = minf(245.0, viewport_size.x * 0.43)

	var score_label: Label = main_scene.get_node_or_null("UI/HUD/ScoreLabel") as Label
	var lives_label: Label = main_scene.get_node_or_null("UI/HUD/LivesLabel") as Label
	var coin_label: Label = main_scene.get_node_or_null("UI/HUD/CoinLabel") as Label
	var level_label: Label = main_scene.get_node_or_null("UI/HUD/LevelLabel") as Label
	var high_label: Label = main_scene.get_node_or_null("UI/HUD/HighLabel") as Label
	var progress_bar: ProgressBar = main_scene.get_node_or_null("UI/HUD/ProgressBar") as ProgressBar
	var message_label: Label = main_scene.get_node_or_null("UI/HUD/MessageLabel") as Label

	if score_label != null:
		score_label.offset_left = 14.0
		score_label.offset_right = side_width
		score_label.add_theme_font_size_override("font_size", font_size)
	if lives_label != null:
		lives_label.offset_left = 14.0
		lives_label.offset_right = side_width
		lives_label.add_theme_font_size_override("font_size", font_size - 1)
	if coin_label != null:
		coin_label.offset_left = 14.0
		coin_label.offset_right = side_width
		coin_label.add_theme_font_size_override("font_size", font_size - 1)
	if level_label != null:
		level_label.offset_left = -side_width
		level_label.offset_right = -14.0
		level_label.add_theme_font_size_override("font_size", font_size)
	if high_label != null:
		high_label.offset_left = -side_width
		high_label.offset_right = -14.0
		high_label.add_theme_font_size_override("font_size", font_size - 2)
	if progress_bar != null:
		progress_bar.offset_left = viewport_size.x * 0.34
		progress_bar.offset_right = -viewport_size.x * 0.34
	if message_label != null:
		var half_width: float = viewport_size.x * 0.43
		message_label.offset_left = -half_width
		message_label.offset_right = half_width
		message_label.add_theme_font_size_override("font_size", clampi(font_size + 10, 30, 42))


func _configure_camera() -> void:
	if main_scene == null or not is_instance_valid(main_scene):
		return

	var camera: Camera2D = main_scene.get("camera") as Camera2D
	if camera == null:
		return

	camera.position = Vector2(120.0, -40.0)
	camera.zoom = Vector2(0.95, 0.95)
	camera.position_smoothing_enabled = false
	camera.drag_horizontal_enabled = true
	camera.drag_vertical_enabled = true
	camera.drag_left_margin = 0.28
	camera.drag_right_margin = 0.34
	camera.drag_top_margin = 0.32
	camera.drag_bottom_margin = 0.24
	camera.reset_smoothing()


func _toggle_pause() -> void:
	if main_scene == null or not is_instance_valid(main_scene):
		return

	var next_paused: bool = not get_tree().paused
	get_tree().paused = next_paused
	main_scene.set("paused", next_paused)
	var message_label: Label = main_scene.get_node_or_null("UI/HUD/MessageLabel") as Label
	if message_label != null:
		message_label.text = "PAUSE" if next_paused else ""
		message_label.modulate.a = 1.0


func _release_old_mobile_flags() -> void:
	if main_scene == null:
		return
	var player: CharacterBody2D = main_scene.get("player") as CharacterBody2D
	if player != null:
		player.call("set_mobile_left", false)
		player.call("set_mobile_right", false)


func _release_all_mobile_actions() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("pause_game")
	_release_old_mobile_flags()


func _ensure_input_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
