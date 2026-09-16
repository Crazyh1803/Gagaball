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
const BACKDROP := "res://Assets/Backgrounds/city_schoolyard-v2.png"
const FIGHTER_NAMES := ["ACE", "MACK", "RILEY", "KAI", "MORGAN", "TAY", "DREW", "CASEY", "JORDAN"]
## Jersey palettes handed out to CPUs in order, so opponents stay distinct
## from each other and from the player's gold.
const FIGHTER_SHEETS := [
	"res://Assets/Sprites/character_blue.png",
	"res://Assets/Sprites/character_red.png",
	"res://Assets/Sprites/character_green.png",
]

signal fighter_eliminated(victim: Character, striker: Character)

@export var pit_radius: float = 300.0
@export_range(3, 16) var pit_sides: int = 8
@export var wall_thickness: float = 24.0
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 10
	var points := _octagon_points()
	_build_ground(points)
	_build_walls(points)
	_setup_match()
	_build_hud()
	_register_ball(ball)
	_start_round()

func _start_round() -> void:
	ball.freeze = true
	for character in _alive:
		character.set_physics_process(false)
	for count in ["3", "2", "1"]:
		_flash_message(count, 0.75)
		_play_sfx(&"count", -7.0)
		await get_tree().create_timer(0.8, false).timeout
	drop_ball()
	ball.freeze = false
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
	ball.linear_damp = config["ball_damp"]
	drop_speed = config["drop_speed"]

	var cpus: Array = config["cpus"]
	_initial_count = cpus.size() + 1
	var spawn_radius := pit_radius * 0.65
	var player := $Player as Character
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	ball.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = Vector2.from_angle(PI / 2.0) * spawn_radius
	_register_character(player)
	var cpu_scene := load(CPU_SCENE) as PackedScene
	for i in cpus.size():
		var cpu := cpu_scene.instantiate() as AIController
		cpu.difficulty = cpus[i]
		cpu.display_name = FIGHTER_NAMES[i % FIGHTER_NAMES.size()]
		cpu.process_mode = Node.PROCESS_MODE_PAUSABLE
		cpu.position = Vector2.from_angle(
				PI / 2.0 + TAU * float(i + 1) / _initial_count) * spawn_radius
		add_child(cpu)
		cpu.set_fighter_sheet(load(FIGHTER_SHEETS[i % FIGHTER_SHEETS.size()]) as Texture2D)
		_register_character(cpu)

func _register_character(character: Character) -> void:
	_alive.append(character)
	character.struck_ball.connect(_on_struck_ball)
	var tag := Label.new()
	tag.name = "NameTag"
	tag.text = character.display_name
	tag.position = Vector2(-38, -88)
	tag.size = Vector2(76, 18)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_constant_override("outline_size", 3)
	tag.add_theme_color_override("font_color", Color("ffd777") if character is PlayerCharacter else Color.WHITE)
	character.add_child(tag)
	if character is PlayerCharacter:
		character.strike_blocked.connect(_on_player_strike_blocked)

func _register_ball(current: GagaBall) -> void:
	current.wall_bounced.connect(func() -> void: _play_sfx(&"bounce", -12.0, 0.045))

func _play_sfx(sound: StringName, volume_db := -4.0, min_gap := 0.0) -> void:
	get_node("/root/RetroSfx").play(sound, volume_db, min_gap)

func _process(delta: float) -> void:
	if _status:
		var player := $Player as Character
		_status.text = "%d / %d IN THE PIT   •   DASH %s" % [
				_alive.size(), _initial_count,
				"READY" if player.dash_ready_ratio() >= 1.0 else "RECHARGING"]
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
	ball.position = Vector2.ZERO
	ball.last_touched_by = null
	ball.repeat_toucher = null
	ball.linear_velocity = Vector2.from_angle(randf() * TAU) * drop_speed
	_previous_ball_positions[ball] = ball.global_position

