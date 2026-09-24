extends SceneTree
const ART = preload("res://Scripts/FighterArt.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")
	create_timer(45.0).timeout.connect(func() -> void: quit(1))

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func _run() -> void:
	var state := root.get_node("GameState")
	# Isolate all disk writes from the user's real players and campaign.
	state.profiles_path = "user://test-players-%d.cfg" % OS.get_process_id()
	state.progress_path = "user://test-tour-%d.cfg" % OS.get_process_id()
	state._load_profiles()
	check(state.player_profiles.size() == 3, "Three independent player slots exist")
	for slot in 3:
		var p := ART.defaults("TEST %d" % slot)
		p.merge({"hat": slot + 1, "beard": slot + 1, "skin": slot + 3,
			"hair_style": slot + 2, "jersey": ART.COLORS[slot + 1]}, true)
		check(state.save_player(slot, p) == OK, "Slot %d saves to disk" % slot)
	state.player_profiles.clear()
	state._load_profiles()
	for slot in 3:
		check(state.player_profiles[slot].name == "TEST %d" % slot
			and state.player_profiles[slot].hat == slot + 1
			and state.player_profiles[slot].skin == slot + 3,
			"Slot %d restores name and cosmetics from disk" % slot)
	check(state.active_player_slot == 2, "Equipped player survives reload")
	var clean := ART.normalize({"name": "  ", "hat": 90, "skin": -5, "jersey": "invalid"})
	check(clean.name == "ROOKIE" and clean.hat == 3 and clean.skin == 0,
		"Incomplete or out-of-range cosmetics are normalized")
	var personal_name := ART.normalize({"name": "  DJ River-Kid  "})
	check(personal_name.name == "DJ River-Kid",
		"Player names preserve custom spelling, punctuation and casing")
	var good_path: String = state.profiles_path
	state.profiles_path = "user://missing-profile-test-folder/players.cfg"
	check(state.save_player(0, ART.defaults("UNSAVED")) != OK
		and state.player_profiles[0].name == "TEST 0" and state.active_player_slot == 2,
		"Failed disk save does not replace saved slots or equipped player")
	state.profiles_path = good_path
	var names := {}
	for index in state.CAMPAIGN_STAGES.size():
		var home: Dictionary = state.home_fighter(index)
		names[home.name] = true
		var sheet := ART.sheet(home)
		check(sheet.get_size() == Vector2(ART.W * 8, ART.H * 3),
			"%s has complete 24-frame hometown art" % home.name)
	check(names.size() == 10, "Every arena has a distinct home character")
	var creator := (load("res://Scenes/PlayerCreator.tscn") as PackedScene).instantiate()
	root.add_child(creator)
	creator._select_slot(0)
	creator._name.text = "NEW NAME"
	creator._name.text_changed.emit("NEW NAME")
	creator._options["hat"].item_selected.emit(2)
	creator._select_slot(1)
	creator._select_slot(0)
	check(creator._name.text == "NEW NAME" and creator._drafts[0].hat == 2,
		"Creator retains unsaved drafts when switching slots")
	creator._save()
	check(state.current_player().name == "NEW NAME" and state.current_player().hat == 2,
		"Creator Save & Use commits and equips edited player")
	creator.queue_free()
	await process_frame
	state.start_campaign_stage(2)
	var bayou := (load("res://Scenes/GameArena.tscn") as PackedScene).instantiate()
	root.add_child(bayou)
	var minimum_y := INF
	for point in bayou._octagon_points():
		minimum_y = minf(minimum_y, point.y + 360)
	check(minimum_y > 430, "Bayou floor lies below the waterline on the dirt clearing")
	check(bayou._alive[1].display_name == "JET", "Bayou spawns its home rival")
	check(bayou.get_node("Player").display_name == "NEW NAME"
		and bayou.get_node("Player/Sprite").texture.get_width() == ART.W * 8,
		"Match uses the equipped player's name and new sprite art")
	bayou._toggle_pause()
	var countdown: int = bayou._countdown_left
	await create_timer(0.9).timeout
	check(bayou._countdown_left == countdown and bayou.ball.freeze,
		"Pausing during ready phase pauses the countdown")
	bayou._toggle_pause()
	await create_timer(2.5).timeout
	bayou._end_round(false)
	check(bayou._next_stage == -1, "Loss does not advance the tour")
	bayou.queue_free()
	await process_frame
	state.start_campaign_stage(0)
	change_scene_to_file("res://Scenes/GameArena.tscn")
	await process_frame
	await process_frame
	await create_timer(2.5).timeout
	var arena := current_scene
	for fighter in arena._alive.duplicate():
		if not fighter is PlayerCharacter:
			arena._eliminate(fighter)
	check(arena._next_stage == 1 and arena._retry_button.text == "NEXT CITY NOW",
		"Tour victory queues next city and offers an immediate continue")
	await create_timer(4.15).timeout
	check(current_scene != arena and state.match_config.stage_index == 1,
		"Tour automatically loads the next city after four seconds")
	check(current_scene.get_node("Player").display_name == "NEW NAME",
		"Equipped player carries into the next city")
	await create_timer(2.5).timeout
	current_scene._end_round(true)
	current_scene._return_to_menu()
	await process_frame
	await process_frame
	await create_timer(4.2).timeout
	check(current_scene.name == "MainMenu", "Returning to menu cancels pending tour travel")
	state.start_campaign_stage(9)
	change_scene_to_file("res://Scenes/GameArena.tscn")
	await process_frame
	await process_frame
	await create_timer(2.5).timeout
	current_scene._end_round(true)
	check(current_scene._overlay_title.text == "TOUR CHAMPION" and current_scene._next_stage == -1,
		"Final city celebrates completion without loading a nonexistent stage")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.profiles_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.progress_path))
	print("PROFILE / TOUR CHECKS: %d passed: %d failed: %d" % [checks, checks - failures, failures])
	current_scene.queue_free()
	root.get_node("RetroSfx").stop_all()
	await create_timer(0.3).timeout
	quit(1 if failures else 0)
