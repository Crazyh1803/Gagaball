class_name Arena
extends Node2D
## The core gameplay space: builds the octagonal pit at runtime, drops the
## ball, and referees the round — below-the-waist eliminations, the
## double-touch feedback, dash evasion, countdown, pause and rematch.
##
## The pit walls are generated in _ready() rather than hand-placed in the
## scene, so the octagon math stays reviewable and the pit can be reshaped
## per campaign stage (radius, wall material) by tweaking exports.

## Loaded at runtime rather than preloaded: preload() resolves while this
## script is still parsing, which would make CPU.tscn -> AI_Controller.gd ->
## Arena a cyclic reference, and would also fail on a fresh clone where the
## textures have not been imported yet.
const CPU_SCENE := "res://Scenes/CPU.tscn"
const BALL_SCENE := "res://Scenes/Ball.tscn"
const MENU_SCENE := "res://Scenes/MainMenu.tscn"
const ART = preload("res://Scripts/FighterArt.gd")
const IMPACT = preload("res://Scripts/ComicImpact.gd")
const FIGHTER_NAMES := ["ACE", "MACK", "RILEY", "KAI", "MORGAN", "TAY", "DREW", "CASEY", "JORDAN"]

signal fighter_eliminated(victim: Character, striker: Character)

@export var pit_radius: float = 330.0
## Places the complete playable pit in the foreground courtyard instead of
## over the school façade and trees in the upper half of the backdrop.
@export var pit_center_offset := Vector2(0, 115)
## Foreshortens the pit into the same three-quarter view as stage backdrops.
@export_range(0.28, 1.0) var pit_vertical_scale: float = 0.36
## Widens the near half and narrows the far half so parallel ground-plane
## edges converge toward the backdrop's central vanishing region.
@export_range(0.0, 0.25) var pit_perspective_taper: float = 0.13
@export_range(3, 16) var pit_sides: int = 8
@export var wall_thickness: float = 24.0
## Screen-space rise of the far boards. The near wall is intentionally cut
## low so the player and ball remain readable inside the pit.
@export var wall_visual_height: float = 10.0
@export var front_wall_visual_height: float = 3.0
@export var wall_visual_thickness: float = 10.0
## Extends each wall slightly past its corners so adjacent angled segments
## overlap and the ball can never slip through a joint.
@export var wall_overlap: float = 8.0
@export var drop_speed: float = 340.0
## A ball slower than this is harmless — no eliminations from a dying roll.
@export var elimination_min_speed: float = 120.0
@onready var ball: GagaBall = $Ball
@onready var message_label: Label = $HUD/Message
@onready var camera: Camera2D = $Camera2D

var _alive: Array[Character] = []
var _round_over := false
var _initial_count := 0
var _second_ball_spawned := false
var _shake_strength := 0.0
var _round_started := false
var _message_version := 0
var _previous_ball_positions: Dictionary = {}
var _status: Label
var _match_title: Label
var _overlay: PanelContainer
var _overlay_title: Label
var _overlay_note: Label
var _resume_button: Button
var _retry_button: Button
var _tour_timer: Timer
var _next_stage := -1
var _countdown_timer: Timer
var _message_timer: Timer
var _countdown_left := 3
var touch_controls := OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or OS.get_cmdline_user_args().has("--touch")
var _help: Label
var _crowd: Node2D
var _home_rep: Sprite2D
var _toss_progress := -1.0
var _toss_start := Vector2.ZERO
var _opening_safe := 0.0
var _finish_order: Array = []
var _league_recorded := false
var _travel_summary := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 10
	pit_center_offset = GameState.match_config.get("pit_center", pit_center_offset)
	pit_vertical_scale = GameState.match_config.get("pit_scale", pit_vertical_scale)
	var points := _octagon_points()
	_build_ground(points)
	_build_walls(points)
	_setup_match()
	_build_supporters()
	_build_hud()
	_register_ball(ball)
	_start_round()
	Input.joy_connection_changed.connect(_controller_changed)
	get_node("/root/RetroSfx").play_music(GameState.city_id())

func _controller_changed(_device: int, connected: bool) -> void:
	if not connected and _round_started and not _round_over and not get_tree().paused:
		_toggle_pause()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		if not _round_over and not get_tree().paused:
			_toggle_pause()

func _start_round() -> void:
	ball.freeze = true
	_toss_start = $Player.position if GameState.player_is_home() else _home_rep.position
	ball.position = _toss_start
	ball.get_node("BallSprite").position.y = -55
	for character in _alive:
		character.set_physics_process(false)
	_countdown_timer = Timer.new()
	_countdown_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_countdown_timer.wait_time = 0.8
	_countdown_timer.timeout.connect(_countdown_tick)
	add_child(_countdown_timer)
	_countdown_timer.start()
	_countdown_tick()

