extends Control

signal vector_changed(value: Vector2)

@export var max_radius: float = 46.0
@export var deadzone: float = 0.055

var active_touch_index: int = -1
var mouse_active: bool = false
var active: bool = false
var resting_center: Vector2 = Vector2.ZERO
var dynamic_center: Vector2 = Vector2.ZERO
var knob_position: Vector2 = Vector2.ZERO
var current_vector: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	if resting_center == Vector2.ZERO:
		resting_center = size * 0.5
	dynamic_center = resting_center
	knob_position = resting_center
	queue_redraw()


func configure(radius: float, center_position: Vector2) -> void:
	max_radius = maxf(radius, 28.0)
	set_resting_center(center_position)


func set_resting_center(center_position: Vector2) -> void:
	resting_center = center_position
	if not active:
		dynamic_center = resting_center
		knob_position = resting_center
	queue_redraw()


func reset() -> void:
	active_touch_index = -1
	mouse_active = false
	active = false
	dynamic_center = resting_center
	knob_position = resting_center
	_set_vector(Vector2.ZERO)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and active_touch_index == -1:
			active_touch_index = touch.index
			_begin_control(touch.position)
			accept_event()
		elif not touch.pressed and touch.index == active_touch_index:
			reset()
			accept_event()
		return

	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == active_touch_index:
			_update_from_position(drag.position)
			accept_event()
		return

	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed and not mouse_active and active_touch_index == -1:
				mouse_active = true
				_begin_control(button.position)
			elif not button.pressed and mouse_active:
				reset()
			accept_event()
		return

	if event is InputEventMouseMotion and mouse_active:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_update_from_position(motion.position)
		accept_event()


func _begin_control(local_position: Vector2) -> void:
	active = true
	dynamic_center = _clamp_center(local_position)
	knob_position = dynamic_center
	_set_vector(Vector2.ZERO)
	queue_redraw()


func _update_from_position(local_position: Vector2) -> void:
	if not active:
		return

	var delta_from_center: Vector2 = local_position - dynamic_center
	var distance: float = delta_from_center.length()

	if distance > max_radius * 1.45 and distance > 0.0:
		var center_shift: float = distance - max_radius * 1.45
		dynamic_center = _clamp_center(dynamic_center + delta_from_center.normalized() * center_shift * 0.72)
		delta_from_center = local_position - dynamic_center
		distance = delta_from_center.length()

	var clamped_delta: Vector2 = delta_from_center
	if distance > max_radius and distance > 0.0:
		clamped_delta = delta_from_center / distance * max_radius

	knob_position = dynamic_center + clamped_delta
	var raw_vector: Vector2 = clamped_delta / max_radius
	var magnitude: float = raw_vector.length()
	if magnitude <= deadzone:
		_set_vector(Vector2.ZERO)
	else:
		var linear_magnitude: float = clampf((magnitude - deadzone) / (1.0 - deadzone), 0.0, 1.0)
		var responsive_magnitude: float = pow(linear_magnitude, 0.72)
		_set_vector(raw_vector.normalized() * responsive_magnitude)
	queue_redraw()


func _clamp_center(local_position: Vector2) -> Vector2:
	var padding: float = max_radius + 6.0
	return Vector2(
		clampf(local_position.x, padding, maxf(padding, size.x - padding)),
		clampf(local_position.y, padding, maxf(padding, size.y - padding))
	)


func _set_vector(value: Vector2) -> void:
	var limited: Vector2 = value.limit_length(1.0)
	if limited.distance_squared_to(current_vector) < 0.000004:
		return
	current_vector = limited
	vector_changed.emit(current_vector)


func _draw() -> void:
	var base_center: Vector2 = dynamic_center if active else resting_center
	var base_alpha: float = 0.78 if active else 0.36
	var knob_alpha: float = 1.0 if active else 0.52

	draw_circle(base_center, max_radius, Color(0.07, 0.22, 0.38, base_alpha))
	draw_arc(base_center, max_radius, 0.0, TAU, 48, Color(0.55, 0.86, 1.0, base_alpha), 3.0, true)
	draw_circle(base_center, max_radius * deadzone, Color(0.2, 0.65, 0.95, 0.18))
	draw_circle(knob_position, max_radius * 0.46, Color(0.18, 0.58, 0.9, knob_alpha))
	draw_arc(knob_position, max_radius * 0.46, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, knob_alpha), 3.0, true)
