extends Control
## Title screen: USA Pit Tour stage select, friendly match setup, and settings
## (with the support-the-dev link). Stage buttons are built from
## GameState.CAMPAIGN_STAGES so the roadmap lives in one place.

const ARENA_SCENE := "res://Scenes/GameArena.tscn"

@onready var stage_list: VBoxContainer = $CampaignPanel/StageList
@onready var _panels: Array[Control] = [
	$MainButtons, $CampaignPanel, $FriendlyPanel, $SettingsPanel,
]

func _ready() -> void:
	theme = GameTheme.create()
	$Background.color = Color("0d1725")
	var backdrop := TextureRect.new()
	backdrop.name = "NeighborhoodBackdrop"
	backdrop.texture = load("res://Assets/Backgrounds/city_schoolyard-v2.png")
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(1280, 720)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.modulate = Color(0.28, 0.34, 0.42, 0.24)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	move_child(backdrop, 1)
	$Title.text = "GAGA PIT SHOWDOWN"
	$Title.add_theme_font_size_override("font_size", 52)
	$Title.add_theme_constant_override("outline_size", 0)
	$Title.add_theme_color_override("font_color", Color("ffd777"))
	$CampaignPanel.offset_top = -170
	$CampaignPanel.offset_bottom = 330
	$CampaignPanel.offset_left = -370
	$CampaignPanel.offset_right = 370
	for button in $MainButtons.get_children():
		button.add_theme_font_size_override("font_size", 22)
	$MainButtons/FriendlyBtn.text = "CUSTOM MATCH"
	var quick := Button.new()
	quick.text = "JUMP INTO THE PIT"
	quick.add_theme_font_size_override("font_size", 22)
	quick.pressed.connect(func() -> void:
		GameState.start_friendly(4, AIController.Difficulty.EASY)
		get_tree().change_scene_to_file(ARENA_SCENE))
	$MainButtons.add_child(quick)
	$MainButtons.move_child(quick, 0)
	var sfx_button := Button.new()
	sfx_button.name = "SfxButton"
	sfx_button.text = "8-BIT SFX: ON"
	sfx_button.pressed.connect(func() -> void:
		var sfx = get_node("/root/RetroSfx")
		sfx.enabled = not sfx.enabled
		sfx_button.text = "8-BIT SFX: ON" if sfx.enabled else "8-BIT SFX: OFF")
	$SettingsPanel.add_child(sfx_button)
	$SettingsPanel.move_child(sfx_button, 0)
	var subtitle := Label.new()
	subtitle.text = "ONE BALL. NO TEAMS. LAST ONE STANDING."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 153)
	subtitle.size.x = 1280
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("81d9c1"))
	add_child(subtitle)
	var instructions := Label.new()
	instructions.text = "SLAP IT AWAY. DODGE THE REBOUND. OWN THE PIT.\nWASD / arrows move  •  Space / click slap  •  Hold to charge  •  Shift evade"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.position = Vector2(0, 620)
	instructions.size.x = 1280
	instructions.add_theme_font_size_override("font_size", 17)
	instructions.add_theme_color_override("font_color", Color("92a9c1"))
	add_child(instructions)
	instructions.name = "Instructions"
	for center in [Vector2(120, 385), Vector2(1160, 385)]:
		var rim := Line2D.new()
		for i in 9:
			rim.add_point(center + Vector2.from_angle(TAU * (i + 0.5) / 8.0) * 180.0)
		rim.width = 4
		rim.default_color = Color("233a51")
		$Background.add_child(rim)
	for i in GameState.CAMPAIGN_STAGES.size():
		var stage: Dictionary = GameState.CAMPAIGN_STAGES[i]
		var button := Button.new()
		button.text = "%d. %s — %s" % [i + 1, stage["name"], stage["location"]]
		button.pressed.connect(_on_stage_pressed.bind(i))
		stage_list.add_child(button)
	_wire_ui_sounds(self)

func _wire_ui_sounds(node: Node) -> void:
	if node is Button:
		(node as Button).pressed.connect(func() -> void:
			get_node("/root/RetroSfx").play(&"ui", -10.0, 0.02))
	for child in node.get_children():
		_wire_ui_sounds(child)

func _show_panel(panel: Control) -> void:
	$Instructions.visible = panel == $MainButtons
	for p in _panels:
		p.visible = p == panel

func _on_campaign_pressed() -> void:
	for i in stage_list.get_child_count():
		(stage_list.get_child(i) as Button).disabled = i >= GameState.unlocked_stages
	_show_panel($CampaignPanel)

func _on_friendly_pressed() -> void:
	_show_panel($FriendlyPanel)

func _on_settings_pressed() -> void:
	_show_panel($SettingsPanel)

func _on_back_pressed() -> void:
	_show_panel($MainButtons)

func _on_stage_pressed(index: int) -> void:
	GameState.start_campaign_stage(index)
	get_tree().change_scene_to_file(ARENA_SCENE)

func _on_friendly_start_pressed() -> void:
	GameState.start_friendly(_selected_count(), _selected_difficulty())
	get_tree().change_scene_to_file(ARENA_SCENE)

func _on_support_pressed() -> void:
	# Opens the native browser on Android and desktop alike.
	OS.shell_open(GameState.SUPPORT_URL)

func _selected_count() -> int:
	for child in $FriendlyPanel/CountRow.get_children():
		var button := child as Button
		if button and button.button_pressed:
			return int(button.text)
	return 4

func _selected_difficulty() -> int:
	var row := $FriendlyPanel/DiffRow
	for i in row.get_child_count():
		var button := row.get_child(i) as Button
		if button and button.button_pressed:
			return i
	return 0
