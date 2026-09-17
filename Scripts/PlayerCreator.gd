extends Control
const ART = preload("res://Scripts/FighterArt.gd")
const COLOR_NAMES = ART.COLOR_NAMES
var _drafts: Array[Dictionary] = []
var _slot := 0
var _slots: Array[Button] = []
var _options: Dictionary = {}
var _name: LineEdit
var _preview: Sprite2D
var _name_label: Label
var _status: Label
var _pose: OptionButton
var _facing: OptionButton
var _clock := 0.0
var _appearance: GridContainer
var _outfit: GridContainer
var _identity: GridContainer
var _home_city: OptionButton
var _discard_dialog: ConfirmationDialog

func _ready() -> void:
	theme = GameTheme.create()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for profile in GameState.player_profiles:
		_drafts.append(profile.duplicate())
	_slot = GameState.active_player_slot
	var bg := ColorRect.new()
	bg.color = Color("101d2d")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_label("MAKE YOUR PIT LEGEND", Vector2(60, 24), 36, Color("ffd777"))
	_label("Three saved players. Every look works in every arena.", Vector2(62, 76), 18)
	for index in 3:
		var button := Button.new()
		button.position = Vector2(60 + index * 390, 118)
		button.size = Vector2(370, 46)
		button.pressed.connect(_select_slot.bind(index))
		add_child(button)
		_slots.append(button)
	var pedestal := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 33:
		points.append(Vector2(256, 467) + Vector2(cos(TAU * i / 32.0) * 145, sin(TAU * i / 32.0) * 27))
	pedestal.polygon = points
	pedestal.color = Color("284159")
	add_child(pedestal)
	_preview = Sprite2D.new()
	_preview.position = Vector2(256, 350)
	_preview.scale = Vector2(2.5, 2.5)
	_preview.hframes = 8
	_preview.vframes = 3
	add_child(_preview)
	_name_label = _label("", Vector2(66, 186), 25, Color("ffd777"))
	_name_label.size.x = 380
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pose = OptionButton.new()
	for item in ["Walking", "Power charge", "Slap", "Victory", "Knocked out", "Jump"]:
		_pose.add_item(item)
	_pose.position = Vector2(65, 516)
	_pose.size = Vector2(190, 40)
	add_child(_pose)
	_facing = OptionButton.new()
	for item in ["Front", "Side", "Back"]:
		_facing.add_item(item)
	_facing.position = Vector2(270, 516)
	_facing.size = Vector2(178, 40)
	add_child(_facing)
	var grid := GridContainer.new()
	_appearance = grid
	grid.columns = 2
	grid.position = Vector2(520, 236)
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 7)
	add_child(grid)
	_outfit = GridContainer.new()
	_outfit.columns = 2
	_outfit.position = grid.position
	_outfit.add_theme_constant_override("h_separation",24)
	_outfit.add_theme_constant_override("v_separation",7)
	add_child(_outfit)
	_outfit.hide()
	_identity = GridContainer.new()
	_identity.columns = 1
	_identity.position = grid.position
	_identity.add_theme_constant_override("v_separation", 22)
	add_child(_identity)
	_identity.hide()
	var city_title := Label.new()
	city_title.text = "YOUR HOME CITY"
	_identity.add_child(city_title)
	_home_city = OptionButton.new()
	_home_city.name = "HomeCity"
	_home_city.custom_minimum_size = Vector2(570, 42)
	for city in GameState.all_cities():
		_home_city.add_item(city.location)
		_home_city.set_item_metadata(_home_city.item_count - 1, city.city_id)
	_home_city.item_selected.connect(func(index: int) -> void:
		_drafts[_slot].home_city = _home_city.get_item_metadata(index)
		_refresh(false))
	_identity.add_child(_home_city)
	var city_help := Label.new()
	city_help.text = "Your fans travel in your shirt colours.\nAt your home city, they take the HOME side.\nLocal fans mix colours from regional sports teams.\n\nEach saved player has their own league career.\nOn the court it is still every player for themselves!"
	city_help.add_theme_font_size_override("font_size", 18)
	_identity.add_child(city_help)
	for tab in 3:
		var button := Button.new()
		button.text = ["APPEARANCE", "OUTFIT", "HOME CITY"][tab]
		button.position = Vector2(520 + tab * 200,184)
		button.size = Vector2(185,40)
		button.pressed.connect(_show_tab.bind(tab))
		add_child(button)
	var name_title := Label.new()
	name_title.text = "PLAYER NAME"
	grid.add_child(name_title)
	_name = LineEdit.new()
	_name.max_length = 14
	_name.custom_minimum_size = Vector2(370, 36)
	_name.text_changed.connect(func(value: String) -> void:
		_drafts[_slot]["name"] = value
		_refresh(false))
	grid.add_child(_name)
	_add_option(grid, "skin", "SKIN COLOUR", ART.SKIN_NAMES)
	_add_option(grid, "body_type", "BODY TYPE", ART.BODIES)
	_add_option(grid, "hair_style", "HAIRSTYLE", ART.STYLES)
	_add_option(grid, "hair_color", "HAIR COLOUR", ["Black", "Brown", "Auburn", "Blond", "Silver", "Plum"])
	_add_option(grid, "eye_color", "EYE COLOUR", ART.EYE_NAMES)
	_add_option(grid, "beard", "FACIAL HAIR", ART.BEARDS)
	_add_option(_outfit, "hat", "HAT", ART.HATS)
	_add_option(_outfit, "accessory", "ACCESSORY", ART.ACCESSORIES)
	_add_option(_outfit, "pattern", "SHIRT DESIGN", ART.PATTERNS)
	_add_option(_outfit, "jersey", "SHIRT PRIMARY", COLOR_NAMES)
	_add_option(_outfit, "accent", "SHIRT SECONDARY", COLOR_NAMES)
	_add_option(_outfit, "pants", "SHORTS COLOUR", COLOR_NAMES)
	_add_option(_outfit, "shoes", "SHOE COLOUR", COLOR_NAMES)
	_status = _label("", Vector2(60, 578), 17, Color("81d9c1"))
	var save := Button.new()
	save.text = "SAVE & USE THIS PLAYER"
	save.position = Vector2(520, 622)
	save.size = Vector2(370, 46)
	save.pressed.connect(_save)
	add_child(save)
	var back := Button.new()
	back.text = "BACK / DISCARD UNSAVED"
	back.position = Vector2(60, 622)
	back.size = Vector2(388, 46)
	back.pressed.connect(_back)
	add_child(back)
	_discard_dialog = ConfirmationDialog.new()
	_discard_dialog.dialog_text = "Discard unsaved edits? Your saved player slots will not change."
	_discard_dialog.confirmed.connect(_leave)
	add_child(_discard_dialog)
	_select_slot(_slot)
	_slots[_slot].grab_focus()

