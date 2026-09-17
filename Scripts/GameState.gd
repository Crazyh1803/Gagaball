extends Node
## Autoload (see project.godot). Holds the campaign roadmap, unlock progress
## (persisted to user://), and the match configuration the next-loaded
## GameArena sets itself up from.

const SUPPORT_URL := "https://buymeacoffee.com/appsbydan"
const SAVE_PATH := "user://save.cfg"
const ART = preload("res://Scripts/FighterArt.gd")
const CATALOG = preload("res://Scripts/LeagueCatalog.gd")
const SEASON = preload("res://Scripts/LeagueSeason.gd")
var careers: Array = [{}, {}, {}]
const HOME_FIGHTERS := [
	["LENA", "Wehen Wiesbaden", "c93748", "242938", 1, 3, 0],
	["BO", "Washburn", "254c84", "e8e2cf", 3, 0, 1],
	["JET", "Houston Astros", "ed6731", "202f50", 4, 2, 1],
	["FINN", "Maine Black Bears", "70a7cf", "202f50", 0, 1, 2],
	["ROWAN", "Humboldt", "276544", "e7b948", 2, 3, 0],
	["CAM", "Baltimore Orioles", "ed6731", "242938", 5, 2, 1],
	["SOL", "Phoenix Suns", "7853a6", "ed6731", 3, 4, 3],
	["QUINN", "Boston Celtics", "268654", "e8e2cf", 0, 1, 3],
	["DRE", "Chicago Bulls", "c93748", "242938", 5, 0, 0],
	["NOVA", "Orlando Magic", "337cbe", "242938", 2, 3, 3],
]
var profiles_path := "user://players.cfg"
var progress_path := SAVE_PATH
var player_profiles: Array[Dictionary] = []
var active_player_slot := 0
var last_save_error := OK

## The 10-stage international Pit Tour. "cpus" lists AIController difficulties
## (0 easy / 1 medium / 2 hard); "ball_damp" is the pit's surface (dirt pits
## drag, steel pits barely slow the ball); "drop_speed" is the opening bounce.
const CAMPAIGN_STAGES := [
	{"name": "Aukamm Elementary", "location": "Wiesbaden, Germany",
		"cpus": [0, 0, 0], "drop_speed": 260.0, "ball_damp": 0.5,
		"floor": "blacktop", "surround": "gym", "backdrop": "backdrop_wiesbaden",
		"wall_color": "8a603d", "court_tint": "b6aa93"},
	{"name": "Oakridge Middle", "location": "Topeka, KS",
		"cpus": [0, 1, 1], "drop_speed": 300.0, "ball_damp": 0.4,
		"floor": "court", "surround": "gym", "backdrop": "backdrop_topeka",
		"wall_color": "8b5a32", "court_tint": "c69a5d"},
	{"name": "Bayou Academy", "location": "Houston, TX",
		"cpus": [1, 1, 1], "drop_speed": 400.0, "ball_damp": 0.35,
		"floor": "dirt", "surround": "grass", "backdrop": "backdrop_houston",
		"wall_color": "4f6657", "court_tint": "b59870",
		"pit_center": Vector2(0, 175), "pit_scale": 0.32},
	{"name": "Pinecrest Camp", "location": "Maine Woods",
		"cpus": [1, 1, 1], "drop_speed": 340.0, "ball_damp": 0.7,
		"floor": "dirt", "surround": "grass", "backdrop": "backdrop_maine",
		"wall_color": "7b4930", "court_tint": "8a725a"},
	{"name": "Redwood Charter", "location": "Humboldt, CA",
		"cpus": [1, 1, 2], "drop_speed": 360.0, "ball_damp": 0.35,
		"floor": "dirt", "surround": "grass", "backdrop": "backdrop_humboldt",
		"wall_color": "6d3f32", "court_tint": "6f8067"},
	{"name": "Inner Harbor Middle", "location": "Baltimore, MD",
		"cpus": [1, 1, 2], "drop_speed": 360.0, "ball_damp": 0.35,
		"floor": "blacktop", "surround": "city", "double_ball": true,
		"backdrop": "backdrop_baltimore", "wall_color": "405a6f",
		"court_tint": "758a9c"},
	{"name": "Desert Oasis High", "location": "Phoenix, AZ",
		"cpus": [0, 0, 1, 1, 1, 1, 2, 2, 2], "drop_speed": 380.0, "ball_damp": 0.35,
		"floor": "sand", "surround": "desert", "backdrop": "backdrop_phoenix",
		"wall_color": "a66a3f", "court_tint": "b4875b"},
	{"name": "Brickstone Prep", "location": "Boston, MA",
		"cpus": [2, 2, 2], "drop_speed": 420.0, "ball_damp": 0.3,
		"floor": "court", "surround": "city", "backdrop": "backdrop_boston",
		"wall_color": "70413c", "court_tint": "8b6d68"},
	{"name": "Metro Tech", "location": "Chicago, IL",
		"cpus": [2, 2, 2], "drop_speed": 440.0, "ball_damp": 0.12,
		"floor": "steel", "surround": "industrial", "backdrop": "backdrop_chicago",
		"wall_color": "737b88", "court_tint": "6d788a",
		"pit_center": Vector2(0, 175), "pit_scale": 0.32},
	{"name": "National Championship Pit", "location": "Orlando, FL",
		"cpus": [2, 2, 2, 2], "drop_speed": 440.0, "ball_damp": 0.3,
		"floor": "court", "surround": "arena", "backdrop": "backdrop_orlando",
		"wall_color": "9a653b", "court_tint": "9b7495"},
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
	"backdrop": "backdrop_wiesbaden",
	"wall_color": "8a603d",
	"court_tint": "b6aa93",
}

