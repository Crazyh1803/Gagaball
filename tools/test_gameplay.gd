extends SceneTree
## Deterministic integration checks against the real scenes/physics.
## godot --headless --path . --script res://tools/test_gameplay.gd

var _failures := 0
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")
	# A broken dependency must fail the test instead of hanging forever.
	create_timer(50.0).timeout.connect(func() -> void:
		push_error("Gameplay test exceeded 50 seconds")
		quit(1))

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func _run() -> void:
	seed(42)
	var state := root.get_node("GameState")
	_check(state.CAMPAIGN_STAGES[0]["name"] == "Aukamm Elementary"
			and state.CAMPAIGN_STAGES[0]["location"] == "Wiesbaden, Germany",
			"Campaign opens at Aukamm Elementary in Wiesbaden")
	var stage_backdrops := {}
	var wall_palettes := {}
	var court_tints := {}
	for stage in state.CAMPAIGN_STAGES:
		var backdrop: String = stage.get("backdrop", "")
		stage_backdrops[backdrop] = true
		wall_palettes[stage.get("wall_color", "")] = true
		court_tints[stage.get("court_tint", "")] = true
		_check(ResourceLoader.exists("res://Assets/Backgrounds/Stages/%s.png" % backdrop),
				"%s has an imported background" % stage["location"])
	_check(stage_backdrops.size() == state.CAMPAIGN_STAGES.size(),
			"Every campaign city has a distinct background")
	_check(wall_palettes.size() == state.CAMPAIGN_STAGES.size()
			and court_tints.size() == state.CAMPAIGN_STAGES.size(),
			"Every campaign city has a distinct pit palette")
	state.start_friendly(4, 1)
	var arena := (load("res://Scenes/GameArena.tscn") as PackedScene).instantiate()
	root.add_child(arena)
	var pit_bounds := Rect2(arena._octagon_points()[0], Vector2.ZERO)
	for point in arena._octagon_points():
		pit_bounds = pit_bounds.expand(point)
	_check(pit_bounds.size.y < pit_bounds.size.x * 0.52,
			"Pit geometry matches the revised high-angle ground plane")
	_check(pit_bounds.position.y >= 0.0 and pit_bounds.size.x > 620.0,
			"Large pit stays entirely in the foreground courtyard")
	_check(arena.get_node("NeighborhoodBackdrop").texture != null,
			"The configured city background is visible in the live arena")
	var far_wall: StaticBody2D = arena.get_node("Wall0")
	var near_wall: StaticBody2D = arena.get_node("Wall0")
	for wall_index in arena.pit_sides:
		var candidate := arena.get_node("Wall%d" % wall_index) as StaticBody2D
		if candidate.position.y < far_wall.position.y:
			far_wall = candidate
		if candidate.position.y > near_wall.position.y:
			near_wall = candidate
	_check(far_wall.has_node("BoardFace") and near_wall.has_node("BoardFace")
			and far_wall.z_index < near_wall.z_index,
			"Far interior and near exterior board faces create court depth")
	_check(float(far_wall.get_node("BoardFace").get_meta("visual_height"))
			> float(near_wall.get_node("BoardFace").get_meta("visual_height")),
			"Near wall uses a low gameplay cutaway")
	var far_shape := (far_wall.get_child(0) as CollisionShape2D).shape as RectangleShape2D
	var near_shape := (near_wall.get_child(0) as CollisionShape2D).shape as RectangleShape2D
	_check(near_shape.size.x > far_shape.size.x,
			"Pit side lengths converge toward the background vanishing point")
	var player := arena.get_node("Player") as Character
	var ball := arena.get_node("Ball") as GagaBall
	_check(ball.position == arena._toss_start and ball.get_node("BallSprite").position.y < 0,
			"Opening ball starts in the home representative's hand")
	_check(ball.freeze and not player.is_physics_processing(), "Countdown freezes the roster and ball")
	await create_timer(2.5).timeout
	_check(arena._round_started and not ball.freeze, "Countdown starts the round")
	arena._opening_safe = 0.0 # Test normal refereeing after the safe opening.
	arena.set_physics_process(false)
	for fighter in arena._alive:
		fighter.set_physics_process(false)
	ball.freeze = true
	player.position = Vector2(0, 180)
	player.facing = Vector2.UP
	ball.position = player.position + Vector2(0, -55)
	ball.repeat_toucher = null
	player.begin_charge()
	player.release_strike()
	_check(ball.repeat_toucher == player and ball.linear_velocity.y < -500.0, "Tap slap connects and uses current aim")
	# Exercise actual input, including a tap shorter than one physics tick.
	var press := InputEventAction.new()
	press.action = &"strike"
	press.pressed = true
	var release := InputEventAction.new()
	release.action = &"strike"
	release.pressed = false
	ball.repeat_toucher = null
	player._strike_cooldown_left = 0.0
	Input.parse_input_event(press)
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	player.handle_actions(1.0 / 60.0)
	_check(not player.is_charging() and ball.repeat_toucher == player, "Sub-frame input tap strikes without sticking in charge")
	var shot := ball.linear_velocity
	var blocked := [false]
	player.strike_blocked.connect(func(_ball: GagaBall) -> void: blocked[0] = true)
	player._strike_cooldown_left = 0.0
	player.begin_charge()
	player.release_strike()
	_check(blocked[0] and ball.linear_velocity == shot, "Double-touch is rejected")
	ball._on_body_entered(arena.get_node("Wall0"))
	_check(ball.repeat_toucher == null, "Wall bounce relegalizes a strike")
	player._strike_cooldown_left = 0.0
	player.begin_charge()
	player.set_charge(1.0)
	player.release_strike()
	_check(is_equal_approx(ball.linear_velocity.length(), 900.0), "Full charge produces a bounded power slap")
	ball._on_body_entered(player)
	_check(ball.repeat_toucher == player, "Body contact cannot overwrite legal-strike ownership")
	ball.repeat_toucher = null
	ball.position = player.position + Vector2(0, -100)
	player._strike_cooldown_left = 0.0
	player.begin_charge()
	player.release_strike()
	_check(player._strike_time_left > 0.0, "Whiff keeps a short active connection window")
	ball.position = player.position + Vector2(0, -60)
	player._try_connect_strike()
	_check(ball.repeat_toucher == player, "Buffered slap connects when ball enters reach")
	ball.repeat_toucher = null
	ball.linear_velocity = Vector2.DOWN * 500
	player.start_dash()
	arena._on_below_waist_hit(ball, player)
	_check(player.is_alive, "Dash evades a live incoming ball")
	player._dash_time_left = 0.0
	ball.linear_velocity = Vector2.DOWN * 80
	arena._on_below_waist_hit(ball, player)
	_check(player.is_alive, "Slow rolls are harmless")
	ball.repeat_toucher = player
	ball.linear_velocity = Vector2.DOWN * 500
	arena._on_below_waist_hit(ball, player)
	_check(player.is_alive, "Own strike is harmless before a wall bounce")
	ball.repeat_toucher = null
	arena._toggle_pause()
	_check(paused and arena._overlay.visible, "Pause exposes the resume controls")
	arena._toggle_pause()
	_check(not paused and not arena._overlay.visible, "Resume restores play")
	# Sweep across an opponent in one sample, deliberately faster than
	# an Area2D entry callback can reliably observe.
	var opponent := arena._alive[1] as Character
	opponent.position = Vector2(100, 0)
	ball.position = Vector2(150, 0)
	ball.linear_velocity = Vector2.RIGHT * 900
	arena._previous_ball_positions[ball] = Vector2(50, 0)
	arena._physics_process(1.0 / 60.0)
	_check(not opponent.is_alive and arena._alive.size() == 3, "Swept ball hits eliminate opponents and update roster")
	state.match_config["double_ball"] = true
	arena._eliminate(arena._alive[1])
	await process_frame
	_check(get_nodes_in_group(&"balls").size() == 2, "Half-roster event spawns the second ball")
	var second := get_nodes_in_group(&"balls")[1] as GagaBall
	second.freeze = true
	second.position = player.position + Vector2(0, -50)
	ball.position = player.position + Vector2(0, -55)
	ball.repeat_toucher = player
	player._strike_cooldown_left = 0.0
	player.begin_charge()
	player.release_strike()
	_check(second.repeat_toucher == player, "An illegal repeat ball cannot block a legal second-ball slap")
	ball.repeat_toucher = null
	ball.linear_velocity = Vector2.DOWN * 500
	arena._on_below_waist_hit(ball, player)
	_check(not player.is_alive and arena._round_over, "A live hit ends the human round")
	_check(arena._overlay.visible and not arena._resume_button.visible, "Results offer rematch instead of ejecting to menu")
	for fighter in arena._alive:
		_check(not fighter.is_physics_processing(), "Survivors stop after the round")
	arena.queue_free()
	await process_frame
	var menu := (load("res://Scenes/MainMenu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	menu._on_campaign_pressed()
	_check(menu.stage_list.get_child_count() == 10, "All ten campaign stages appear")
	_check(not menu.stage_list.get_child(0).disabled, "First campaign stage is playable")
	menu._on_friendly_pressed()
	_check(menu._selected_count() == 4 and menu._selected_difficulty() == 0,
			"Friendly setup retains valid defaults")
	menu.queue_free()
	await process_frame
	state.start_friendly(4, 0)
	var victory := (load("res://Scenes/GameArena.tscn") as PackedScene).instantiate()
	root.add_child(victory)
	await create_timer(2.5).timeout
	for fighter in victory._alive.duplicate():
		if not fighter is PlayerCharacter:
			victory._eliminate(fighter)
	_check(victory._round_over and victory._overlay_title.text == "PIT CHAMPION",
			"Last human standing receives victory results")
	_check(victory.get_node("Player/Sprite").frame % 8 == Character.COL_VICTORY,
			"Winner displays the victory pose despite stopped physics")
	victory.queue_free()
	await process_frame
	# Smoke-test every roster size/difficulty with actual AI and physics.
	for count in [4, 6, 8]:
		state.start_friendly(count, (count / 2 - 2) as int)
		var match_scene := (load("res://Scenes/GameArena.tscn") as PackedScene).instantiate()
		root.add_child(match_scene)
		await create_timer(2.6).timeout
		_check(match_scene._initial_count == count, "%d-player roster spawns" % count)
		await create_timer(6.0).timeout
		_check(match_scene._alive.size() < count or match_scene.ball.last_touched_by != null,
				"%d-player match has knockouts or legal strikes" % count)
		match_scene.queue_free()
		await process_frame
	# Reproduce the real stage-button signal order: the first callback removes
	# MainMenu from the tree, then its click-sound callback still has to run.
	var transition_menu := (load("res://Scenes/MainMenu.tscn") as PackedScene).instantiate()
	root.add_child(transition_menu)
	current_scene = transition_menu
	transition_menu._on_campaign_pressed()
	transition_menu.stage_list.get_child(0).pressed.emit()
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.name == "GameArena",
			"Campaign transition keeps the menu click sound safe during scene exit")
	print("GAMEPLAY CHECKS: ", _checks, " passed: ", _checks - _failures, " failed: ", _failures)
	current_scene.queue_free()
	root.get_node("RetroSfx").stop_all()
	await create_timer(0.3).timeout
	quit(1 if _failures else 0)
