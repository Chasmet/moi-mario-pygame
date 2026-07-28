extends Control

signal jump_pressed
signal jump_released

@export var button_radius: float = 48.0

var active_touch_index: int = -1
var mouse_active: bool = false
var active: bool = false
var resting_center: Vector2 = Vector2.ZERO
var button_center: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	if resting_center == Vector2.ZERO:
		resting_center = size * 0.5
	button_center = resting_center
	queue_redraw()


func configure(radius: float, center_position: Vector2) -> void:
	button_radius = maxf(radius, 34.0)
	resting_center = center_position
	if not active:
		button_center = resting_center
	queue_redraw()


func reset() -> void:
	var was_active: bool = active
	active_touch_index = -1
	mouse_active = false
	active = false
	button_center = resting_center
	if was_active:
		jump_released.emit()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and active_touch_index == -1:
			active_touch_index = touch.index
			_begin_jump(touch.position)
			accept_event()
		elif not touch.pressed and touch.index == active_touch_index:
			reset()
			accept_event()
		return

	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == active_touch_index:
			button_center = _clamp_center(drag.position)
			queue_redraw()
			accept_event()
		return

	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed and not mouse_active and active_touch_index == -1:
				mouse_active = true
				_begin_jump(button.position)
			elif not button.pressed and mouse_active:
				reset()
			accept_event()
		return

	if event is InputEventMouseMotion and mouse_active:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		button_center = _clamp_center(motion.position)
		queue_redraw()
		accept_event()


func _begin_jump(local_position: Vector2) -> void:
	active = true
	button_center = _clamp_center(local_position)
	jump_pressed.emit()
	queue_redraw()


func _clamp_center(local_position: Vector2) -> Vector2:
	var padding: float = button_radius + 4.0
	return Vector2(
		clampf(local_position.x, padding, maxf(padding, size.x - padding)),
		clampf(local_position.y, padding, maxf(padding, size.y - padding))
	)


func _draw() -> void:
	var center: Vector2 = button_center if active else resting_center
	var outer_alpha: float = 0.98 if active else 0.48
	var inner_alpha: float = 0.98 if active else 0.68
	var pulse_radius: float = button_radius * (1.08 if active else 1.0)

	draw_circle(center, pulse_radius, Color(0.48, 0.22, 0.05, outer_alpha))
	draw_arc(center, pulse_radius, 0.0, TAU, 48, Color(1.0, 0.78, 0.35, outer_alpha), 4.0, true)
	draw_circle(center, button_radius * 0.72, Color(0.95, 0.43, 0.08, inner_alpha))

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 18
	var text: String = "SAUT"
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var text_position: Vector2 = center - Vector2(text_size.x * 0.5, -text_size.y * 0.34)
	draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)
