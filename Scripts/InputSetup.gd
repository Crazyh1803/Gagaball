extends RefCounted
## One idempotent mapping for keyboard, standard PC gamepads and touch actions.
static func bind(action: StringName, event: InputEvent, deadzone := 0.22) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

static func setup() -> void:
	var keys := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"strike": [KEY_SPACE], "dash": [KEY_SHIFT], "jump": [KEY_J, KEY_E], "pause": [KEY_ESCAPE], "control_ball": [KEY_C]}
	for action in keys:
		for code in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			bind(action, event)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	bind(&"strike", mouse)
	var buttons := {"jump": JOY_BUTTON_A, "strike": JOY_BUTTON_X, "control_ball": JOY_BUTTON_Y,
		"dash": JOY_BUTTON_B, "pause": JOY_BUTTON_START,
		"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT,
		"move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN,
		"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B}
	for action in buttons:
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = buttons[action]
		bind(action, event)
	var axes := {"move_left": [JOY_AXIS_LEFT_X,-1], "move_right": [JOY_AXIS_LEFT_X,1],
		"move_up": [JOY_AXIS_LEFT_Y,-1], "move_down": [JOY_AXIS_LEFT_Y,1],
		"aim_left": [JOY_AXIS_RIGHT_X,-1], "aim_right": [JOY_AXIS_RIGHT_X,1],
		"aim_up": [JOY_AXIS_RIGHT_Y,-1], "aim_down": [JOY_AXIS_RIGHT_Y,1],
		"ui_left": [JOY_AXIS_LEFT_X,-1], "ui_right": [JOY_AXIS_LEFT_X,1],
		"ui_up": [JOY_AXIS_LEFT_Y,-1], "ui_down": [JOY_AXIS_LEFT_Y,1]}
	for action in axes:
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = axes[action][0]
		event.axis_value = axes[action][1]
		bind(action, event)
	var shoulder := InputEventJoypadButton.new()
	shoulder.device = -1
	shoulder.button_index = JOY_BUTTON_RIGHT_SHOULDER
	bind(&"strike", shoulder)

static func focus_first(node: Node) -> bool:
	if node is Control and not node.is_visible_in_tree():
		return false
	if node is BaseButton and not node.disabled:
		node.grab_focus()
		return true
	for child in node.get_children():
		if focus_first(child):
			return true
	return false
