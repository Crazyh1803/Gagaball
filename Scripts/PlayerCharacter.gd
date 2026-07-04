class_name PlayerCharacter
extends Character
## Human-controlled character. Reads the input map, which is fed by the
## keyboard (WASD/arrows, Space, Shift) and by the on-screen touch controls —
## both press the same actions, so this script never needs touch-specific code.

func get_move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func handle_actions(delta: float) -> void:
	if Input.is_action_just_pressed(&"dash"):
		start_dash()
	if Input.is_action_just_pressed(&"strike"):
		begin_charge()
	elif is_charging():
		if Input.is_action_just_released(&"strike"):
			release_strike()
		else:
			set_charge(charge_ratio + delta / charge_time)