func _countdown_tick() -> void:
	if _round_over:
		_countdown_timer.stop()
		return
	if _countdown_left > 0:
		_flash_message(str(_countdown_left), 0.75)
		_play_sfx(&"count", -7.0)
		_countdown_left -= 1
		if _countdown_left == 0:
			_toss_progress = 0.0
			_home_rep.frame = Character.COL_SLAP
			if GameState.player_is_home(): ($Player as Character).sprite.frame = Character.COL_SLAP
			_play_sfx(&"toss", -9.0)
		return
	_countdown_timer.stop()
	drop_ball()
	ball.freeze = false
	ball.get_node("BallSprite").position.y = 0
	_toss_progress = -1.0
	_home_rep.frame = 0
	_opening_safe = 0.75
	_round_started = true
	($Player as PlayerCharacter).clear_strike_input()
	for character in _alive:
		character.set_physics_process(true)
	_flash_message("GAGA!", 0.7)
	_play_sfx(&"go", -5.0)

## Configure the pit and the roster from GameState.match_config: apply the
## stage's ball physics and place the player plus one CPU per configured
## difficulty, evenly spaced around the pit.
func _setup_match() -> void:
	var config: Dictionary = GameState.match_config
	ball.linear_damp = float(config["ball_damp"]) * 0.40
	drop_speed = config["drop_speed"]

	var cpus: Array = config["cpus"]
	_initial_count = cpus.size() + 1
	# Start near the perimeter so the waist-high rear rail aligns naturally
	# with the back fighters and the center stays open for the first exchange.
	var spawn_radius := pit_radius * 0.80
	var player := $Player as Character
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	ball.process_mode = Node.PROCESS_MODE_PAUSABLE
	ball.position = pit_center_offset
	player.position = _arena_point(PI / 2.0, spawn_radius)
	var profile := GameState.current_player()
	player.display_name = profile.name
	player.set_fighter_sheet(ART.sheet(profile))
	_register_character(player)
	player.set_meta("club_id", "player")
	var league_roster: Array = []
	if config.get("league_match", false):
		for club in GameState.SEASON.table(GameState.career(), GameState.SEASON.player_league(GameState.career())):
			if club.id != "player": league_roster.append(club)
	var cpu_scene := load(CPU_SCENE) as PackedScene
	for i in cpus.size():
		var cpu := cpu_scene.instantiate() as AIController
		cpu.difficulty = cpus[i]
		cpu.move_speed = config.get("ai_speed", 230.0)
		var cpu_profile := ART.defaults(FIGHTER_NAMES[i % FIGHTER_NAMES.size()])
		cpu_profile.home_city = "" # generic friendly fighters are visitors
		cpu_profile.merge({"skin": (i + 2) % ART.SKINS.size(), "hair_style": i % 6,
			"hat": i % 4, "beard": (i / 3) % 4,
			"jersey": ART.COLORS[(i + 3) % ART.COLORS.size()]}, true)
		if i == 0:
			cpu_profile = GameState.city_representative()
		if not league_roster.is_empty():
			cpu_profile = league_roster[i].profile
			cpu.set_meta("club_id", league_roster[i].id)
		cpu.display_name = cpu_profile.name
		cpu.set_meta("fighter_profile", cpu_profile)
		cpu.process_mode = Node.PROCESS_MODE_PAUSABLE
		cpu.position = _arena_point(
				PI / 2.0 + TAU * float(i + 1) / _initial_count, spawn_radius)
		add_child(cpu)
		cpu.set_fighter_sheet(ART.sheet(cpu_profile))
		_register_character(cpu)
		if (i == 0 and league_roster.is_empty()) or cpu_profile.get("home_city", "") == GameState.city_id():
			cpu.get_node("NameTag").text += " • HOME"
	if GameState.player_is_home(): player.get_node("NameTag").text += " • HOME"

func _build_supporters() -> void:
	_crowd = preload("res://Scripts/PitCrowd.gd").new()
	_crowd.name = "Supporters"
	add_child(_crowd)
	var visitors: Array = []
	for fighter in _alive:
		if fighter is PlayerCharacter: continue
		var look: Dictionary = fighter.get_meta("fighter_profile")
		visitors.append([look.name, look.jersey, look.accent])
	_crowd.setup(pit_center_offset, GameState.current_player(), GameState.local_palettes(), GameState.player_is_home(), visitors)
	_home_rep = Sprite2D.new()
	_home_rep.name = "OpeningHost"
	_home_rep.texture = ART.sheet(GameState.city_representative())
	_home_rep.hframes = 8
	_home_rep.vframes = 3
	_home_rep.offset = Vector2(0, -46)
	_home_rep.scale = Vector2(0.8, 0.8)
	_home_rep.position = pit_center_offset + Vector2(-370, -25)
	_home_rep.visible = not GameState.player_is_home()
	add_child(_home_rep)