func _physics_process(_delta: float) -> void:
	if not _round_started or _round_over or get_tree().paused:
		return
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
	if not _round_started or _round_over or not character.is_alive or character.is_dashing():
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
	_play_sfx(&"power" if power > 0.55 else &"slap", -3.0)
	if _struck.last_touched_by is PlayerCharacter:
		_flash_message("POWER SLAP!" if power > 0.55 else "SLAP!", 0.35)
	if power > 0.55:
		_add_shake(6.0 + 10.0 * power)

func _eliminate(character: Character, hit_ball: GagaBall = null) -> void:
	var striker := hit_ball.last_touched_by as Character if hit_ball != null else null
	character.eliminate()
	_alive.erase(character)
	var announcement := "%s IS OUT!" % character.display_name
	if striker != null and striker != character:
		announcement = "%s KNOCKED OUT %s!" % [striker.display_name, character.display_name]
	_flash_message(announcement, 0.95)
	_play_sfx(&"out", -3.0)
	fighter_eliminated.emit(character, striker)
	_add_shake(8.0)
	if character is PlayerCharacter:
		_end_round(false)
	elif _alive.size() <= 1:
		_end_round(true)
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
	second.position = Vector2.ZERO
	second.linear_velocity = Vector2.from_angle(randf() * TAU) * drop_speed
	_previous_ball_positions[second] = second.global_position
	_flash_message("DOUBLE BALL!", 1.2)

func _end_round(player_won: bool) -> void:
	if _round_over:
		return
	_round_over = true
	for current in get_tree().get_nodes_in_group(&"balls"):
		current.set_deferred("freeze", true)
	for character in _alive:
		character.set_physics_process(false)
		character.charge_ratio = -1.0
	GameState.report_match_result(player_won)
	if player_won:
		_play_sfx(&"victory", -3.0)
		for survivor in _alive:
			survivor.celebrate()
	_message_version += 1
	message_label.visible = false
	_overlay_title.text = "PIT CHAMPION" if player_won else "YOU'RE OUT"
	_overlay_note.text = "Last one standing. Well played!" if player_won else "Slap before it reaches your feet. Dash through incoming shots."
	if player_won and int(GameState.match_config["stage_index"]) >= 0:
		_overlay_note.text = "Tour progress saved. Choose your next pit from the menu."
	_resume_button.visible = false
	_overlay.show()

func _flash_message(text: String, duration: float) -> void:
	_message_version += 1
	var version := _message_version
	message_label.text = text
	message_label.visible = true
	var timer := get_tree().create_timer(duration, false)
	timer.timeout.connect(func() -> void:
		if version == _message_version:
			message_label.visible = false)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not _round_over:
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	if _round_over:
		return
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		$HUD/VirtualJoystick._release()
		for control_name in ["StrikeButton", "DashButton"]:
			var control := $HUD.get_node(control_name) as TouchActionButton
			if control._touch_index != -1:
				Input.action_release(control.action)
				control._touch_index = -1
				control.queue_redraw()
		($Player as Character).charge_ratio = -1.0
		($Player as PlayerCharacter).clear_strike_input()
	_overlay.visible = get_tree().paused
	_overlay_title.text = "TIME OUT"
	_overlay_note.text = "Take a breath. The pit will wait."
	_resume_button.visible = true

func _rematch() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)

