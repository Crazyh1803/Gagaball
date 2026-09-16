extends SceneTree
## Run without --headless to render a real viewport to a PNG.
## godot --path . --script res://tools/capture_preview.gd -- --arena

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var arena_mode := OS.get_cmdline_user_args().has("--arena")
	var scene := load("res://Scenes/GameArena.tscn" if arena_mode
			else "res://Scenes/MainMenu.tscn") as PackedScene
	var instance := scene.instantiate()
	root.add_child(instance)
	if OS.get_cmdline_user_args().has("--campaign"):
		instance._on_campaign_pressed()
	await create_timer(3.0).timeout
	if OS.get_cmdline_user_args().has("--pause"):
		instance._toggle_pause()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://.godot/preview-arena.png" if arena_mode else "res://.godot/preview-menu.png"
	if OS.get_cmdline_user_args().has("--campaign"):
		path = "res://.godot/preview-campaign.png"
	if OS.get_cmdline_user_args().has("--pause"):
		path = "res://.godot/preview-pause.png"
	var error := root.get_texture().get_image().save_png(path)
	print("Preview saved: ", path, " (", error, ")")
	quit(error)