func _register_character(character: Character) -> void:
	_alive.append(character)
	character.struck_ball.connect(_on_struck_ball)
	character.jumped.connect(func() -> void: _play_sfx(&"jump", -12.0, 0.08))
	var tag := Label.new()
	tag.name = "NameTag"
	tag.text = character.display_name
	tag.position = Vector2(-100, -112)
	tag.size = Vector2(200, 20)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 10 if character.display_name.length() > 18 else 11)
	tag.add_theme_constant_override("outline_size", 3)
	tag.add_theme_color_override("font_color", Color("ffd777") if character is PlayerCharacter else Color.WHITE)
	character.add_child(tag)
	if character is PlayerCharacter:
		character.strike_blocked.connect(_on_player_strike_blocked)

func _register_ball(current: GagaBall) -> void:
	current.wall_bounced.connect(func() -> void: _play_sfx(&"bounce", -12.0, 0.045))
	current.control_changed.connect(func(stolen: bool) -> void:
		_play_sfx(&"steal" if stolen else &"dribble", -8.0, 0.09)
		_flash_message("STOLEN!" if stolen else "DRIBBLE!", 0.45))

func _play_sfx(sound: StringName, volume_db := -4.0, min_gap := 0.0) -> void:
	get_node("/root/RetroSfx").play(sound, volume_db, min_gap)

func _process(delta: float) -> void:
	if not get_tree().paused and _toss_progress >= 0:
		_toss_progress = minf(1.0, _toss_progress + delta / 0.8)
		ball.position = _toss_start.lerp(pit_center_offset, _toss_progress)
		ball.get_node("BallSprite").position.y = -55 * (1.0 - _toss_progress) - sin(_toss_progress * PI) * 100
	if _next_stage >= 0 and is_instance_valid(_tour_timer) and not _tour_timer.is_stopped():
		var leg := "Game %d" % (int(GameState.career().series.rounds) + 1) if GameState.match_config.get("league_match", false) else ""
		_overlay_note.text = "%s%sNext: %s%s\nTravelling in %d…%s" % [
			_travel_summary, "\n\n" if not _travel_summary.is_empty() else "",
			GameState.tour_stages()[_next_stage]["name"], " · " + leg if not leg.is_empty() else "",
			ceili(_tour_timer.time_left), "" if GameState.last_save_error == OK else "  (Progress could not be saved.)"]
	if _status:
		var player := $Player as Character
		_status.text = "%d / %d IN THE PIT   •   DASH %s   •   JUMP %s" % [
				_alive.size(), _initial_count,
				"READY" if player.dash_ready_ratio() >= 1.0 else "RECHARGING",
				"READY" if player.jump_ready_ratio() >= 1.0 else "RECHARGING"]
		var controlled := player.controlled_ball()
		if controlled != null: _status.text += "   •   DRIBBLE %.1fs" % controlled.control_left
	if _help and not touch_controls:
		_help.text = "WASD move · MOUSE aim · SPACE slap · J / E jump · SHIFT dash · Tap C to trap / steal" if Input.get_connected_joypads().is_empty() else "LEFT STICK move · RIGHT STICK aim · X / RB slap · A jump · B dash · Tap Y to trap / steal · START pause"
	# Screenshake: kicked up by power slaps and knockouts, decays fast.
	if _shake_strength > 0.05:
		_shake_strength = move_toward(_shake_strength, 0.0, 40.0 * delta)
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

func _add_shake(amount: float) -> void:
	_shake_strength = maxf(_shake_strength, amount)

## Center drop: ball resets to the middle of the pit with a random opening
## bounce, with no toucher attributed.
func drop_ball() -> void:
	ball.position = pit_center_offset
	ball.last_touched_by = null
	ball.repeat_toucher = null
	ball.linear_velocity = Vector2.from_angle(randf() * TAU) * drop_speed
	_previous_ball_positions[ball] = ball.global_position

func _physics_process(_delta: float) -> void:
	if not _round_started or _round_over or get_tree().paused:
		return
	_opening_safe = maxf(0.0, _opening_safe - _delta)
	# Sweep the ball between physics samples rather than relying on sensor
	# entry callbacks: fast shots cannot skip feet, and dash immunity is
	# reevaluated even if a ball remains overlapping when the dash expires.
	for node in get_tree().get_nodes_in_group(&"balls"):
		var current := node as GagaBall
		var previous: Vector2 = _previous_ball_positions.get(current, current.global_position)
		for character in _alive.duplicate():
			var closest := Geometry2D.get_closest_point_to_segment(
					character.global_position, previous, current.global_position)
			if closest.distance_to(character.global_position) <= 28.0:
				_on_below_waist_hit(current, character)
			if _round_over:
				break
		_previous_ball_positions[current] = current.global_position

