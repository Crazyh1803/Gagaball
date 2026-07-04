class_name VirtualJoystick
extends Control
## Floating touch joystick occupying the left half of the screen (per PRD).
## It presses the same move_* input actions the keyboard uses, so
## PlayerCharacter needs no touch-specific code and desktop testing keeps
## working. The stick appears wherever the finger lands, arcade-style.
##
## Uses _input() with a rect check (not _gui_input) so multitouch keeps
## working when the future strike/dash buttons land on the right side.

@export var radius := 100.0
@export var knob_radius := 42.0

var _touch_index := -1
var _center := Vector2.ZERO
var _output := Vector2.ZERO

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and get_global_rect().has_point(event.position):
				_touch_index = event.index
				_center = event.position - global_position
				_update_stick(event.position - global_position)
		elif event.index == _touch_index:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_stick(event.position - global_position)

func _update_stick(local_pos: Vector2) -> void:
	_output = (local_pos - _center).limit_length(radius) / radius
	_press_axis(&"move_left", &"move_right", _output.x)
	_press_axis(&"move_up", &"move_down", _output.y)
	queue_redraw()

func _release() -> void:
	_touch_index = -1
	_output = Vector2.ZERO
	for action in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	queue_redraw()

func _press_axis(negative: StringName, positive: StringName, value: float) -> void:
	if value > 0.0:
		Input.action_release(negative)
		Input.action_press(positive, value)
	elif value < 0.0:
		Input.action_release(positive)
		Input.action_press(negative, -value)
	else:
		Input.action_release(negative)
		Input.action_release(positive)

func _draw() -> void:
	var active := _touch_index != -1
	var base_pos := _center if active else Vector2(size.x * 0.5, size.y * 0.68)
	var alpha := 0.4 if active else 0.15
	draw_arc(base_pos, radius, 0.0, TAU, 48, Color(1, 1, 1, alpha), 4.0)
	draw_circle(base_pos + _output * radius, knob_radius, Color(1, 1, 1, alpha))
