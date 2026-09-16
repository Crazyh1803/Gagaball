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
	state.start_friendly(4, 1)
	var arena := (load("res://Scenes/GameArena.tscn") as PackedScene).instantiate()
	root.add_child(arena)
	var player := arena.get_node("Player") as Character
	var ball := arena.get_node("Ball") as GagaBall
	_check(ball.freeze and not player.is_physics_processing(), "Countdown freezes the roster and ball")
	await create_timer(2.5).timeout
	_check(arena._round_started and not ball.freeze, "Countdown starts the round")
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
	print("GAMEPLAY CHECKS: ", _checks, " passed: ", _checks - _failures, " failed: ", _failures)
	quit(1 if _failures else 0)