# --- Refereeing ---

func _on_below_waist_hit(hit_ball: GagaBall, character: Character) -> void:
	if _opening_safe > 0.0 or hit_ball.controller != null:
		return
	if not _round_started or _round_over or not character.is_alive or character.is_dashing() or character.clears_ball():
		return
	# Your own touch can't eliminate you until the ball hits a wall or
	# someone else (the same memory the double-touch rule uses).
	if hit_ball.is_repeat_touch(character):
		return
	if hit_ball.linear_velocity.length() < elimination_min_speed:
		return
	_eliminate(character, hit_ball)

func _on_player_strike_blocked(_blocked_ball: GagaBall) -> void:
	_flash_message("DOUBLE!", 0.8)
	_play_sfx(&"double", -6.0)

func _on_struck_ball(_struck: GagaBall, power: float) -> void:
	# The audio layer rate-limits cheers, so every clean connection can ask for
	# a reaction without turning a rapid rally into overlapping noise.
	_crowd.cheer(0.5, true)
	var direction := _struck.linear_velocity.normalized()
	_spawn_impact(_struck.global_position, "slap", direction, power)
	_play_sfx(&"power" if power > 0.55 else &"slap", -3.0)
	if _struck.last_touched_by is PlayerCharacter:
		_flash_message("POWER SLAP!" if power > 0.55 else "SLAP!", 0.35)
	if power > 0.55:
		_add_shake(6.0 + 10.0 * power)
	else:
		_add_shake(3.0)

func _spawn_impact(at: Vector2, kind: String, direction: Vector2, power := 0.0) -> void:
	var impact := IMPACT.new()
	impact.kind = kind
	impact.direction = direction
	impact.power = power
	add_child(impact)
	impact.global_position = at

func _eliminate(character: Character, hit_ball: GagaBall = null) -> void:
	var striker := hit_ball.last_touched_by as Character if hit_ball != null else null
	var impact_direction := hit_ball.linear_velocity.normalized() if hit_ball != null else Vector2.RIGHT
	_spawn_impact(character.global_position + Vector2(0,-20), "out", impact_direction)
	character.eliminate(impact_direction)
	_alive.erase(character)
	_finish_order.push_front(character.get_meta("club_id", character.display_name))
	if character is PlayerCharacter:
		_crowd.boo(1.25)
	else:
		_crowd.cheer(1.2, true)
	var announcement := "%s IS OUT!" % character.display_name
	if striker != null and striker != character:
		announcement = "%s KNOCKED OUT %s!" % [striker.display_name, character.display_name]
	_flash_message(announcement, 0.95)
	_play_sfx(&"out", -3.0)
	fighter_eliminated.emit(character, striker)
	_add_shake(8.0)
	if character is PlayerCharacter and not GameState.match_config.get("league_match", false):
		_end_round(false)
	elif _alive.size() <= 1:
		_end_round(not _alive.is_empty() and _alive[0] is PlayerCharacter)
	elif character is PlayerCharacter:
		_flash_message("YOU'RE OUT · WATCHING THE FINISH", 2.0)
		_release_touch_controls()
	elif not _second_ball_spawned \
			and GameState.match_config.get("double_ball", false) \
			and _alive.size() * 2 <= _initial_count:
		# Stage gimmick: a second ball drops halfway through the match.
		# Deferred — we're inside a physics signal callback here.
		_second_ball_spawned = true
		call_deferred("_spawn_second_ball")

func _spawn_second_ball() -> void:
	if _round_over:
		return
	var second := (load(BALL_SCENE) as PackedScene).instantiate() as GagaBall
	second.linear_damp = ball.linear_damp
	second.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(second)
	_register_ball(second)
	second.position = pit_center_offset
	second.linear_velocity = Vector2.from_angle(randf() * TAU) * drop_speed
	_previous_ball_positions[second] = second.global_position
	_flash_message("DOUBLE BALL!", 1.2)

