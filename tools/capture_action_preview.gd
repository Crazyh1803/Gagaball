extends SceneTree
## Arrange live action poses for visual QA; does not modify player saves.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.get_node("GameState").start_campaign_stage(0)
	var arena := (load("res://Scenes/GameArena.tscn") as PackedScene).instantiate()
	arena.touch_controls = true
	root.add_child(arena)
	await create_timer(2.45).timeout
	arena.set_physics_process(false)
	for fighter in arena._alive:
		fighter.set_physics_process(false)
	arena.ball.freeze = true
	var player := arena.get_node("Player") as Character
	player.position = arena.pit_center_offset + Vector2(-130,55)
	player.start_jump()
	player._update_jump(0.3)
	player._update_sprite(0)
	var slapper := arena._alive[2] as Character
	slapper.position = arena.pit_center_offset + Vector2(-35,-30)
	slapper.facing = Vector2.RIGHT
	arena.ball.position = slapper.position + Vector2(55,0)
	arena.ball.repeat_toucher = null
	slapper._strike_cooldown_left = 0
	slapper.begin_charge()
	slapper.set_charge(1)
	slapper.release_strike()
	slapper._update_sprite(0)
	var victim := arena._alive[1] as Character
	victim.position = arena.pit_center_offset + Vector2(150,45)
	arena._eliminate(victim,arena.ball)
	arena.message_label.hide()
	await create_timer(0.24).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://.godot/preview-actions.png")
	print("Action preview saved; error: ",error)
	arena.queue_free()
	root.get_node("RetroSfx").stop_all()
	await create_timer(0.3).timeout
	quit(error)
