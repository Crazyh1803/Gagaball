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

@export var max_speed: float = 900.0

## The character that last struck or bumped the ball. null after a fresh drop.
## Persists across wall bounces so eliminations can be attributed.
var last_touched_by: Character = null
## The character whose *next* touch would break the double-touch rule.
## Cleared by a wall bounce, replaced when a different character touches the
## ball. Enforcement (elimination) is a later iteration; the game only tracks
## it here.
var repeat_toucher: Character = null

func is_repeat_touch(character: Character) -> bool:
	return repeat_toucher == character

func _ready() -> void:
	add_to_group(&"balls")
	body_entered.connect(_on_body_entered)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Clamp inside the physics step so power slaps and stacked bounces can
	# never launch the ball fast enough to feel unfair (or tunnel).
	if state.linear_velocity.length_squared() > max_speed * max_speed:
		state.linear_velocity = state.linear_velocity.limit_length(max_speed)

## Send the ball flying from a slap or power slap.
func strike(direction: Vector2, speed: float, striker: Character) -> void:
	last_touched_by = striker
	repeat_toucher = striker
	linear_velocity = direction.normalized() * minf(speed, max_speed)

func _on_body_entered(body: Node) -> void:
	if body is Character:
		last_touched_by = body
		repeat_toucher = body
		character_touched.emit(body)
	elif body is StaticBody2D:
		# Pit walls are the only static bodies in the ball's collision mask.
		repeat_toucher = null
		wall_bounced.emit()