func _end_round(player_won: bool) -> void:
	if _round_over:
		return
	_round_over = true
	if GameState.match_config.get("league_match", false) and not _league_recorded:
		if _alive.size() == 1:
			_finish_order.push_front(_alive[0].get_meta("club_id", "player"))
		_league_recorded = GameState.record_league_round(_finish_order)
	for current in get_tree().get_nodes_in_group(&"balls"):
		current.release_control()
		current.set_deferred("freeze", true)
	for character in _alive:
		character.set_physics_process(false)
		character.charge_ratio = -1.0
		character.settle_jump()
	GameState.report_match_result(player_won)
	if player_won:
		_play_sfx(&"victory", -3.0)
		for survivor in _alive:
			survivor.celebrate()
	_message_version += 1
	message_label.visible = false
	_overlay_title.text = "PIT CHAMPION" if player_won else "YOU'RE OUT"
	_overlay_note.text = "Last one standing. Well played!" if player_won else "Slap before it reaches your feet. Jump over the ball or dash through it."
	if GameState.match_config.get("league_match", false):
		var same_city := int(GameState.career().round) == int(GameState.match_config.stage_index)
		if GameState.career().complete:
			_overlay_title.text = "SEASON COMPLETE"
			_overlay_note.text = "FINAL SEASON TABLE\n" + GameState.standings_text(true) + "\n\n" + GameState.career().movement
			_retry_button.text = "START NEXT SEASON"
		elif same_city:
			_overlay_title.text = "GAME %d COMPLETE" % (int(GameState.match_config.series_game) + 1)
			_travel_summary = "CITY SERIES\n" + GameState.series_text() + "\n\nSEASON TABLE\n" + GameState.standings_text()
			_overlay_note.text = _travel_summary
			_next_stage = int(GameState.career().round)
			_retry_button.text = "CONTINUE TO GAME %d" % (int(GameState.career().series.rounds) + 1)
		else:
			_overlay_title.text = "CITY SERIES COMPLETE"
			_travel_summary = "CITY PODIUM · 3 / 2 / 1 POINTS\n" + GameState.series_text() + "\n\nSEASON TABLE\n" + GameState.standings_text()
			_overlay_note.text = _travel_summary
			_next_stage = int(GameState.career().round)
			_retry_button.text = "CONTINUE TO NEXT CITY"
		if GameState.last_save_error != OK:
			_overlay_note.text += "\nSave failed; progress is in memory only."
	elif player_won and int(GameState.match_config["stage_index"]) >= 0:
		var next := int(GameState.match_config["stage_index"]) + 1
		if next < GameState.tour_stages().size() and not (GameState.match_config.get("league_match", false) and GameState.career().complete):
			_next_stage = next
			_retry_button.text = "NEXT CITY NOW"
			_tour_timer = Timer.new()
			_tour_timer.one_shot = true
			_tour_timer.wait_time = 4.0
			_tour_timer.timeout.connect(_advance_tour)
			add_child(_tour_timer)
			_tour_timer.start()
		elif not GameState.match_config.get("league_match", false):
			_overlay_title.text = "TOUR CHAMPION"
			_overlay_note.text = "All ten cities conquered! Your hometown legend starts here."
	_resume_button.visible = false
	if player_won:
		_crowd.cheer(3.0, true)
	else:
		_crowd.boo(2.5)
	_overlay.show()
	# Leave the pratfall visible before fading in the results card.
	_overlay.modulate.a = 0.0
	var reveal := create_tween()
	reveal.tween_interval(0.65)
	reveal.tween_property(_overlay,"modulate:a",1.0,0.15)
	reveal.tween_callback(_retry_button.grab_focus)
	_release_touch_controls()

func _start_travel_timer() -> void:
	if is_instance_valid(_tour_timer): _tour_timer.queue_free()
	_tour_timer = Timer.new()
	_tour_timer.one_shot = true
	_tour_timer.wait_time = 4.0
	_tour_timer.timeout.connect(_advance_tour)
	add_child(_tour_timer)
	_tour_timer.start()

func _flash_message(text: String, duration: float) -> void:
	_message_version += 1
	message_label.text = text
	message_label.visible = true
	if not is_instance_valid(_message_timer):
		_message_timer = Timer.new()
		_message_timer.one_shot = true
		_message_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
		_message_timer.timeout.connect(message_label.hide)
		add_child(_message_timer)
	_message_timer.start(duration)

func _input(event: InputEvent) -> void:
	if get_tree().paused and event.is_action_pressed(&"ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if _round_over and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_return_to_menu()
		return
	if event.is_action_pressed(&"pause") and not _round_over:
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	if _round_over:
		return
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		_release_touch_controls()
		($Player as Character).charge_ratio = -1.0
		($Player as PlayerCharacter).clear_strike_input()
	_overlay.visible = get_tree().paused
	_overlay_title.text = "TIME OUT"
	_overlay_note.text = "Take a breath. The pit will wait."
	_resume_button.visible = true
	_overlay.modulate.a = 1.0
	if get_tree().paused:
		_resume_button.grab_focus()

func _release_touch_controls() -> void:
	$HUD/VirtualJoystick._release()
	for control_name in ["StrikeButton", "DashButton", "JumpButton", "ControlButton"]:
		($HUD.get_node(control_name) as TouchActionButton).release_touch()
	($Player as PlayerCharacter).clear_strike_input()

func _rematch() -> void:
	_cancel_tour()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _return_to_menu() -> void:
	_cancel_tour()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)