## Actions the game expects. project.godot defines these too; this is a
## safety net so a Godot version upgrade that rewrites the input map can't
## leave the game unplayable. InputSetup also binds gamepads and jump.
const DEFAULT_ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"strike": [KEY_SPACE],
	"dash": [KEY_SHIFT],
	"jump": [KEY_J, KEY_E],
}

func _ready() -> void:
	_ensure_input_actions()
	_load_progress()
	_load_profiles()

func _ensure_input_actions() -> void:
	preload("res://Scripts/InputSetup.gd").setup()

func start_campaign_stage(index: int) -> void:
	var stage: Dictionary = CAMPAIGN_STAGES[index]
	match_config = {
		"stage_index": index,
		"venue_index": index,
		"city_id": CATALOG.ORIGINAL_IDS[index],
		"pit_center": stage.get("pit_center", Vector2(0, 115)),
		"pit_scale": stage.get("pit_scale", 0.36),
		"stage_name": "%s — %s" % [stage["name"], stage["location"]],
		"cpus": stage["cpus"],
		"drop_speed": stage["drop_speed"],
		"ball_damp": stage["ball_damp"],
		"double_ball": stage.get("double_ball", false),
		"floor": stage["floor"],
		"surround": stage["surround"],
		"backdrop": stage["backdrop"],
		"wall_color": stage["wall_color"],
		"court_tint": stage["court_tint"],
	}

## Friendly matches roll a random venue so quick-play isn't always the gym.
func start_friendly(player_count: int, difficulty: int, selected_city := "") -> void:
	var cpus: Array = []
	for i in player_count - 1:
		cpus.append(difficulty)
	var venue_index := randi_range(0, CAMPAIGN_STAGES.size() - 1)
	var venue: Dictionary = CAMPAIGN_STAGES[venue_index]
	match_config = {
		"stage_index": -1,
		"venue_index": venue_index,
		"city_id": CATALOG.ORIGINAL_IDS[venue_index],
		"pit_center": venue.get("pit_center", Vector2(0, 115)),
		"pit_scale": venue.get("pit_scale", 0.36),
		"stage_name": "",
		"cpus": cpus,
		"drop_speed": 340.0,
		"ball_damp": 0.35,
		"double_ball": false,
		"floor": venue["floor"],
		"surround": venue["surround"],
		"backdrop": venue["backdrop"],
		"wall_color": venue["wall_color"],
		"court_tint": venue["court_tint"],
	}
	if not selected_city.is_empty():
		var chosen := CATALOG.find_city(selected_city, CAMPAIGN_STAGES)
		match_config.merge(chosen, true)
		match_config.merge({"stage_index": -1, "stage_name": "%s — %s" % [chosen.name, chosen.location],
			"cpus": cpus, "drop_speed": 340.0, "double_ball": false}, true)

## Called by the arena when the round is decided. Campaign wins unlock the
## next stage; friendly matches just pass through.
func report_match_result(player_won: bool) -> void:
	if match_config.get("league_match", false):
		return # A season records all six finishing places, not just a win flag.
	var stage_index: int = match_config["stage_index"]
	if player_won and stage_index >= 0:
		unlocked_stages = clampi(
				maxi(unlocked_stages, stage_index + 2), 1, CAMPAIGN_STAGES.size())
		_save_progress()

func _load_progress() -> void:
	careers = [{}, {}, {}]
	var config_file := ConfigFile.new()
	if config_file.load(progress_path) == OK:
		unlocked_stages = clampi(int(config_file.get_value("campaign", "unlocked_stages", 1)),
				1, CAMPAIGN_STAGES.size())
		for slot in 3:
			var saved: Variant = config_file.get_value("leagues", "slot_%d" % slot, {})
			careers[slot] = SEASON.migrate(saved) if SEASON.valid(saved) else {}

func _save_progress() -> void:
	var config_file := ConfigFile.new()
	config_file.load(progress_path)
	config_file.set_value("campaign", "unlocked_stages", unlocked_stages)
	for slot in 3:
		config_file.set_value("leagues", "slot_%d" % slot, careers[slot])
	last_save_error = config_file.save(progress_path)

func all_cities() -> Array[Dictionary]:
	return CATALOG.cities(CAMPAIGN_STAGES)

func city_id() -> String:
	return match_config.get("city_id", "wiesbaden")

func player_is_home() -> bool:
	return current_player().get("home_city", "wiesbaden") == city_id()

