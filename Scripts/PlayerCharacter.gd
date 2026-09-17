class_name PlayerCharacter
extends Character
var _mouse_aim := false
var _strike_pressed := false
var _strike_released := false
var _jump_pressed := false
var _dash_pressed := false
var _control_pressed := false

func _input(event: InputEvent) -> void:
	if get_tree().paused or not is_alive:
		return
	var arena := get_parent()
	if arena.get("_round_over") == true or arena.get("_round_started") == false:
		return
	# Touch-generated mouse clicks must not slap when moving the touch stick.
	if event is InputEventMouse and event.device == -1:
		return
	if event.is_action_pressed(&"jump"):
		_jump_pressed = true
	if event.is_action_pressed(&"dash"):
		_dash_pressed = true
	if event.is_action_pressed(&"control_ball"):
		_control_pressed = true
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
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.22):
		_mouse_aim = false

func get_aim_direction(input_dir: Vector2) -> Vector2:
	var stick := Input.get_vector("aim_left","aim_right","aim_up","aim_down",0.22)
	if not _mouse_aim and stick.length_squared() > 0.01:
		return stick.normalized()
	if _mouse_aim:
		var offset := get_global_mouse_position() - global_position
		if offset.length_squared() > 4.0:
			return offset.normalized()
	return super(input_dir)
## Human-controlled character. Reads the input map, which is fed by the
## keyboard, gamepads and multitouch. Buffered edges preserve very short taps;
## synthetic mouse events from touch are ignored to avoid accidental slaps.

func get_move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func handle_actions(delta: float) -> void:
	if _control_pressed:
		begin_control()
	if _jump_pressed:
		start_jump()
	if _dash_pressed:
		start_dash()
	if _strike_pressed:
		begin_charge()
	if is_charging():
		if _strike_released:
			release_strike()
		else:
			set_charge(charge_ratio + delta / charge_time)
	clear_strike_input()

func clear_strike_input() -> void:
	_strike_pressed = false
	_strike_released = false
	_jump_pressed = false
	_dash_pressed = false
	_control_pressed = false
