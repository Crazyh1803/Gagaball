class_name PlayerCharacter
extends Character
var _mouse_aim := false
var _strike_pressed := false
var _strike_released := false

func _input(event: InputEvent) -> void:
	# Keep both edges of a very short tap even when they arrive between
	# physics frames. Polling only just_pressed can lose the release.
	if event.is_action_pressed(&"strike"):
		_strike_pressed = true
	if event.is_action_released(&"strike"):
		_strike_released = true
	if event is InputEventMouseMotion and event.relative.length_squared() > 4.0:
		_mouse_aim = true
	elif event is InputEventKey and event.pressed and (
			event.is_action("move_left") or event.is_action("move_right")
			or event.is_action("move_up") or event.is_action("move_down")):
		_mouse_aim = false
	elif event is InputEventScreenTouch:
		_mouse_aim = false

func get_aim_direction(input_dir: Vector2) -> Vector2:
	if _mouse_aim:
		var offset := get_global_mouse_position() - global_position
		if offset.length_squared() > 4.0:
			return offset.normalized()
	return super(input_dir)
## Human-controlled character. Reads the input map, which is fed by the
## keyboard (WASD/arrows, Space, Shift) and by the on-screen touch controls —
## both press the same actions, so this script never needs touch-specific code.

func get_move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func handle_actions(delta: float) -> void:
	if Input.is_action_just_pressed(&"dash"):
		start_dash()
	if _strike_pressed or Input.is_action_just_pressed(&"strike"):
		begin_charge()
	if is_charging():
		if _strike_released or Input.is_action_just_released(&"strike"):
			release_strike()
		else:
			set_charge(charge_ratio + delta / charge_time)
	clear_strike_input()

func clear_strike_input() -> void:
	_strike_pressed = false
	_strike_released = false
