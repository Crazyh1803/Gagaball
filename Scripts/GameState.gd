extends Node
## Autoload (see project.godot). Holds the campaign roadmap, unlock progress
## (persisted to user://), and the match configuration the next-loaded
## GameArena sets itself up from.

const SUPPORT_URL := "https://buymeacoffee.com/appsbydan"
const SAVE_PATH := "user://save.cfg"

## The 10-stage USA Pit Tour. "cpus" lists AIController difficulties
## (0 easy / 1 medium / 2 hard); "ball_damp" is the pit's surface (dirt pits
## drag, steel pits barely slow the ball); "drop_speed" is the opening bounce.
const CAMPAIGN_STAGES := [
	{"name": "Wayside Elementary", "location": "Canyon, TX",
		"cpus": [0, 0, 0], "drop_speed": 260.0, "ball_damp": 0.5,
		"floor": "wood", "surround": "gym"},
	{"name": "Oakridge Middle", "location": "Topeka, KS",
		"cpus": [0, 1, 1], "drop_speed": 300.0, "ball_damp": 0.4,
		"floor": "court", "surround": "gym"},
	{"name": "Bayou Academy", "location": "Houston, TX",
		"cpus": [1, 1, 1], "drop_speed": 400.0, "ball_damp": 0.35,
		"floor": "blacktop", "surround": "grass"},
	{"name": "Pinecrest Camp", "location": "Maine Woods",
		"cpus": [1, 1, 1], "drop_speed": 340.0, "ball_damp": 0.7,
		"floor": "dirt", "surround": "grass"},
	{"name": "Redwood Charter", "location": "Humboldt, CA",
		"cpus": [1, 1, 2], "drop_speed": 360.0, "ball_damp": 0.35,
		"floor": "dirt", "surround": "grass"},
	{"name": "Inner Harbor Middle", "location": "Baltimore, MD",
		"cpus": [1, 1, 2], "drop_speed": 360.0, "ball_damp": 0.35,
		"floor": "blacktop", "surround": "city", "double_ball": true},
	{"name": "Desert Oasis High", "location": "Phoenix, AZ",
		"cpus": [0, 0, 1, 1, 1, 1, 2, 2, 2], "drop_speed": 380.0, "ball_damp": 0.35,
		"floor": "sand", "surround": "desert"},
	{"name": "Brickstone Prep", "location": "Boston, MA",
		"cpus": [2, 2, 2], "drop_speed": 420.0, "ball_damp": 0.3,
		"floor": "court", "surround": "city"},
	{"name": "Metro Tech", "location": "Chicago, IL",
		"cpus": [2, 2, 2], "drop_speed": 440.0, "ball_damp": 0.12,
		"floor": "steel", "surround": "industrial"},
	{"name": "National Championship Pit", "location": "Orlando, FL",
		"cpus": [2, 2, 2, 2], "drop_speed": 440.0, "ball_damp": 0.3,
		"floor": "court", "surround": "arena"},
]

## How many campaign stages are playable (1 = only stage 0). Saved/loaded.
var unlocked_stages := 1

## What the next GameArena should set up. The defaults let GameArena run
## straight from the editor (F5/F6) without visiting the menu first.
var match_config := {
	"stage_index": -1,
	"stage_name": "",
	"cpus": [0, 0, 1],
	"drop_speed": 340.0,
	"ball_damp": 0.35,
	"double_ball": false,
	"floor": "wood",
	"surround": "gym",
}

## Actions the game expects. project.godot defines these too; this is a
## safety net so a Godot version upgrade that rewrites the input map can't
## leave the game unplayable. Keyboard only -- the touch controls press these
## same actions from code.
const DEFAULT_ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"strike": [KEY_SPACE],
	"dash": [KEY_SHIFT],
}

func _ready() -> void:
	_ensure_input_actions()
	_load_progress()

func _ensure_input_actions() -> void:
	for action in DEFAULT_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in DEFAULT_ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	var mouse_strike := InputEventMouseButton.new()
	mouse_strike.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event(&"strike", mouse_strike)
	if not InputMap.has_action(&"pause"):
		InputMap.add_action(&"pause")
		var pause_key := InputEventKey.new()
		pause_key.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event(&"pause", pause_key)

func start_campaign_stage(index: int) -> void:
	var stage: Dictionary = CAMPAIGN_STAGES[index]
	match_config = {
		"stage_index": index,
		"stage_name": "%s — %s" % [stage["name"], stage["location"]],
		"cpus": stage["cpus"],
		"drop_speed": stage["drop_speed"],
		"ball_damp": stage["ball_damp"],
		"double_ball": stage.get("double_ball", false),
		"floor": stage["floor"],
		"surround": stage["surround"],
	}

## Friendly matches roll a random venue so quick-play isn't always the gym.
func start_friendly(player_count: int, difficulty: int) -> void:
	var cpus: Array = []
	for i in player_count - 1:
		cpus.append(difficulty)
	var venue: Dictionary = CAMPAIGN_STAGES.pick_random()
	match_config = {
		"stage_index": -1,
		"stage_name": "",
		"cpus": cpus,
		"drop_speed": 340.0,
		"ball_damp": 0.35,
		"double_ball": false,
		"floor": venue["floor"],
		"surround": venue["surround"],
	}

## Called by the arena when the round is decided. Campaign wins unlock the
## next stage; friendly matches just pass through.
func report_match_result(player_won: bool) -> void:
	var stage_index: int = match_config["stage_index"]
	if player_won and stage_index >= 0:
		unlocked_stages = clampi(
				maxi(unlocked_stages, stage_index + 2), 1, CAMPAIGN_STAGES.size())
		_save_progress()

func _load_progress() -> void:
	var config_file := ConfigFile.new()
	if config_file.load(SAVE_PATH) == OK:
		unlocked_stages = clampi(int(config_file.get_value("campaign", "unlocked_stages", 1)),
				1, CAMPAIGN_STAGES.size())

func _save_progress() -> void:
	var config_file := ConfigFile.new()
	config_file.set_value("campaign", "unlocked_stages", unlocked_stages)
	config_file.save(SAVE_PATH)
