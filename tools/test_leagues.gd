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
	state.start_friendly(6, 1, "baltimore")
	check(state.match_config.pit_center == Vector2(0,115) and state.match_config.pit_scale == 0.36,
		"An explicitly selected city cannot inherit another random venue's court geometry")
	state.start_campaign_stage(5)
	check(state.player_is_home(), "Home-city comparison assigns player to HOME in Baltimore")
	var arena := (load("res://Scenes/GameArena.tscn") as PackedScene).instantiate()
	arena.touch_controls = true
	root.add_child(arena)
	var ball := arena.ball as GagaBall
	var player := arena.get_node("Player") as PlayerCharacter
	var opponent := arena._alive[1] as Character
	check(arena._crowd.fans.size() == 10, "Ten venue-placed animated spectators exist outside the roster")
	check(arena._crowd.fans[0].get_meta("player_supporter") and not arena._crowd.fans[5].get_meta("player_supporter"), "Home fans switch sides in the player's home city")
	var crowd_rows := {}
	for fan in arena._crowd.fans.slice(0, 5): crowd_rows[roundi(fan.position.y)] = true
	check(crowd_rows.size() == 5, "Supporters gather in irregular clumps instead of formation rows")
	var venue_layers = preload("res://Scripts/VenueLayers.gd")
	for city in state.all_cities():
		var crowd_layer: Array = venue_layers.crowd(city.city_id)
		var motion_layer: Array = venue_layers.motion(city.city_id)
		check(venue_layers.CROWD.has(city.city_id) and crowd_layer[0].size() == 5
			and crowd_layer[1].size() == 5,
			"Venue has its own populated crowd layer: " + str(city.city_id))
		var pit_center: Vector2 = city.get("pit_center", Vector2(0, 115))
		var pit_vertical_scale: float = city.get("pit_scale", 0.36)
		var pit_polygon := PackedVector2Array()
		for point_index in 8:
			var angle := TAU * (point_index + 0.5) / 8.0
			var world_y := sin(angle) * 330.0
			var width_scale := 1.0 + world_y / 330.0 * 0.13
			pit_polygon.append(pit_center + Vector2(cos(angle) * 330.0 * width_scale,
				world_y * pit_vertical_scale))
		var crowd_clear := true
		for side in crowd_layer:
			for point in side:
				crowd_clear = crowd_clear and not Geometry2D.is_point_in_polygon(Vector2(point), pit_polygon)
		check(crowd_clear, "Every spectator's feet stay outside the playable pit: " + str(city.city_id))
		check(venue_layers.MOTION.has(city.city_id) and motion_layer.size() >= 1
			and motion_layer.all(func(spec): return spec.path.size() >= 2),
			"Venue has approved background-movement paths: " + str(city.city_id))
	for sprite_name in ["roadrunner-run-v3", "javelina-trot-v3", "blue-crab-scuttle-v3", "cyclist-pedal-v3",
			"pigeon-flap-v3", "chicago-train-periodic-v3", "baltimore-oriole-flap-v1",
			"boston-gull-flap-v1", "belair-cardinal-flap-v1", "berlin-sparrow-flap-v1",
			"brasilia-toucan-flap-v1", "canberra-cockatoo-flap-v1",
			"brasilia-capybara-walk-v1", "canberra-kangaroo-hop-v1",
			"pedestrian-walk-v1", "rollerblader-glide-v1", "dogwalker-labrador-v1",
			"dogwalker-dachshund-v1", "dogwalker-kelpie-v1", "houston-grackle-flap-v1",
			"humboldt-raven-flap-v1", "maine-chickadee-flap-v1", "orlando-ibis-flap-v1",
			"topeka-meadowlark-flap-v1", "tokyo-whiteeye-flap-v1",
			"washington-eagle-flap-v1"]:
		var texture := load("res://Assets/Ambience/%s.png" % sprite_name) as Texture2D
		check(texture != null and texture.get_image().detect_alpha() != Image.ALPHA_NONE,
			"Ambient pixel-art sprite imports with true transparency: " + sprite_name)
	check(arena.has_node("StageAmbience") and arena.has_node("StageAmbienceFront")
		and arena.get_node("StageAmbienceFront").actors.size() == 1,
		"Baltimore promenade life is isolated on the foreground layer")
	var labels_in_crowd := 0
	for child in arena._crowd.get_children(): labels_in_crowd += 1 if child is Label else 0
	check(labels_in_crowd == 0, "Crowd no longer carries HOME or AWAY text labels")
	check(venue_layers.MOTION.values().all(func(layer):
		return layer.all(func(actor): return actor.kind != "boat")),
		"Moving sailboats are removed in favor of the superior painted boats")
	var baltimore_crab: Dictionary = arena.get_node("StageAmbienceFront").actors[0]
	check(baltimore_crab.kind in ["walker", "rollerblader", "dogwalker", "bicycle", "crab"]
		and Vector2(baltimore_crab.path[0]) == Vector2(-184,301)
		and Vector2(baltimore_crab.path[-1]) == Vector2(190,301),
		"Baltimore ground rotation follows the new foreground brick-promenade route")
	check(arena.get_node("StageAmbienceFront").z_index > 2,
		"Tall Baltimore promenade actors render in front of the near pit wall")
	check(arena._crowd.fans[9].position.x < 300.0,
		"Baltimore's right foreground spectator stays clear of the railing")
	check(arena._crowd.fans.any(func(fan): return fan.z_index > 2),
		"Foreground spectators render in front of the near pit wall")
	var crowd_painter_order := true
	for first in arena._crowd.fans:
		for second in arena._crowd.fans:
			if first.position.y > second.position.y + 20.0:
				crowd_painter_order = crowd_painter_order and first.z_index > second.z_index
	check(crowd_painter_order,
		"Crowd depth follows every spectator's feet instead of two broad rows")
	var crowd_audio := root.get_node("RetroSfx")
	arena._crowd.cheer(0.1, true)
	arena._crowd.boo(0.1)
	arena._crowd.random_shout()
	var shout_played := false
	for shout in [&"crowd_shout_a", &"crowd_shout_b", &"crowd_shout_c"]:
		shout_played = shout_played or crowd_audio._last_played.has(shout)
	check(crowd_audio._last_played.has(&"crowd_cheer")
		and crowd_audio._last_played.has(&"crowd_boo") and shout_played,
		"Cheer, boo and random shout events reach the audio mixer")
	check(arena._crowd.ambient_shout_left <= 3.0,
		"The first ambient shout happens early enough to hear in a short match")
	var ambience_script = preload("res://Scripts/StageAmbience.gd")
	var tokyo_ambience = ambience_script.new()
	tokyo_ambience.setup("tokyo")
	check(tokyo_ambience.actors.all(func(actor): return actor.kind in ["petals", "whiteeye"])
		and Vector2(tokyo_ambience.actors[0].path[0]) == Vector2(-144,-287),
		"Tokyo rotates sakura and a local white-eye on its annotated aerial route")
	tokyo_ambience.free()
	var orlando_ambience = ambience_script.new()
	orlando_ambience.setup("orlando")
	check(orlando_ambience.actors.all(func(actor): return actor.kind in ["bird", "ibis"])
		and Vector2(orlando_ambience.actors[0].path[0]) == Vector2(-330,-242),
		"Orlando uses its annotated skyline route and local ibis rotation")
	orlando_ambience.free()
	var orlando_crowd: Array = venue_layers.crowd("orlando")
	check(orlando_crowd[0].all(func(point): return Vector2(point).x >= -490.0)
		and orlando_crowd[1].all(func(point): return Vector2(point).x <= 490.0)
		and orlando_crowd[0].all(func(point): return Vector2(point).y <= 165.0)
		and orlando_crowd[1].all(func(point): return Vector2(point).y <= 165.0),
		"Orlando spectators keep their full silhouettes clear of the foreground lamps")
	var topeka_crowd: Array = venue_layers.crowd("topeka")
	var washington_crowd: Array = venue_layers.crowd("washington")
	check(Vector2(topeka_crowd[1][3]).x >= 420.0,
		"Topeka's lower-right spectator stays outside the pit boundary")
	check(Vector2(washington_crowd[1][3]).x >= 420.0,
		"Washington's lower-right spectator stays outside the pit boundary")
	var final_guide_routes := {
		"wiesbaden":[Vector2(-97,-36),Vector2(152,-18)],
		"phoenix":[Vector2(-162,-32),Vector2(209,-32)],
		"taos":[Vector2(-376,-90),Vector2(455,-94)],
		"tokyo":[Vector2(-144,-287),Vector2(194,-287)],
		"topeka":[Vector2(-310,-280),Vector2(78,-280)],
		"washington":[Vector2(282,-256),Vector2(596,-258)],
	}
	for city_id in final_guide_routes:
		var route: Array = venue_layers.motion(city_id)[0].path
		var expected: Array = final_guide_routes[city_id]
		check(Vector2(route[0]) == expected[0] and Vector2(route[-1]) == expected[1],
			"Final placement-guide motion corridor is exact: " + city_id)
	check(venue_layers.motion("topeka")[0].choices.has("meadowlark")
		and venue_layers.motion("tokyo")[0].choices.has("whiteeye")
		and venue_layers.motion("washington")[0].choices.has("eagle"),
		"Final aerial venues rotate locally recognizable birds")
	var berlin_ambience = ambience_script.new()
	berlin_ambience.setup("berlin")
	var berlin_bike: Dictionary = berlin_ambience.actors[0]
	check(berlin_ambience.actors.size() == 1
		and berlin_bike.kind in ["walker", "rollerblader", "dogwalker_dachshund", "bicycle"]
		and Vector2(berlin_bike.path[0]) == Vector2(-219,-35)
		and Vector2(berlin_bike.path[-1]) == Vector2(270,-35),
		"Berlin ground rotation, including its dachshund, stays on the annotated courtyard route")
	berlin_ambience.free()
	var belair_motion: Array = venue_layers.motion("belair")
	check(belair_motion[0].choices == ["bird", "cardinal"]
		and belair_motion[1].choices.has("rollerblader")
		and Vector2(belair_motion[0].path[0]) == Vector2(-303,-230)
		and Vector2(belair_motion[1].path[0]) == Vector2(-284,-25),
		"Bel Air separates annotated aerial and ground corridors")
	var boston_motion: Array = venue_layers.motion("boston")
	check(boston_motion.all(func(actor): return actor.choices == ["bird", "gull"])
		and Vector2(boston_motion[0].path[0]).y == -318,
		"Boston movement remains inside its annotated aerial corridor")
	var boston_crowd: Array = venue_layers.crowd("boston")
	check(Vector2(boston_crowd[0][-1]).x == -375
		and Vector2(boston_crowd[1][-1]).x == 375,
		"Boston's foreground spectators stay clear of the stone pillars")
	var brasilia_motion: Array = venue_layers.motion("brasilia")
	check(brasilia_motion.size() == 1 and brasilia_motion[0].choices.has("capybara")
		and brasilia_motion[0].choices.has("dogwalker")
		and Vector2(brasilia_motion[0].path[0]) == Vector2(-276,-18),
		"Brasília uses only its annotated ground corridor")
	var canberra_motion: Array = venue_layers.motion("canberra")
	check(canberra_motion[0].choices == ["bird", "cockatoo"]
		and canberra_motion[1].choices.has("dogwalker_kelpie")
		and canberra_motion[1].choices.has("kangaroo")
		and Vector2(canberra_motion[0].path[0]) == Vector2(-72,-315)
		and Vector2(canberra_motion[1].path[0]) == Vector2(-247,-50),
		"Canberra separates annotated aerial and ground corridors")
	var annapolis_ambience = ambience_script.new()
	annapolis_ambience.setup("annapolis")
	check(annapolis_ambience.actors[0].kind in ["bird", "oriole"]
		and Vector2(annapolis_ambience.actors[0].path[0]).x == -235.0
		and annapolis_ambience.actors[1].kind in ["walker", "rollerblader", "dogwalker", "bicycle"]
		and Vector2(annapolis_ambience.actors[1].path[0]).y == -67.0,
		"Annapolis follows the annotated bird and ground-movement corridors")
	annapolis_ambience.free()
	var chicago_ambience = ambience_script.new()
	chicago_ambience.setup("chicago")
	var chicago_train: Dictionary = chicago_ambience.actors[0]
	check(chicago_train.kind == "train" and chicago_train.periodic
		and not chicago_train.active and chicago_train.wait_min >= 15.0,
		"Chicago train makes periodic passes instead of looping constantly")
	check(chicago_train.path.size() >= 5
		and float(chicago_train.start_size) > float(chicago_train.end_size),
		"Chicago train follows the rail perspective and shrinks toward the vanishing point")
	chicago_train.active = true
	chicago_train.travel = float(chicago_train.path_length) * 0.5
	chicago_ambience.actors[0] = chicago_train
	chicago_ambience._process(0.0)
	chicago_train = chicago_ambience.actors[0]
	check(float(chicago_train.render_size) < float(chicago_train.start_size)
		and float(chicago_train.render_size) > float(chicago_train.end_size),
		"Chicago train interpolates its rendered size during a pass")
	chicago_ambience.free()
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
	for crowd_sound in ["crowd_cheer", "crowd_boo", "crowd_shout_a", "crowd_shout_b", "crowd_shout_c"]:
		check(ResourceLoader.exists("res://Assets/Audio/%s.wav" % crowd_sound),
			"Crowd reaction imports: %s" % crowd_sound)
	check(ResourceLoader.exists("res://Assets/Icon/gaga-pit-icon-1024.png")
		and ResourceLoader.exists("res://Assets/Icon/gaga-pit-icon-512.png"),
		"Octagonal Gaga pit app-store icon masters import")
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
	check(league._next_stage == 0 and league._retry_button.text == "CONTINUE TO GAME 2"
		and not is_instance_valid(league._tour_timer),
		"Game 1 pauses on the tables until Continue starts Game 2")
	check("SEASON TABLE" in league._overlay_note.text,
		"Between-game pause displays the complete season table")
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
	check(game_two._next_stage == 1 and game_two._retry_button.text == "CONTINUE TO NEXT CITY"
		and not is_instance_valid(game_two._tour_timer),
		"Clinched series pauses on the season table before the next city")
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