func _build_hud() -> void:
	var hud := $HUD
	var ui_theme := GameTheme.create()
	var mobile := OS.has_feature("mobile")
	for control_name in ["VirtualJoystick", "StrikeButton", "DashButton"]:
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
	hud.add_child(_match_title)
	_status = Label.new()
	_status.position = Vector2(32, 52)
	_status.add_theme_color_override("font_color", Color("ffd777"))
	hud.add_child(_status)
	var help := Label.new()
	help.position = Vector2(32, 672)
	help.text = "WASD / ARROWS  move + aim    •    MOUSE  aim    •    SPACE / CLICK  slap (hold to charge)    •    SHIFT  evade"
	if mobile:
		help.text = "LEFT STICK  move + aim    •    SLAP  tap / hold to charge    •    DASH  evade incoming shots"
	help.add_theme_font_size_override("font_size", 16)
	hud.add_child(help)
	var pause_button := Button.new()
	pause_button.text = "PAUSE  /  ESC"
	pause_button.theme = ui_theme
	pause_button.position = Vector2(1100, 22)
	pause_button.size = Vector2(148, 40)
	pause_button.pressed.connect(_toggle_pause)
	hud.add_child(pause_button)
	_overlay = PanelContainer.new()
	_overlay.theme = ui_theme
	_overlay.position = Vector2(340, 210)
	_overlay.size = Vector2(600, 300)
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
	var retry := Button.new()
	retry.text = "REMATCH"
	retry.pressed.connect(_rematch)
	column.add_child(retry)
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
		points.append(Vector2.from_angle(angle) * pit_radius)
	return points

## Lays down the ground: the stage's surface inside the pit, a different one
## outside it, and a rim line where the wall meets the floor. Both textures
## tile (Polygon2D uses vertex positions as UVs when none are supplied).
func _build_ground(points: PackedVector2Array) -> void:
	var config: Dictionary = GameState.match_config
	var reach := pit_radius * 3.0

	var backdrop := Sprite2D.new()
	backdrop.name = "NeighborhoodBackdrop"
	backdrop.texture = load(BACKDROP) as Texture2D
	backdrop.scale = Vector2(1280.0 / backdrop.texture.get_width(), 720.0 / backdrop.texture.get_height())
	backdrop.z_index = -6
	add_child(backdrop)

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
	center_line.points = PackedVector2Array([Vector2(-270, 0), Vector2(270, 0)])
	center_line.width = 3.0
	center_line.default_color = paint
	center_line.z_index = -2
	add_child(center_line)
	var circle := Line2D.new()
	for i in 49:
		circle.add_point(Vector2.from_angle(TAU * i / 48.0) * 76.0)
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
	"blacktop": Color("3f4450"),
	"steel": Color("8d94a6"),
	"court": Color("8c5a30"),
}

func _build_walls(points: PackedVector2Array) -> void:
	var wall_material := PhysicsMaterial.new()
	wall_material.bounce = 1.0  # perfectly elastic pit walls
	wall_material.friction = 0.0
	var wall_color: Color = WALL_COLORS.get(GameState.match_config["floor"], Color("7a4f2c"))

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
		var outward := (a + b).normalized()
		wall.position = (a + b) / 2.0 + outward * (wall_thickness / 2.0)
		wall.rotation = (b - a).angle()

		var shape := RectangleShape2D.new()
		shape.size = Vector2(a.distance_to(b) + wall_overlap, wall_thickness)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		wall.add_child(collision)
		wall.z_index = -1  # under the players and ball, over the floor
		_add_wall_visual(wall, shape.size, wall_color)
		add_child(wall)

## Draws the wall board plus a lit cap on whichever side faces the pit, so
## the rim reads as a raised barrier rather than a flat stripe.
func _add_wall_visual(wall: StaticBody2D, size: Vector2, color: Color) -> void:
	var half := size / 2.0
	var board := Polygon2D.new()
	board.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	board.color = color
	wall.add_child(board)

	var inward := (Vector2.ZERO - wall.position).rotated(-wall.rotation)
	var cap_sign := signf(inward.y)
	var cap_outer := half.y * cap_sign
	var cap_inner := cap_outer - 5.0 * cap_sign
	var cap := Polygon2D.new()
	cap.polygon = PackedVector2Array([
		Vector2(-half.x, cap_inner), Vector2(half.x, cap_inner),
		Vector2(half.x, cap_outer), Vector2(-half.x, cap_outer),
	])
	cap.color = color.lightened(0.35)
	wall.add_child(cap)