func _cancel_tour() -> void:
	_next_stage = -1
	if is_instance_valid(_tour_timer):
		_tour_timer.stop()

func _advance_tour() -> void:
	if _next_stage < 0:
		return
	if GameState.match_config.get("league_match", false):
		GameState.start_league_round()
	else:
		GameState.start_campaign_stage(_next_stage)
	_cancel_tour()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/GameArena.tscn")

func _result_action() -> void:
	if _next_stage >= 0:
		_advance_tour()
	elif GameState.match_config.get("league_match", false) and GameState.career().complete:
		GameState.start_league_round()
		_rematch()
	else:
		_rematch()

func _build_hud() -> void:
	var hud := $HUD
	var ui_theme := GameTheme.create()
	var mobile := touch_controls
	for control_name in ["VirtualJoystick", "StrikeButton", "DashButton", "JumpButton", "ControlButton"]:
		var control := hud.get_node(control_name) as Control
		control.visible = mobile
		control.process_mode = Node.PROCESS_MODE_PAUSABLE
		control.set_process_input(mobile)
	message_label.add_theme_font_size_override("font_size", 48)
	message_label.add_theme_constant_override("outline_size", 5)
	message_label.anchor_top = 0.4
	message_label.anchor_bottom = 0.4
	_match_title = Label.new()
	_match_title.position = Vector2(32, 20)
	_match_title.text = GameState.match_config["stage_name"]
	if _match_title.text == "":
		_match_title.text = "GAGA PIT  /  FREE-FOR-ALL"
	_match_title.add_theme_font_size_override("font_size", 22)
	if _match_title.text.length() > 75: _match_title.add_theme_font_size_override("font_size", 18)
	hud.add_child(_match_title)
	_status = Label.new()
	_status.position = Vector2(32, 52)
	_status.add_theme_color_override("font_color", Color("ffd777"))
	hud.add_child(_status)
	var help := Label.new()
	_help = help
	help.position = Vector2(32, 672)
	help.text = "WASD / ARROWS move   •   MOUSE aim   •   SPACE / CLICK slap   •   J / E jump   •   SHIFT dash"
	if mobile:
		help.text = "STICK move + aim · SLAP tap / hold · JUMP · DASH · Tap TRAP near the ball to dribble / steal"
	help.add_theme_font_size_override("font_size", 16)
	hud.add_child(help)
	var pause_button := Button.new()
	pause_button.text = "PAUSE  /  ESC"
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.theme = ui_theme
	pause_button.position = Vector2(1100, 22)
	pause_button.size = Vector2(148, 40)
	pause_button.pressed.connect(_toggle_pause)
	hud.add_child(pause_button)
	_overlay = PanelContainer.new()
	_overlay.theme = ui_theme
	_overlay.position = Vector2(300, 72)
	_overlay.size = Vector2(680, 570)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("121e2e")
	style.border_color = Color("ffd777")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	_overlay.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	_overlay.add_child(column)
	_overlay_title = Label.new()
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.add_theme_font_size_override("font_size", 38)
	_overlay_title.add_theme_color_override("font_color", Color("ffd777"))
	column.add_child(_overlay_title)
	_overlay_note = Label.new()
	_overlay_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_overlay_note)
	_resume_button = Button.new()
	_resume_button.text = "BACK TO THE PIT"
	_resume_button.pressed.connect(_toggle_pause)
	column.add_child(_resume_button)
	_retry_button = Button.new()
	_retry_button.text = "REMATCH"
	_retry_button.pressed.connect(_result_action)
	column.add_child(_retry_button)
	var menu := Button.new()
	menu.text = "MAIN MENU"
	menu.pressed.connect(_return_to_menu)
	column.add_child(menu)
	hud.add_child(_overlay)
	_overlay.hide()

func _octagon_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in pit_sides:
		# Half-a-side offset gives the "stop sign" orientation: flat walls
		# face up/down/left/right instead of corners poking at the camera.
		var angle := TAU * (i + 0.5) / pit_sides
		points.append(_arena_point(angle, pit_radius))
	return points

func _arena_point(angle: float, radius: float) -> Vector2:
	var world_y := sin(angle) * radius
	var depth := world_y / pit_radius
	var width_scale := 1.0 + depth * pit_perspective_taper
	return pit_center_offset + Vector2(cos(angle) * radius * width_scale,
			world_y * pit_vertical_scale)

