extends Node

const GAME_HEIGHT_RATIO: float = 0.89
const CONTROL_HEIGHT_RATIO: float = 0.11
const DYNAMIC_JUMP_SCRIPT: Script = preload("res://scripts/DynamicJumpButton.gd")

var main_scene: Node
var ui_layer: CanvasLayer
var dynamic_jump: Control
var configured: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	get_viewport().size_changed.connect(_layout_controls)
	call_deferred("_try_configure_current_scene")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_jump()
		if dynamic_jump != null and is_instance_valid(dynamic_jump) and dynamic_jump.has_method("reset"):
			dynamic_jump.call("reset")


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
	if configured and main_scene == scene:
		return

	var found_ui: CanvasLayer = scene.get_node_or_null("UI") as CanvasLayer
	if found_ui == null:
		call_deferred("_configure_scene", scene)
		return

	main_scene = scene
	ui_layer = found_ui
	call_deferred("_install_responsive_controls")


func _install_responsive_controls() -> void:
	if ui_layer == null or not is_instance_valid(ui_layer):
		return

	_remove_old_jump_button()
	_create_dynamic_jump()
	_tune_movement_joystick()
	configured = true
	_layout_controls()


func _remove_old_jump_button() -> void:
	for child in ui_layer.get_children():
		if child.name == "Jump" or child.name == "DynamicJump":
			child.set_process(false)
			child.set_physics_process(false)
			if child is CanvasItem:
				(child as CanvasItem).visible = false
			child.queue_free()


func _create_dynamic_jump() -> void:
	dynamic_jump = Control.new()
	dynamic_jump.name = "DynamicJump"
	dynamic_jump.set_script(DYNAMIC_JUMP_SCRIPT)
	dynamic_jump.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(dynamic_jump)
	dynamic_jump.connect("jump_pressed", Callable(self, "_on_jump_pressed"))
	dynamic_jump.connect("jump_released", Callable(self, "_on_jump_released"))


func _layout_controls() -> void:
	if not configured or dynamic_jump == null or not is_instance_valid(dynamic_jump):
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var panel_top: float = viewport_size.y * GAME_HEIGHT_RATIO
	var panel_height: float = viewport_size.y * CONTROL_HEIGHT_RATIO
	var zone_left: float = viewport_size.x * 0.56
	var zone_right: float = viewport_size.x * 0.89
	var zone_width: float = zone_right - zone_left
	var radius: float = clampf(panel_height * 0.32, 38.0, 50.0)

	dynamic_jump.position = Vector2(zone_left, panel_top)
	dynamic_jump.size = Vector2(zone_width, panel_height)
	dynamic_jump.call("configure", radius, Vector2(zone_width * 0.56, panel_height * 0.52))
	_tune_movement_joystick()


func _tune_movement_joystick() -> void:
	if ui_layer == null:
		return
	var joystick: Control = ui_layer.get_node_or_null("MoveJoystick") as Control
	if joystick == null:
		call_deferred("_tune_movement_joystick")
		return
	joystick.set("deadzone", 0.055)


func _on_jump_pressed() -> void:
	Input.action_press("jump", 1.0)
	var player: CharacterBody2D = _get_player()
	if player != null and player.has_method("request_jump"):
		player.call("request_jump")


func _on_jump_released() -> void:
	_release_jump()


func _release_jump() -> void:
	Input.action_release("jump")


func _get_player() -> CharacterBody2D:
	if main_scene == null or not is_instance_valid(main_scene):
		return null
	return main_scene.get("player") as CharacterBody2D
