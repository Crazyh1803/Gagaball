extends SceneTree
## Run without --headless to render a real viewport to a PNG.
## godot --path . --script res://tools/capture_preview.gd -- --arena

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var arena_mode := args.has("--arena")
	var stage_index := -1
	var custom_id := ""
	var state := root.get_node("GameState")
	for arg in args:
		if arg.begins_with("--stage="):
			stage_index = int(arg.trim_prefix("--stage="))
		if arg.begins_with("--city="):
			custom_id = arg.trim_prefix("--city=")
			state.start_friendly(6, 1, custom_id)
			arena_mode = true
		if arg.begins_with("--league="):
			var division := int(arg.trim_prefix("--league="))
			state.careers[state.active_player_slot] = state.SEASON.create(division, state.current_player())
			custom_id = "league-%d" % division
			if args.has("--season-end"):
				for fixture in state.CATALOG.ROUTES[division].size():
					var order: Array = []
					for club in state.SEASON.table(state.career(), division): order.append(club.id)
					while int(state.career().round) == fixture:
						state.SEASON.record(state.career(), order, fixture, int(state.career().series.rounds))
			if not args.has("--campaign"):
				state.start_league_round()
				arena_mode = true
	if args.has("--home"):
		state.player_profiles[state.active_player_slot].home_city = state.city_id()
	if stage_index >= 0:
		root.get_node("GameState").start_campaign_stage(stage_index)
		arena_mode = true
	var scene := load("res://Scenes/GameArena.tscn" if arena_mode
			else "res://Scenes/MainMenu.tscn") as PackedScene
	if args.has("--creator"):
		scene = load("res://Scenes/PlayerCreator.tscn") as PackedScene
	var instance := scene.instantiate()
	root.add_child(instance)
	if args.has("--outfit"):
		instance._show_tab(1)
	if args.has("--sample-look"):
		instance._drafts[instance._slot].merge({"hair_style":8,"skin":9,"eye_color":2,
			"body_type":2,"accessory":1,"pattern":1,"jersey":"337cbe","accent":"ed6731",
			"pants":"242938","shoes":"e8e2cf","hat":0},true)
		instance._select_slot(instance._slot)
	if OS.get_cmdline_user_args().has("--campaign"):
		instance._on_campaign_pressed()
	await create_timer(0.15 if args.has("--lineup") else 3.0).timeout
	if args.has("--lineup") and arena_mode:
		instance.message_label.hide()
	if OS.get_cmdline_user_args().has("--pause"):
		instance._toggle_pause()
	if args.has("--result") and arena_mode:
		for fighter in instance._alive.duplicate():
			if instance._alive.size() > 1:
				instance._eliminate(fighter)
		await create_timer(0.9).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://.godot/preview-arena.png" if arena_mode else "res://.godot/preview-menu.png"
	if OS.get_cmdline_user_args().has("--campaign"):
		path = "res://.godot/preview-campaign.png"
	if OS.get_cmdline_user_args().has("--pause"):
		path = "res://.godot/preview-pause.png"
	if stage_index >= 0:
		path = "res://.godot/preview-stage-%02d.png" % stage_index
	if custom_id != "": path = "res://.godot/preview-%s%s.png" % [custom_id, "-table" if args.has("--campaign") else ""]
	if args.has("--creator"):
		path = "res://.godot/preview-creator.png"
		if args.has("--outfit"):
			path = "res://.godot/preview-outfit.png"
	var error := root.get_texture().get_image().save_png(path)
	print("Preview saved: ", path, " (", error, ")")
	instance.queue_free()
	root.get_node("RetroSfx").stop_all()
	await create_timer(0.3).timeout
	quit(error)
