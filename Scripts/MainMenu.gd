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
	for i in GameState.CAMPAIGN_STAGES.size():
		var stage: Dictionary = GameState.CAMPAIGN_STAGES[i]
		var button := Button.new()
		button.text = "%d. %s — %s" % [i + 1, stage["name"], stage["location"]]
		button.pressed.connect(_on_stage_pressed.bind(i))
		stage_list.add_child(button)

func _show_panel(panel: Control) -> void:
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
