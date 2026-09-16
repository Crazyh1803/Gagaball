class_name TouchActionButton
extends Control
## Round on-screen button that presses/releases a project input action while
## held, so gameplay code reads one input path for touch and keyboard alike.
## Uses _input() with a rect check (like VirtualJoystick) so multitouch works
## alongside the joystick and the other buttons.

@export var action: StringName = &"strike"
@export var label := "SLAP"
@export var color := Color("e8554d")

var _touch_index := -1

func _exit_tree() -> void:
	if _touch_index != -1:
		Input.action_release(action)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and get_global_rect().has_point(event.position):
				_touch_index = event.index
				Input.action_press(action)
				queue_redraw()
		elif event.index == _touch_index:
			_touch_index = -1
			Input.action_release(action)
			queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0
	var alpha := 0.55 if _touch_index != -1 else 0.3
	draw_circle(center, radius, Color(color, alpha))
	draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, alpha + 0.15), 3.0)
	var font := get_theme_default_font()
	var font_size := 22
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	draw_string(font, Vector2(center.x - text_width / 2.0, center.y + font_size * 0.35),
			label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, 0.9))
