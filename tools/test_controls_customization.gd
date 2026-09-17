extends SceneTree
const ART = preload("res://Scripts/FighterArt.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")
	create_timer(45).timeout.connect(func() -> void: quit(1))

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: ",description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func send(event: InputEvent) -> void:
	var physical := event.duplicate() as InputEvent
	# Headless windows are 64x64: feed physical coordinates, allowing Godot
	# to apply the same viewport/letterbox transform as a real touchscreen.
	if physical is InputEventScreenTouch or physical is InputEventScreenDrag:
		physical.position = root.get_final_transform() * physical.position
	Input.parse_input_event(physical)
	Input.flush_buffered_events()

func button(code: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = code
	event.pressed = pressed
	send(event)

func axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = code
	event.axis_value = value
	send(event)

func touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	send(event)

func _run() -> void:
	var state := root.get_node("GameState")
	state.profiles_path = "user://controls-test-%d.cfg" % OS.get_process_id()
	state.progress_path = "user://controls-tour-%d.cfg" % OS.get_process_id()
	state._load_profiles()
	var legacy := ART.normalize({"name":"OLD PLAYER","skin":5,"hair_style":4,"accent":"429465"})
	check(legacy.pants == "429465" and legacy.shoes == "429465" and legacy.skin == 5,
		"Legacy outfits migrate without changing old skin or pants colours")
	check(ART.SKINS.size() == 12 and ART.SKIN_NAMES.size() == 12 and ART.STYLES.size() == 12,
		"Twelve named skin shades and twelve hairstyles are available")
	for slot in 3:
		var profile := ART.defaults("CUSTOM %d" % slot)
		profile.merge({"body_type":slot+1,"eye_color":slot+1,"accessory":slot+1,
			"pattern":slot+1,"pants":"7853a6","shoes":"e8e2cf","hair_style":slot+7,
			"skin":slot+8,"jersey":"337cbe","accent":"ed6731"},true)
		check(state.save_player(slot,profile) == OK,"Expanded profile %d saves" % slot)
	state._load_profiles()
	for slot in 3:
		var saved: Dictionary = state.player_profiles[slot]
		check(saved.body_type == slot+1 and saved.accessory == slot+1 and saved.eye_color == slot+1
			and saved.pants == "7853a6" and saved.hair_style == slot+7 and saved.pattern == slot+1,
			"Expanded profile %d restores every new option" % slot)
	var look := ART.defaults()
	look.pattern = 1
	var first := ART.frame(look,0,0)
	look.accent = "ed6731"
	var second := ART.frame(look,0,0)
	check(first.get_pixel(30,77) == second.get_pixel(30,77) and first.get_data() != second.get_data(),
		"Two-tone shirt colour changes do not recolour the shorts")
	var count := InputMap.action_get_events("strike").size()
	state._ensure_input_actions()
	check(InputMap.action_get_events("strike").size() == count,"Input setup is idempotent")
	state.start_campaign_stage(0)
	var arena := (load("res://Scenes/GameArena.tscn") as PackedScene).instantiate()
	arena.touch_controls = true
	root.add_child(arena)
	await create_timer(2.45).timeout
	arena._opening_safe = 0.0 # Opening-toss protection is tested separately.
	arena.set_physics_process(false)
	for fighter in arena._alive:
		fighter.set_physics_process(false)
	var player := arena.get_node("Player") as PlayerCharacter
	var ball := arena.ball as GagaBall
	ball.freeze = true
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	key.pressed = true
	send(key)
	player.handle_actions(0)
	check(player._jump_elapsed == 0,"Keyboard J starts a jump")
	key.pressed = false
	send(key)
	check(not player.clears_ball(),"Takeoff is vulnerable before feet clear the ball")
	player._update_jump(0.3)
	ball.linear_velocity = Vector2.RIGHT * 600
	ball.repeat_toucher = null
	arena._on_below_waist_hit(ball,player)
	check(player.is_alive and player.clears_ball() and player.sprite.position.y < -50,
		"Jump apex visually lifts the player and avoids a live ball")
	player.begin_charge()
	check(not player.is_charging(),"Airborne players cannot slap a grounded ball")
	var elapsed := player._jump_elapsed
	player.start_jump()
	player.start_dash()
	check(player._jump_elapsed == elapsed and not player.is_dashing(),"Jump cannot stack or chain into dash immunity")
	player._update_jump(0.4)
	check(not player.clears_ball() and player.sprite.position == Vector2.ZERO,"Landing restores visual position and vulnerability")
	player.start_jump()
	check(player._jump_elapsed < 0,"Jump cooldown prevents immediate repeat jumps")
	var victim := arena._alive[1] as Character
	victim.start_jump()
	victim._update_jump(victim.jump_duration)
	arena._on_below_waist_hit(ball,victim)
	check(not victim.is_alive,"A live ball eliminates a fighter after landing")
	await create_timer(0.6).timeout
	check(absf(victim.sprite.rotation) > 1 and victim.sprite.scale.y < 1,
		"Knockout animates a visible fallen body")
	# One finger steers while another makes a sub-frame slap tap.
	var joystick := arena.get_node("HUD/VirtualJoystick")
	touch(0,Vector2(150,580),true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(215,580)
	send(drag)
	check(player.get_move_input().x > 0.3 and not player._strike_pressed,
		"Touch stick steers without an emulated-mouse slap")
	player.facing = Vector2.RIGHT
	ball.position = player.position + Vector2(45,0)
	ball.repeat_toucher = null
	player._strike_cooldown_left = 0
	var slap := arena.get_node("HUD/StrikeButton")
	touch(1,slap.get_global_rect().get_center(),true)
	touch(1,slap.get_global_rect().get_center(),false)
	player.handle_actions(0)
	check(ball.last_touched_by == player and not player.is_charging(),"Short touchscreen tap slaps while joystick finger remains held")
	check(get_nodes_in_group(&"comic_impacts").size() > 0,"A connected slap creates its comic impact")
	var jump := arena.get_node("HUD/JumpButton")
	touch(2,jump.get_global_rect().get_center(),true)
	check(jump._touch_index == 2 and joystick._touch_index == 0 and player._jump_pressed,
		"Jump and joystick independently track simultaneous fingers")
	arena._toggle_pause()
	check(jump._touch_index == -1 and joystick._touch_index == -1 and not Input.is_action_pressed("jump")
		and not Input.is_action_pressed("move_right"),"Pause releases every touch action")
	arena._toggle_pause()
	# Feed real Joypad events through Godot's InputMap, not action stubs.
	axis(JOY_AXIS_LEFT_X,0.1)
	check(player.get_move_input().length() == 0,"Controller deadzone rejects stick drift")
	axis(JOY_AXIS_LEFT_X,0.9)
	check(player.get_move_input().x > 0.7,"Left controller stick moves the player")
	axis(JOY_AXIS_LEFT_X,0)
	player._mouse_aim = true
	axis(JOY_AXIS_RIGHT_Y,-1)
	check(player.get_aim_direction(Vector2.ZERO).y < -0.9 and not player._mouse_aim,
		"Right stick takes aim control back from the mouse")
	axis(JOY_AXIS_RIGHT_Y,0)
	button(JOY_BUTTON_DPAD_LEFT,true)
	check(player.get_move_input().x < -0.9,"Controller D-pad moves the player")
	button(JOY_BUTTON_DPAD_LEFT,false)
	player._jump_cooldown_left = 0
	button(JOY_BUTTON_A,true)
	player.handle_actions(0)
	check(player._jump_elapsed == 0,"Controller A starts a jump")
	button(JOY_BUTTON_A,false)
	player.settle_jump()
	player._dash_cooldown_left = 0
	button(JOY_BUTTON_B,true)
	player.handle_actions(0)
	check(player.is_dashing(),"Controller B starts a dash")
	button(JOY_BUTTON_B,false)
	player._dash_time_left = 0
	player._strike_cooldown_left = 0
	ball.repeat_toucher = null
	button(JOY_BUTTON_X,true)
	player.handle_actions(0.2)
	check(player.is_charging(),"Holding controller X charges the slap")
	button(JOY_BUTTON_X,false)
	player.handle_actions(0)
	check(not player.is_charging() and ball.repeat_toucher == player,"Releasing controller X connects the slap")
	button(JOY_BUTTON_START,true)
	check(paused and arena._resume_button.has_focus(),"Controller Start pauses and focuses Resume")
	button(JOY_BUTTON_START,false)
	button(JOY_BUTTON_B,true)
	check(not paused,"Controller B resumes from pause")
	button(JOY_BUTTON_B,false)
	arena._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(paused,"Losing app focus safely pauses the match")
	arena._toggle_pause()
	arena.queue_free()
	await process_frame
	var creator := (load("res://Scenes/PlayerCreator.tscn") as PackedScene).instantiate()
	root.add_child(creator)
	creator._show_tab(1)
	check(creator._outfit.visible and not creator._appearance.visible and creator._options.hat.has_focus(),
		"Creator outfit tab is controller focusable")
	var before: String = creator._drafts[creator._slot].pants
	creator._options.accent.item_selected.emit(1)
	check(creator._drafts[creator._slot].pants == before,"Creator shirt secondary is independent from pants")
	creator.queue_free()
	await process_frame
	var menu := (load("res://Scenes/MainMenu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	menu._on_campaign_pressed()
	check(menu._league_panel.get_node("NewCareer").has_focus(),"League menu focuses New Career for a new player")
	button(JOY_BUTTON_A,true)
	button(JOY_BUTTON_A,false)
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.name == "GameArena","Controller A launches a stage from the menu")
	current_scene._end_round(false)
	button(JOY_BUTTON_B,true)
	button(JOY_BUTTON_B,false)
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.name == "MainMenu","Controller B safely leaves the results scene")
	change_scene_to_file("res://Scenes/PlayerCreator.tscn")
	await process_frame
	await process_frame
	button(JOY_BUTTON_B,true)
	button(JOY_BUTTON_B,false)
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.name == "MainMenu","Controller B safely leaves an unchanged creator")
	current_scene.queue_free()
	root.get_node("RetroSfx").stop_all()
	await create_timer(0.3).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.profiles_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.progress_path))
	print("CONTROL / CUSTOMIZATION CHECKS: %d passed: %d failed: %d" % [checks,checks-failures,failures])
	quit(1 if failures else 0)