func local_palettes() -> Array:
	return CATALOG.PALETTES.get(city_id(), CATALOG.PALETTES.wiesbaden)

func city_representative() -> Dictionary:
	var index: int = match_config.get("venue_index", 0)
	if index >= 0: return home_fighter(index)
	var names := {"belair":"HARPER", "doylestown":"PENN", "taos":"LUZ", "annapolis":"SAILOR",
		"washington":"BLAIR", "brasilia":"CAIO", "berlin":"MILA", "nairobi":"AMANI", "tokyo":"REN", "canberra":"CHARLIE"}
	var profile := ART.defaults(names.get(city_id(), "HOST"))
	var palette: Array = local_palettes()[0]
	profile.merge({"jersey": palette[1], "accent": palette[2], "pants": palette[2],
		"home_city": city_id(), "skin": absi(city_id().hash()) % ART.SKINS.size()}, true)
	return profile

func career() -> Dictionary:
	return careers[active_player_slot]

func new_career(league: int) -> void:
	careers[active_player_slot] = SEASON.create(clampi(league, 0, 3), current_player())
	_save_progress()

func league_route() -> Array[Dictionary]:
	return CATALOG.route(SEASON.player_league(career()), CAMPAIGN_STAGES)

func start_league_round() -> void:
	if career().is_empty(): new_career(0)
	if career().complete:
		SEASON.next_season(career())
		_save_progress()
	var stage: Dictionary = league_route()[int(career().round)]
	match_config = stage.duplicate(true)
	match_config.merge({"league_match": true, "stage_index": int(career().round), "series_game": int(career().series.rounds),
		"stage_name": "%s · %s — %s" % [CATALOG.NAMES[SEASON.player_league(career())], stage.name, stage.location]}, true)
	for club in career().clubs:
		if club.id == "player": club.profile = current_player()

func record_league_round(order: Array) -> bool:
	if not match_config.get("league_match", false): return false
	if not SEASON.record(career(), order, int(match_config.stage_index), int(match_config.series_game)): return false
	_save_progress()
	return true

func tour_stages() -> Array:
	return league_route() if match_config.get("league_match", false) else CAMPAIGN_STAGES

func standings_text(completed := false) -> String:
	if career().is_empty(): return "No season started. Pick a division below."
	var rows: Array = SEASON.table(career(), SEASON.player_league(career()))
	if completed and career().complete:
		for table_rows in career().last_tables:
			for row in table_rows:
				if row.id == "player": rows = table_rows
	var lines := PackedStringArray()
	for i in rows.size():
		var row: Dictionary = rows[i]
		lines.append("%d. %s%s   %d pts  /  %d wins" % [i + 1, row.profile.name,
			" (YOU)" if row.id == "player" else "", row.points, row.wins])
	return "\n".join(lines)

func series_text(max_rows := 3) -> String:
	var rows: Array = career().last_series if int(career().series.rounds) == 0 else SEASON.series_table(career())
	var lines := PackedStringArray()
	for i in mini(rows.size(), max_rows):
		var row: Dictionary = rows[i]
		lines.append("%d. %s%s   %d wins / %d round pts" % [i + 1, row.profile.name,
			" (YOU)" if row.id == "player" else "", row.round_wins, row.round_points])
	return "\n".join(lines)

func home_fighter(venue_index: int) -> Dictionary:
	var home: Array = HOME_FIGHTERS[clampi(venue_index, 0, HOME_FIGHTERS.size() - 1)]
	var profile := ART.defaults(home[0])
	profile.merge({"jersey": home[2], "accent": home[3], "pants": home[3], "shoes": home[3], "skin": home[4],
		"hair_style": home[5], "hat": home[6], "home_city": CATALOG.ORIGINAL_IDS[clampi(venue_index, 0, CATALOG.ORIGINAL_IDS.size() - 1)]}, true)
	return profile

func current_player() -> Dictionary:
	return player_profiles[active_player_slot].duplicate()

func _load_profiles() -> void:
	var cfg := ConfigFile.new()
	cfg.load(profiles_path)
	player_profiles.clear()
	for slot in 3:
		var value: Variant = cfg.get_value("players", "slot_%d" % slot,
			ART.defaults("ROOKIE %d" % (slot + 1)))
		player_profiles.append(ART.normalize(value if value is Dictionary else {}))
	active_player_slot = clampi(int(cfg.get_value("players", "active", 0)), 0, 2)

## Commit to memory only after the disk save succeeds; never lose the other slots.
func save_player(slot: int, profile: Dictionary) -> Error:
	if slot < 0 or slot >= 3:
		return ERR_INVALID_PARAMETER
	var cfg := ConfigFile.new()
	var cleaned := ART.normalize(profile)
	for index in 3:
		cfg.set_value("players", "slot_%d" % index,
			cleaned if index == slot else player_profiles[index])
	cfg.set_value("players", "active", slot)
	var error := cfg.save(profiles_path)
	if error == OK:
		player_profiles[slot] = cleaned
		active_player_slot = slot
	return error
