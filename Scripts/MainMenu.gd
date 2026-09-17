extends Control
## Title screen: Pit Tour stage select, friendly match setup, and settings
## (with the support-the-dev link). Stage buttons are built from
## GameState.CAMPAIGN_STAGES so the roadmap lives in one place.

const ARENA_SCENE := "res://Scenes/GameArena.tscn"
var _league_panel: VBoxContainer
var _league_choice: OptionButton
var _league_info: Label
var _new_season_dialog: ConfirmationDialog
var _friendly_city: OptionButton

@onready var stage_list: VBoxContainer = $CampaignPanel/StageList
@onready var _panels: Array[Control] = [
	$MainButtons, $CampaignPanel, $FriendlyPanel, $SettingsPanel,
]
## Cached while MainMenu is in the tree. This autoload remains valid when a
## button removes the menu during an ensuing scene change.
@onready var _sfx: Node = get_node("/root/RetroSfx")

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
	$MainButtons.offset_top = -115
	$MainButtons.add_theme_constant_override("separation", 12)
	var creator := Button.new()
	creator.text = "MY PLAYERS  /  CREATE & EQUIP"
	creator.add_theme_font_size_override("font_size", 20)
	creator.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://Scenes/PlayerCreator.tscn"))
	$MainButtons.add_child(creator)
	$MainButtons.move_child(creator, 2)
	var active := Label.new()
	active.text = "PLAYING AS  %s   •   SLOT %d" % [GameState.current_player().name, GameState.active_player_slot + 1]
	active.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active.position = Vector2(0, 205)
	active.size.x = 1280
	active.name = "ActivePlayer"
	add_child(active)
	var sfx_button := Button.new()
	sfx_button.name = "SfxButton"
	sfx_button.text = "16-BIT ARCADE SFX: ON" if _sfx.enabled else "16-BIT ARCADE SFX: OFF"
	sfx_button.pressed.connect(func() -> void:
		_sfx.enabled = not _sfx.enabled
		sfx_button.text = "16-BIT ARCADE SFX: ON" if _sfx.enabled else "16-BIT ARCADE SFX: OFF")
	$SettingsPanel.add_child(sfx_button)
	$SettingsPanel.move_child(sfx_button, 0)
	var music_button := Button.new()
	music_button.name = "MusicButton"
	music_button.text = "MUSIC: ON" if _sfx.music_enabled else "MUSIC: OFF"
	music_button.pressed.connect(func() -> void:
		_sfx.set_music_enabled(not _sfx.music_enabled)
		music_button.text = "MUSIC: ON" if _sfx.music_enabled else "MUSIC: OFF")
	$SettingsPanel.add_child(music_button)
	$SettingsPanel.move_child(music_button, 1)
	_sfx.stop_music()
	var subtitle := Label.new()
	subtitle.text = "ONE BALL. NO TEAMS. LAST ONE STANDING."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 153)
	subtitle.size.x = 1280
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("81d9c1"))
	add_child(subtitle)
	var instructions := Label.new()
	instructions.text = "WASD / arrows move  •  Space / click slap  •  J / E jump  •  Shift dash  •  C trap / steal\nPAD: Left stick move  •  Right stick aim  •  X / RB slap  •  A jump  •  B dash  •  Y trap / steal"
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
	_build_league_menu()
	_friendly_city = OptionButton.new()
	_friendly_city.name = "VenueChoice"
	_friendly_city.add_item("RANDOM CITY")
	_friendly_city.set_item_metadata(0, "")
	for city in GameState.all_cities():
		_friendly_city.add_item(city.location)
		_friendly_city.set_item_metadata(_friendly_city.item_count - 1, city.city_id)
	$FriendlyPanel.add_child(_friendly_city)
	$FriendlyPanel.move_child(_friendly_city, 4)
	_wire_ui_sounds(self)
	quick.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_show_panel($MainButtons)
		get_viewport().set_input_as_handled()

func _wire_ui_sounds(node: Node) -> void:
	if node is Button:
		(node as Button).pressed.connect(_play_ui_sound)
	for child in node.get_children():
		_wire_ui_sounds(child)

## A button may change scenes before its later signal callbacks run. Use the
## cached autoload so playback does not depend on MainMenu still being active.
func _play_ui_sound() -> void:
	_sfx.play(&"ui", -10.0, 0.02)

func _show_panel(panel: Control) -> void:
	$Instructions.visible = panel == $MainButtons
	$ActivePlayer.visible = panel == $MainButtons
	for p in _panels:
		p.visible = p == panel
	preload("res://Scripts/InputSetup.gd").focus_first(panel)

func _on_campaign_pressed() -> void:
	_show_panel(_league_panel)
	(_league_panel.get_node("NewCareer") if GameState.career().is_empty() else _league_panel.get_node("ContinueSeason")).grab_focus()

func _build_league_menu() -> void:
	_league_panel = VBoxContainer.new()
	_league_panel.name = "LeaguePanel"
	_league_panel.position = Vector2(280, 190)
	_league_panel.size = Vector2(720, 480)
	_league_panel.add_theme_constant_override("separation", 9)
	add_child(_league_panel)
	_panels.append(_league_panel)
	_league_panel.hide()
	_league_info = Label.new()
	_league_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_league_info.add_theme_font_size_override("font_size", 16)
	_league_info.add_theme_constant_override("line_spacing", -4)
	var career := GameState.career()
	_league_info.text = "BEST-OF-3 CITIES · podium earns 3 / 2 / 1 league points\nTop two promoted · bottom two relegated · ties: city wins, places, then seed"
	if not career.is_empty():
		_league_info.text += "\n\nSEASON %d · %s\n" % [career.season, GameState.CATALOG.NAMES[int(career.last_league) if career.complete else GameState.SEASON.player_league(career)]]
		_league_info.text += GameState.standings_text(career.complete)
		if career.complete: _league_info.text += "\n" + career.movement
	_league_panel.add_child(_league_info)
	var resume := Button.new()
	resume.name = "ContinueSeason"
	resume.text = "START NEXT SEASON" if not career.is_empty() and career.complete else "CONTINUE SEASON"
	resume.disabled = career.is_empty()
	resume.pressed.connect(_play_league)
	_league_panel.add_child(resume)
	_league_choice = OptionButton.new()
	_league_choice.name = "LeagueChoice"
	for i in 4:
		_league_choice.add_item("%s — %s" % [GameState.CATALOG.NAMES[i], GameState.CATALOG.DESCRIPTIONS[i]])
	_league_panel.add_child(_league_choice)
	var start := Button.new()
	start.name = "NewCareer"
	start.text = "NEW CAREER IN SELECTED LEAGUE"
	start.pressed.connect(func() -> void:
		if GameState.career().is_empty(): _begin_career()
		else: _new_season_dialog.popup_centered(Vector2i(600, 170)))
	_league_panel.add_child(start)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(_on_back_pressed)
	_league_panel.add_child(back)
	_new_season_dialog = ConfirmationDialog.new()
	_new_season_dialog.dialog_text = "Replace this player's league career?\nTheir appearance and other saved players' careers are kept."
	_new_season_dialog.confirmed.connect(_begin_career)
	add_child(_new_season_dialog)

func _begin_career() -> void:
	GameState.new_career(_league_choice.selected)
	_play_league()

func _play_league() -> void:
	GameState.start_league_round()
	get_tree().change_scene_to_file(ARENA_SCENE)

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
	GameState.start_friendly(_selected_count(), _selected_difficulty(), str(_friendly_city.get_item_metadata(_friendly_city.selected)))
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
