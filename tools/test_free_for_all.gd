extends SceneTree
## Real-time AI soak test: proves a CPU can legally knock out another CPU.

var cpu_outs := 0
var cpu_vs_cpu_outs := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	seed(1988)
	Engine.time_scale = 2.0
	var state := root.get_node("GameState")
	state.start_friendly(6, AIController.Difficulty.MEDIUM)
	var arena := (load("res://Scenes/GameArena.tscn") as PackedScene).instantiate()
	arena.fighter_eliminated.connect(_on_eliminated)
	root.add_child(arena)
	await create_timer(2.6).timeout
	var player := arena.get_node("Player") as PlayerCharacter
	# Keep the human observer out of AI target selection and immune so the
	# CPUs can finish their own free-for-all without an early game-over.
	player.remove_from_group(&"characters")
	player.set_physics_process(false)
	player._dash_time_left = 999.0
	player.position = Vector2(0, 255)
	var deadline := create_timer(25.0)
	while cpu_vs_cpu_outs == 0 and deadline.time_left > 0.0:
		await create_timer(0.25).timeout
	Engine.time_scale = 1.0
	print("CPU outs: ", cpu_outs, " | CPU-vs-CPU credited outs: ", cpu_vs_cpu_outs)
	root.get_node("RetroSfx").stop_all()
	arena.queue_free()
	await process_frame
	await process_frame
	if cpu_vs_cpu_outs == 0:
		push_error("No CPU eliminated another CPU during the free-for-all soak test")
		quit(1)
	else:
		print("PASS: CPUs target and eliminate one another")
		quit(0)

func _on_eliminated(victim: Character, striker: Character) -> void:
	if victim is AIController:
		cpu_outs += 1
		if striker is AIController:
			cpu_vs_cpu_outs += 1
