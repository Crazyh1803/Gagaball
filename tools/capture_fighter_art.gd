extends SceneTree
## Render the real game sprites at inspection scale, without modifying saves.
const ART = preload("res://Scripts/FighterArt.gd")

func _initialize() -> void:
	call_deferred("_capture")

func label(parent: Node, text: String, at: Vector2, size: int, color: Color) -> void:
	var node := Label.new()
	node.text = text
	node.position = at
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)

func _capture() -> void:
	var page := Node2D.new()
	page.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(page)
	var background := ColorRect.new()
	background.color = Color("182633")
	background.size = Vector2(1280,720)
	page.add_child(background)
	var poses := OS.get_cmdline_user_args().has("--poses")
	label(page, "PIT LEGENDS  /  PIXEL ART STUDY", Vector2(42,22), 32, Color("ffd777"))
	label(page, "Warm light. Cool shadows. Woven jerseys. Street-court attitude.", Vector2(43,66), 18, Color("a7c1cc"))
	var state := root.get_node("GameState")
	if poses:
		var texture := ART.sheet(state.current_player())
		for row in 3:
			for col in 8:
				var sprite := Sprite2D.new()
				sprite.texture = texture
				sprite.hframes = 8
				sprite.vframes = 3
				sprite.frame = row * 8 + col
				sprite.scale = Vector2(1.6,1.6)
				sprite.position = Vector2(80 + col * 158,190 + row * 185)
				page.add_child(sprite)
	else:
		for index in 10:
			var profile: Dictionary = state.home_fighter(index)
			var x := 128 + index % 5 * 256
			var y := 214 + index / 5 * 280
			var sprite := Sprite2D.new()
			sprite.texture = ART.sheet(profile)
			sprite.hframes = 8
			sprite.vframes = 3
			sprite.scale = Vector2(2.2,2.2)
			sprite.position = Vector2(x,y)
			page.add_child(sprite)
			label(page, profile.name, Vector2(x-45,y+106), 22, Color("ffd777"))
			label(page, str(state.CAMPAIGN_STAGES[index].location), Vector2(x-98,y+138), 16, Color("a7c1cc"))
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://.godot/fighter-poses.png" if poses else "res://.godot/fighter-roster.png"
	var error := root.get_texture().get_image().save_png(path)
	print("Art preview: ", path, " error: ", error)
	page.queue_free()
	await process_frame
	quit(error)
