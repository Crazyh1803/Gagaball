class_name GagaBall
extends RigidBody2D
## The gaga ball. A dynamic body with bounce = 1.0 / friction = 0.0 on both the
## ball and the pit walls, so wall bounces are perfectly elastic no matter how
## Godot combines the two materials. linear_damp (set in Ball.tscn) is the only
## thing that slows it down, keeping "doesn't roll forever" decoupled from
## "bounces lose no energy".
##
## Tracks who touched it last so later iterations can enforce the double-touch
## rule and attribute eliminations / out-of-bounds strikes.

## Emitted when the ball rebounds off a pit wall. The double-touch rule (later)
## listens to this: a wall contact re-legalizes a strike by the last toucher.
signal wall_bounced
## Emitted when the ball comes into physical contact with a character.
signal character_touched(character: Character)

const RADIUS := 12.0

@export var max_speed: float = 900.0

## The character that last struck or bumped the ball. null after a fresh drop.
var last_touched_by: Character = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Clamp inside the physics step so power slaps and stacked bounces can
	# never launch the ball fast enough to feel unfair (or tunnel).
	if state.linear_velocity.length_squared() > max_speed * max_speed:
		state.linear_velocity = state.linear_velocity.limit_length(max_speed)

## Entry point for the future slap / power-slap mechanic.
func strike(direction: Vector2, speed: float, striker: Character) -> void:
	last_touched_by = striker
	linear_velocity = direction.normalized() * minf(speed, max_speed)

func _on_body_entered(body: Node) -> void:
	if body is Character:
		last_touched_by = body
		character_touched.emit(body)
	elif body is StaticBody2D:
		# Pit walls are the only static bodies in the ball's collision mask.
		wall_bounced.emit()

func _draw() -> void:
	# Placeholder until pixel art lands.
	draw_circle(Vector2.ZERO, RADIUS, Color("f2a33c"))
	draw_circle(Vector2(-RADIUS * 0.3, -RADIUS * 0.3), RADIUS * 0.35, Color("ffd9a0"))