## Lays down the ground: the stage's surface inside the pit, a different one
## outside it, and a rim line where the wall meets the floor. Both textures
## tile (Polygon2D uses vertex positions as UVs when none are supplied).
func _build_ground(points: PackedVector2Array) -> void:
	var config: Dictionary = GameState.match_config
	var reach := pit_radius * 3.0

	var backdrop := Sprite2D.new()
	backdrop.name = "NeighborhoodBackdrop"
	var backdrop_name: String = config.get("backdrop", "backdrop_wiesbaden")
	backdrop.texture = load("res://Assets/Backgrounds/Stages/%s.png" % backdrop_name) as Texture2D
	backdrop.scale = Vector2(1280.0 / backdrop.texture.get_width(), 720.0 / backdrop.texture.get_height())
	backdrop.z_index = -6
	add_child(backdrop)
	var ambience := preload("res://Scripts/StageAmbience.gd").new()
	ambience.name = "StageAmbience"
	ambience.z_index = -5
	ambience.setup(GameState.city_id(), "background")
	add_child(ambience)
	var foreground_ambience := preload("res://Scripts/StageAmbience.gd").new()
	foreground_ambience.name = "StageAmbienceFront"
	foreground_ambience.z_index = 3
	foreground_ambience.setup(GameState.city_id(), "foreground")
	add_child(foreground_ambience)

	var surround := Polygon2D.new()
	surround.name = "Surround"
	surround.polygon = PackedVector2Array([
		Vector2(-reach, -reach), Vector2(reach, -reach),
		Vector2(reach, reach), Vector2(-reach, reach),
	])
	surround.texture = _ground_texture("surround", config["surround"])
	surround.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	surround.texture_scale = Vector2(0.5, 0.5)  # 32px tiles drawn at 2x, like the sprites
	surround.modulate = Color(0.32, 0.36, 0.42, 0.28)
	surround.z_index = -5
	add_child(surround)

	var floor_poly := Polygon2D.new()
	floor_poly.name = "PitFloor"
	floor_poly.polygon = points
	floor_poly.texture = _ground_texture("floor", config["floor"])
	floor_poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_poly.texture_scale = Vector2(0.5, 0.5)
	var court_tint := Color.from_string(
			config.get("court_tint", "ffffff"), Color.WHITE)
	floor_poly.modulate = Color(court_tint, 0.24)
	floor_poly.z_index = -3
	add_child(floor_poly)
	_build_court_details(config["floor"])

	var outline := Line2D.new()
	outline.name = "PitOutline"
	var outline_points := points.duplicate()
	outline_points.append(points[0])
	outline.points = outline_points
	outline.width = 6.0
	outline.default_color = Color(0.06, 0.05, 0.09, 0.65)
	outline.z_index = -2
	add_child(outline)

func _build_court_details(surface: String) -> void:
	if surface not in ["wood", "court", "blacktop"]:
		return
	var paint := Color(0.95, 0.86, 0.62, 0.34) if surface != "blacktop" else Color(0.9, 0.9, 0.78, 0.3)
	var center_line := Line2D.new()
	center_line.points = PackedVector2Array([
		pit_center_offset + Vector2(-pit_radius * 0.9, 0),
		pit_center_offset + Vector2(pit_radius * 0.9, 0),
	])
	center_line.width = 3.0
	center_line.default_color = paint
	center_line.z_index = -2
	add_child(center_line)
	var circle := Line2D.new()
	for i in 49:
		circle.add_point(_arena_point(TAU * i / 48.0, 76.0))
	circle.width = 3.0
	circle.default_color = paint
	circle.z_index = -2
	add_child(circle)

func _ground_texture(kind: String, theme: String) -> Texture2D:
	var path := "res://Assets/Backgrounds/%s_%s.png" % [kind, theme]
	return load(path) as Texture2D

## Pit rim colors, keyed by the stage's floor surface.
const WALL_COLORS := {
	"wood": Color("7a4f2c"),
	"dirt": Color("6b543a"),
	"sand": Color("a98c56"),
	"blacktop": Color("765033"),
	"steel": Color("8d94a6"),
	"court": Color("805936"),
}

func _build_walls(points: PackedVector2Array) -> void:
	var wall_material := PhysicsMaterial.new()
	wall_material.bounce = 0.0  # ball owns restitution; do not sum two bounces to 1
	wall_material.friction = 0.0
	var fallback_color: Color = WALL_COLORS.get(
			GameState.match_config["floor"], Color("7a4f2c"))
	var wall_color := Color.from_string(
			GameState.match_config.get("wall_color", ""), fallback_color)

	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]

		var wall := StaticBody2D.new()
		wall.name = "Wall%d" % i
		wall.collision_layer = CollisionLayers.WALLS
		wall.collision_mask = 0
		wall.physics_material_override = wall_material
		# Center the rectangle on the edge, pushed half a thickness outward
		# so the playable area keeps the full pit_radius.
		var outward := (b - a).orthogonal().normalized()
		if outward.dot((a + b) / 2.0 - pit_center_offset) < 0.0:
			outward = -outward
		wall.position = (a + b) / 2.0 + outward * (wall_thickness / 2.0)
		wall.rotation = (b - a).angle()

		var shape := RectangleShape2D.new()
		shape.size = Vector2(a.distance_to(b) + wall_overlap, wall_thickness)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		wall.add_child(collision)
		# The near rim passes in front of feet; the far rim stays behind the
		# fighters. This depth cue sells the three-quarter camera.
		var relative_y := wall.position.y - pit_center_offset.y
		wall.z_index = 2 if relative_y > pit_radius * pit_vertical_scale * 0.45 else -1
		_add_wall_visual(wall, shape.size, wall_color)
		add_child(wall)

