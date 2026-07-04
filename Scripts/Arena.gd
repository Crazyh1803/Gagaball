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

var _alive: Array[Character] = []
var _round_over := false

func _ready() -> void:
	var points := _octagon_points()
	_build_floor(points)
	_build_walls(points)
	for child in get_children():
		if child is Character:
			_alive.append(child)
			child.ball_contact_below_waist.connect(_on_below_waist_hit.bind(child))
			if child is PlayerCharacter:
				child.strike_blocked.connect(_on_player_strike_blocked)
	drop_ball()
	_flash_message("GAGA!", 1.2)

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

func _eliminate(character: Character) -> void:
	character.eliminate()
	_alive.erase(character)
	_flash_message("OUT!", 1.0)
	if character is PlayerCharacter:
		_end_round("GAME OVER")
	elif _alive.size() <= 1:
		_end_round("VICTORY!")

func _end_round(closing_message: String) -> void:
	if _round_over:
		return
	_round_over = true
	await get_tree().create_timer(1.0).timeout
	_flash_message(closing_message, round_restart_delay)
	await get_tree().create_timer(round_restart_delay).timeout
	get_tree().reload_current_scene()

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
