class_name GameTheme
extends RefCounted

static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("e5edf6"))
	theme.set_color("font_color", "Button", Color("e5edf6"))
	theme.set_color("font_hover_color", "Button", Color("ffffff"))
	theme.set_color("font_pressed_color", "Button", Color("101925"))
	theme.set_color("font_disabled_color", "Button", Color("5f7187"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("1c2d42")
		style.border_color = Color("344b66")
		if state == "hover":
			style.bg_color = Color("2a425d")
			style.border_color = Color("82d9c3")
		elif state == "pressed":
			style.bg_color = Color("ffd777")
			style.border_color = Color("ffd777")
		elif state == "disabled":
			style.bg_color = Color("142031")
			style.border_color = Color("233449")
		elif state == "focus":
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Color("ffd777")
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		theme.set_stylebox(state, "Button", style)
	return theme