## Draws a low wall rising vertically from its ground-plane footprint. The
## screen-facing edge is the inside edge on the far wall and the outside edge
## on the near wall. The near rise is reduced to create a gameplay cutaway.
func _add_wall_visual(wall: StaticBody2D, size: Vector2, color: Color) -> void:
	var half := size / 2.0
	var visual_half_thickness := minf(half.y, wall_visual_thickness / 2.0)
	var relative_y := wall.position.y - pit_center_offset.y
	var depth_ratio := clampf(
			(relative_y / (pit_radius * pit_vertical_scale) + 1.0) * 0.5,
			0.0, 1.0)
	var visible_height := lerpf(wall_visual_height, front_wall_visual_height,
			depth_ratio)
	var screen_rise := Vector2(0, -visible_height).rotated(-wall.rotation)
	var screen_down_local := Vector2.DOWN.rotated(-wall.rotation)
	var face_sign := signf(screen_down_local.y)
	if is_zero_approx(face_sign):
		face_sign = 1.0
	var face_y := visual_half_thickness * face_sign
	var face_start := Vector2(-half.x, face_y)
	var face_end := Vector2(half.x, face_y)

	# The wall rises up-screen from its pavement footprint. The near exterior
	# is darker than the far interior for an extra depth cue.
	var face := Polygon2D.new()
	face.name = "BoardFace"
	face.polygon = PackedVector2Array([
		face_start, face_end, face_end + screen_rise, face_start + screen_rise,
	])
	face.color = color.darkened(0.28 if relative_y > 0.0 else 0.13)
	face.set_meta("visual_height", visible_height)
	wall.add_child(face)

	# A short shadow at the footprint seats the pit on the stage ground.
	var shadow := Line2D.new()
	var shadow_offset := Vector2(0, 3.0).rotated(-wall.rotation)
	shadow.points = PackedVector2Array([
		face_start + shadow_offset, face_end + shadow_offset,
	])
	shadow.width = 6.0
	shadow.default_color = Color(0.03, 0.025, 0.035, 0.38)
	wall.add_child(shadow)

	# Vertical seams make the extrusion read as constructed boards rather than
	# one flat vector shape. They stay vertical on screen even on angled walls.
	var seam_count := maxi(1, floori(size.x / 64.0))
	for seam_index in range(1, seam_count + 1):
		var seam_x := lerpf(-half.x, half.x, float(seam_index) / float(seam_count + 1))
		var seam := Line2D.new()
		seam.points = PackedVector2Array([
			Vector2(seam_x, face_y), Vector2(seam_x, face_y) + screen_rise,
		])
		seam.width = 2.0
		seam.default_color = Color(0.08, 0.055, 0.04, 0.34)
		wall.add_child(seam)

	var board := Polygon2D.new()
	board.name = "BoardTop"
	board.polygon = PackedVector2Array([
		Vector2(-half.x, -visual_half_thickness) + screen_rise,
		Vector2(half.x, -visual_half_thickness) + screen_rise,
		Vector2(half.x, visual_half_thickness) + screen_rise,
		Vector2(-half.x, visual_half_thickness) + screen_rise,
	])
	board.color = color.lightened(0.10)
	wall.add_child(board)

	var inward := (pit_center_offset - wall.position).rotated(-wall.rotation)
	var cap_sign := signf(inward.y)
	var cap_outer := visual_half_thickness * cap_sign
	var cap_inner := cap_outer - 3.0 * cap_sign
	var cap := Polygon2D.new()
	cap.polygon = PackedVector2Array([
		Vector2(-half.x, cap_inner) + screen_rise,
		Vector2(half.x, cap_inner) + screen_rise,
		Vector2(half.x, cap_outer) + screen_rise,
		Vector2(-half.x, cap_outer) + screen_rise,
	])
	cap.color = color.lightened(0.35)
	wall.add_child(cap)

	var lip := Line2D.new()
	lip.points = PackedVector2Array([
		face_start + screen_rise, face_end + screen_rise,
	])
	lip.width = 3.0
	lip.default_color = color.lightened(0.42)
	wall.add_child(lip)
