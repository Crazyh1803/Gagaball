class_name PlayerCharacter
extends Character
## Human-controlled character. Reads the input map, which is fed by the
## keyboard today (WASD / arrows) and by the on-screen virtual joystick in a
## later iteration — the joystick will emit these same actions, so this script
## should not need to change.

func get_move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")
