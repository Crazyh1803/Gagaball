class_name Arena
extends Node2D
## The core gameplay space: builds the octagonal pit at runtime, drops the
## ball, and referees the round — below-the-waist eliminations, the
## double-touch rule feedback, and last-one-standing victory. Multi-round
## matches, scoring, and campaign flow are later iterations (GameState).
##
## The pit walls are generated in _ready() rather than hand-placed in the
## scene, so the octagon math stays reviewable and the pit can be reshaped
## per campaign stage (radius, wall material) by tweaking exports.

const CPU_SCENE := preload("res://Scenes/CPU.tscn")
const BALL_SCENE := preload("res://Scenes/Ball.tscn")
const MENU_SCENE := "res://Scenes/MainMenu.tscn"

@export var pit_radius: float = 300.0
@export_range(3, 16) var pit_sides: int = 8
@export var wall_thickness: float = 24.0
## Extends each wall slightly past its corners so adjacent angled segments
## overlap and the ball can never slip through a joint.
@export var wall_overlap: float = 8.0
@export var drop_speed: float = 340.0
## A ball slower than this is harmless — no eliminations from a dying roll.
@export var elimination_min_speed: float = 120.0
@export var round_restart_delay: float = 3.0

@onready var ball: GagaBall = $Ball
@onready var message_label: Label = $HUD/Message
@onready var camera: Camera2D = $Camera2D

var _alive: Array[Character] = []
var _round_over := false
var _initial_count := 0
var _second_ball_spawned := false
var _shake_strength := 0.0

func _ready() -> void:
	var points := _octagon_points()
	_build_floor(points)
	_build_walls(points)
	_setup_match()
	drop_ball()
	var stage_name: String = GameState.match_config["stage_name"]
	_flash_message(stage_name if stage_name != "" else "GAGA!", 1.6)

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
	player.position = Vector2.from_angle(PI / 2.0) * spawn_radius
	_register_character(player)
	for i in cpus.size():
		var cpu := CPU_SCENE.instantiate() as AIController
		cpu.difficulty = cpus[i]
		cpu.position = Vector2.from_angle(
				PI / 2.0 + TAU * float(i + 1) / _initial_count) * spawn_radius
		add_child(cpu)
		_register_character(cpu)

func _register_character(character: Character) -> void:
	_alive.append(character)
	character.ball_contact_below_waist.connect(_on_below_waist_hit.bind(character))
	character.struck_ball.connect(_on_struck_ball)
	if character is PlayerCharacter:
		character.strike_blocked.connect(_on_player_strike_blocked)

func _process(delta: float) -> void:
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

# --- Refereeing ---

func _on_below_waist_hit(hit_ball: GagaBall, character: Character) -> void:
	if _round_over or not character.is_alive:
		return
	# Your own touch can't eliminate you until the ball hits a wall or
	# someone else (the same memory the double-touch rule uses).
	if hit_ball.is_repeat_touch(character):
		return
	if hit_ball.linear_velocity.length() < elimination_min_speed:
		return
	_eliminate(character)

func _on_player_strike_blocked(_blocked_ball: GagaBall) -> void:
	_flash_message("DOUBLE!", 0.8)

func _on_struck_ball(_struck: GagaBall, power: float) -> void:
	if power > 0.55:
		_add_shake(6.0 + 10.0 * power)

func _eliminate(character: Character) -> void:
	character.eliminate()
	_alive.erase(character)
	_flash_message("OUT!", 1.0)
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
	var second := BALL_SCENE.instantiate() as GagaBall
	second.linear_damp = ball.linear_damp
	add_child(second)
	second.position = Vector2.ZERO
	second.linear_velocity = Vector2.from_angle(randf() * TAU) * drop_speed
	_flash_message("DOUBLE BALL!", 1.2)

func _end_round(player_won: bool) -> void:
	if _round_over:
		return
	_round_over = true
	GameState.report_match_result(player_won)
	await get_tree().create_timer(1.0).timeout
	_flash_message("VICTORY!" if player_won else "GAME OVER", round_restart_delay)
	await get_tree().create_timer(round_restart_delay).timeout
	get_tree().change_scene_to_file(MENU_SCENE)

func _flash_message(text: String, duration: float) -> void:
	message_label.text = text
	message_label.visible = true
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		if message_label.text == text:
			message_label.visible = false)

func _octagon_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in pit_sides:
		# Half-a-side offset gives the "stop sign" orientation: flat walls
		# face up/down/left/right instead of corners poking at the camera.
		var angle := TAU * (i + 0.5) / pit_sides
		points.append(Vector2.from_angle(angle) * pit_radius)
	return points

func _build_floor(points: PackedVector2Array) -> void:
	var floor_poly := Polygon2D.new()
	floor_poly.name = "PitFloor"
	floor_poly.polygon = points
	floor_poly.color = Color("3a3a4a")
	floor_poly.z_index = -2
	add_child(floor_poly)

	var outline := Line2D.new()
	outline.name = "PitOutline"
	var outline_points := points.duplicate()
	outline_points.append(points[0])
	outline.points = outline_points
	outline.width = 10.0
	outline.default_color = Color("8a8ab0")
	outline.z_index = -1
	add_child(outline)

func _build_walls(points: PackedVector2Array) -> void:
	var wall_material := PhysicsMaterial.new()
	wall_material.bounce = 1.0  # perfectly elastic pit walls
	wall_material.friction = 0.0

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
		add_child(wall)