func _show_tab(tab: int) -> void:
	_appearance.visible = tab == 0
	_outfit.visible = tab == 1
	_identity.visible = tab == 2
	preload("res://Scripts/InputSetup.gd").focus_first([_appearance, _outfit, _identity][tab])

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()

func _back() -> void:
	for index in 3:
		if ART.normalize(_drafts[index]) != GameState.player_profiles[index]:
			_discard_dialog.popup_centered(Vector2i(560,150))
			return
	_leave()

func _leave() -> void:
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _label(value: String, at: Vector2, font_size: int, color := Color("c6d8e6")) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _add_option(grid: GridContainer, key: String, title: String, choices: Array) -> void:
	var label := Label.new()
	label.text = title
	grid.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(370, 36)
	for choice in choices:
		option.add_item(str(choice))
	if key in ART.COLOR_KEYS:
		for index in ART.COLORS.size():
			var swatch := Image.create(18,18,false,Image.FORMAT_RGBA8)
			swatch.fill(Color(ART.COLORS[index]))
			option.set_item_icon(index,ImageTexture.create_from_image(swatch))
			option.set_item_metadata(index,ART.COLORS[index])
	option.item_selected.connect(func(index: int) -> void:
		_drafts[_slot][key] = option.get_item_metadata(index) if key in ART.COLOR_KEYS else index
		_refresh())
	_options[key] = option
	grid.add_child(option)

func _select_slot(index: int) -> void:
	_slot = index
	_name.text = _drafts[_slot].name
	for item in _home_city.item_count:
		if _home_city.get_item_metadata(item) == _drafts[_slot].home_city:
			_home_city.select(item)
	for key in _options:
		var value: Variant = _drafts[_slot][key]
		if key in ART.COLOR_KEYS:
			var option: OptionButton = _options[key]
			var selected := -1
			for item in option.item_count:
				if option.get_item_metadata(item) == value:
					selected = item
			if selected < 0:
				selected = option.item_count
				option.add_item("Custom #%s" % value)
				option.set_item_metadata(selected,value)
			option.select(selected)
		else:
			_options[key].select(int(value))
	_refresh()

func _refresh(redraw := true) -> void:
	if redraw:
		_preview.texture = ART.sheet(_drafts[_slot])
	_name_label.text = ART.normalize(_drafts[_slot]).name
	var any_dirty := false
	for index in 3:
		var dirty := ART.normalize(_drafts[index]) != GameState.player_profiles[index]
		any_dirty = any_dirty or dirty
		_slots[index].text = "%d  %s%s%s" % [index + 1, ART.normalize(_drafts[index]).name,
			" *" if dirty else "", "  [IN USE]" if index == GameState.active_player_slot else ""]
		_slots[index].modulate = Color("ffd777") if index == _slot else Color.WHITE
	_status.text = "* Unsaved edits. Switching slots keeps drafts; Back discards them." if any_dirty else "Choose a slot, customise it, then Save & Use to equip it."

func _save() -> void:
	var error := GameState.save_player(_slot, _drafts[_slot])
	if error != OK:
		_status.text = "Could not save player (%s). Your edits are still here; try again." % error_string(error)
		return
	_drafts[_slot] = GameState.current_player()
	_name.text = _drafts[_slot].name
	_refresh()
	_status.text = "%s saved in slot %d and equipped. Other slots are unchanged." % [_drafts[_slot].name, _slot + 1]

func _process(delta: float) -> void:
	_clock += delta
	var column := int(_clock * 7.0) % 4 if _pose.selected == 0 else _pose.selected + 3
	if _pose.selected == 5:
		column = 4
	_preview.position.y = 350 - absf(sin(_clock * 4)) * 45 if _pose.selected == 5 else 350
	_preview.frame = _facing.selected * 8 + column
