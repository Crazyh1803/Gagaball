extends SceneTree
const SEASON = preload("res://Scripts/LeagueSeason.gd")
const CATALOG = preload("res://Scripts/LeagueCatalog.gd")
const ART = preload("res://Scripts/FighterArt.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")
	create_timer(60).timeout.connect(func() -> void: push_error("League test timeout"); quit(1))

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else: print("PASS: " + label)

func play_season(career: Dictionary, player_place: int) -> void:
	var division := SEASON.player_league(career)
	var order: Array = []
	for row in SEASON.table(career, division):
		if row.id != "player": order.append(row.id)
	order.insert(player_place, "player")
	for fixture in CATALOG.ROUTES[division].size():
		while int(career.round) == fixture:
			var game := int(career.series.rounds)
			check(SEASON.record(career, order, fixture, game), "City %d game %d records once" % [fixture, game + 1])

func run() -> void:
	var state := root.get_node("GameState")
	state.profiles_path = "user://test-league-profiles-%d.cfg" % OS.get_process_id()
	state.progress_path = "user://test-league-progress-%d.cfg" % OS.get_process_id()
	state._load_profiles()
	state.careers = [{},{},{}]
	state.active_player_slot = 0
	var profile := ART.defaults("TEST CAPTAIN")
	profile.home_city = "baltimore"
	check(state.save_player(0, profile) == OK, "Home city saves with a player")
	state._load_profiles()
	check(state.current_player().home_city == "baltimore", "Home city survives disk reload")
	check(ART.normalize({"home_city":"invalid"}).home_city == "wiesbaden", "Unknown saved home city migrates safely")
	check(CATALOG.ROUTES[0][0] == "wiesbaden" and not CATALOG.ROUTES[1].has("wiesbaden"), "Aukamm stays in Kindergarten only")
	check(CATALOG.ROUTES[3].size() == 6, "World league spans six continental destinations")
	check(CATALOG.PALETTES.baltimore[0][1] != CATALOG.PALETTES.baltimore[1][1], "Baltimore supports Orioles and Ravens palettes")
	var three_game := SEASON.create(0, profile)
	var ids: Array = []
	for row in SEASON.table(three_game, 0): ids.append(row.id)
	for winner in 3:
		var game_order := ids.duplicate()
		var chosen: Variant = game_order.pop_at(winner)
		game_order.push_front(chosen)
		check(SEASON.record(three_game, game_order, 0, winner), "Different winner keeps series alive through Game %d" % (winner + 1))
	check(three_game.round == 1 and three_game.last_series.size() == 6, "Three different winners complete a three-game city series")
	var city_points := 0
	for club in SEASON.table(three_game, 0): city_points += club.points
	check(city_points == 6, "City podium awards only 3 + 2 + 1 league points")
	check(three_game.last_series[0].round_wins == 1 and three_game.last_series[0].round_points >= three_game.last_series[1].round_points,
		"Round points break a one-win series tie")
	for city in state.all_cities():
		check(ResourceLoader.exists("res://Assets/Backgrounds/Stages/%s.png" % city.backdrop), "Backdrop exists: " + city.location)
		check(CATALOG.PALETTES[city.city_id].size() >= 2, "Multiple regional palettes: " + city.location)
	for division in 4:
		for place in [0,1,4,5]:
			var career := SEASON.create(division, profile)
			play_season(career, place)
			var target := clampi(division + (1 if place < 2 else -1), 0, 3)
			check(SEASON.player_league(career) == target, "Division %d place %d promotion/relegation boundary" % [division,place+1])
			check(SEASON.valid(career), "Simultaneous exchanges preserve 24 unique clubs and 6 per division")
			var before: Array = career.clubs.duplicate(true)
			check(not SEASON.record(career, [], int(career.round)), "Completed season refuses duplicate results")
			check(career.clubs == before, "Rejected result cannot change standings")
			SEASON.next_season(career)
			check(career.season == 2 and career.round == 0 and not career.complete, "Next season resets fixtures")
			check(SEASON.table(career, target)[0].points == 0, "Next season clears points")
	state.new_career(0)
	state.start_league_round()
	var saved_career: Dictionary = state.career().duplicate(true)
	state.careers = [{},{},{}]
	state._load_progress()
	check(state.career() == saved_career, "Full league career survives save and reload")
	state.active_player_slot = 1
	check(state.career().is_empty(), "Different player slots have independent careers")
	state.active_player_slot = 0
	state.start_campaign_stage(8)
	check(state.match_config.pit_center.y == 175 and state.match_config.pit_scale == 0.32, "Chicago court is anchored below the building")
	state.start_campaign_stage(5)
	check(state.player_is_home(), "Home-city comparison assigns player to HOME in Baltimore")
	var arena := (load("res://Scenes/GameArena.tscn") as PackedScene).instantiate()
	arena.touch_controls = true
	root.add_child(arena)
	var ball := arena.ball as GagaBall
	var player := arena.get_node("Player") as PlayerCharacter
	var opponent := arena._alive[1] as Character
	check(arena._crowd.fans.size() == 12, "Twelve animated spectators exist outside the roster")
	check(arena._crowd.fans[0].get_meta("player_supporter") and not arena._crowd.fans[6].get_meta("player_supporter"), "Home fans switch sides in the player's home city")
	check(arena._alive.size() == 4, "Supporters and opening host cannot become combatants")
	check(ball.freeze and ball.get_node("BallSprite").position.y == -55, "Home representative holds ball above ground")
	await create_timer(1.95).timeout
	check(arena._toss_progress > 0 and ball.get_node("BallSprite").position.y < -55, "Opening toss visibly travels through the air")
	await create_timer(0.52).timeout
	check(arena._round_started and not ball.freeze and arena._opening_safe > 0, "Landing starts a random roll with opening protection")
	for fighter in arena._alive: fighter.set_physics_process(false)
	arena.set_physics_process(false)
	ball.linear_velocity = Vector2(500,0)
	arena._on_below_waist_hit(ball, player)
	check(player.is_alive, "Opening ball cannot instantly eliminate its thrower")
	arena._opening_safe = 0
	ball.position = arena.pit_center_offset
	player.position = ball.position + Vector2(-30, 0)
	opponent.position = ball.position + Vector2(30, 0)
	ball.linear_velocity = Vector2(500,0)
	var trap_key := key_event()
	trap_key.pressed = true
	player._input(trap_key)
	player.handle_actions(0.016)
	check(ball.controller == player and ball.freeze, "Keyboard C buffers a timed trap and catches a fast incoming shot")
	check(not ball.is_repeat_touch(player), "Controlled ball allows its owner to slap")
	opponent.begin_control()
	check(ball.controller == player, "Steal has a short anti-ping-pong lock")
	ball._control_lock = 0
	opponent._control_cooldown_left = 0
	opponent.begin_control()
	check(ball.controller == opponent, "Another player's timed trap steals controlled possession")
	ball.strike(Vector2.RIGHT, 520, opponent)
	check(ball.controller == null and not ball.freeze and ball.linear_velocity.x == 520, "Slap releases possession at correct speed")
	ball.linear_velocity = Vector2.ZERO
	ball._control_lock = 0
	check(not ball.try_control(opponent), "Owner cannot recapture their own loose ball without a wall or opponent touch")
	ball.repeat_toucher = null
	opponent._control_cooldown_left = 0
	opponent.begin_control()
	check(ball.controller == opponent, "Wall/opponent reset restores eligibility")
	ball.control_left = 0.001
	ball._physics_process(0.01)
	check(ball.controller == null and not ball.freeze, "Dribble expires rather than allowing unlimited carrying")
	check(is_equal_approx(ball.physics_material_override.bounce, 0.96) and arena.get_node("Wall0").physics_material_override.bounce == 0, "Restitution loses a little energy without compounding")
	check(ball.linear_damp < 0.2, "Floor drag no longer kills ricochets rapidly")
	ball.position = arena.pit_center_offset
	ball.linear_damp = 0
	ball.linear_velocity = Vector2(0, -300)
	await create_timer(0.5).timeout
	check(ball.linear_velocity.y > 270 and ball.linear_velocity.length() < 300, "Real wall ricochet retains 96 percent speed without gaining energy")
	check(InputMap.action_has_event("control_ball", key_event()) and InputMap.action_has_event("control_ball", pad_event()), "Control action supports C and controller Y")
	check(arena.get_node("HUD/ControlButton").visible and arena.get_node("HUD/ControlButton").action == &"control_ball", "Android has a separate dribble/steal control")
	check(arena.get_node("HUD/ControlButton").label == "TRAP", "Touch action clearly explains the timed trap")
	var sound := root.get_node("RetroSfx")
	check(sound._music_player.playing and sound._music_player.stream is AudioStreamWAV
		and sound._music_player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"Arena music starts and loops without a gap")
	for path in sound.MUSIC_PATHS:
		var track := load(path) as AudioStreamWAV
		check(track != null and track.stereo and track.mix_rate == 44100 and track.get_length() > 19, "Full stereo music loop imports: " + path.get_file())
		track = null
	check(AudioServer.get_bus_index(&"SFX") >= 0 and AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"SFX")) > 0,
		"Sound effects use a subtle room bus for depth")
	check(AudioServer.get_bus_index(&"MUSIC") >= 0 and AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"MUSIC")) > 0,
		"Music has a dedicated stereo widening bus")
	var rotations := {}
	for city in state.all_cities(): rotations[posmod(str(city.city_id).hash(), 5)] = true
	check(rotations.size() == 5, "The city list rotates across all five music tracks")
	arena.queue_free()
	await process_frame
	# Actual season round: a human loss waits for all CPU finishing places.
	state.start_league_round()
	var league := (load("res://Scenes/GameArena.tscn") as PackedScene).instantiate()
	root.add_child(league)
	check(league._alive.size() == 6, "League match loads six persistent club representatives")
	league._eliminate(league.get_node("Player"))
	check(not league._round_over, "Human elimination does not invent CPU finishing positions")
	for fighter in league._alive.duplicate():
		if league._alive.size() > 1: league._eliminate(fighter)
	check(league._round_over and league._league_recorded and state.career().round == 0 and state.career().series.rounds == 1,
		"Game 1 records six actual finish positions without leaving the city")
	check(league._next_stage == 0 and league._retry_button.text == "PLAY GAME 2", "Game 1 continues to Game 2 in the same city")
	var sum_points := 0
	for club in SEASON.table(state.career(),0): sum_points += club.points
	check(sum_points == 0, "No league points are awarded before a city series ends")
	league.queue_free()
	await process_frame
	state.start_league_round()
	var game_two := (load("res://Scenes/GameArena.tscn") as PackedScene).instantiate()
	root.add_child(game_two)
	game_two._eliminate(game_two.get_node("Player"))
	for fighter in game_two._alive.duplicate():
		if game_two._alive.size() > 1: game_two._eliminate(fighter)
	check(state.career().round == 1 and state.career().series.rounds == 0, "Two wins clinch the best-of-three and advance cities")
	check(game_two._next_stage == 1 and game_two._retry_button.text == "NEXT CITY", "Clinched series offers the next city")
	sum_points = 0
	for club in SEASON.table(state.career(),0): sum_points += club.points
	check(sum_points == 6, "Clinched series distributes exactly 3 + 2 + 1 points")
	game_two.queue_free()
	await process_frame
	root.get_node("RetroSfx").stop_all()
	await create_timer(0.3).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.profiles_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.progress_path))
	print("LEAGUE / CROWD / BALL CHECKS: %d passed, %d failed" % [checks-failures, failures])
	quit(1 if failures else 0)

func key_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_C
	return event

func pad_event() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = JOY_BUTTON_Y
	return event
