class_name GagaBall
extends RigidBody2D
## The gaga ball. A dynamic body with bounce = 1.0 / friction = 0.0 on both the
## ball and the pit walls, so wall bounces are perfectly elastic no matter how
## Godot combines the two materials. linear_damp (set in Ball.tscn) is the only
## thing that slows it down, keeping "doesn't roll forever" decoupled from
## "bounces lose no energy".
##
## Only legal slaps update ownership. Feet hits are refereed by Arena using
## swept paths, independently of physical wall contacts.

## A wall rebound re-legalizes a strike by the last toucher.
signal wall_bounced
## Emitted when the ball comes into physical contact with a character.
## Typed as Node, not Character: Character.gd refers to GagaBall, so naming
## Character here would make the two scripts a cyclic reference.
signal character_touched(character: Node)

@export var max_speed: float = 900.0

## The character that last struck the ball. null after a fresh drop.
## Persists across wall bounces so eliminations can be attributed.
var last_touched_by: Node = null
## The character whose *next* touch would break the double-touch rule.
## Cleared by a wall bounce, replaced when a different character touches the
## ball. Character refuses illegal repeat slaps; Arena uses this memory
## for own-shot immunity before a rebound.
var repeat_toucher: Node = null
var _trail: Array[Vector2] = []
signal control_changed(stolen: bool)
var controller: Node2D = null
var control_left := 0.0
var _control_lock := 0.0
var _dribble_clock := 0.0

func try_control(actor: Node2D) -> bool:
	if controller == actor: return true
	if _control_lock > 0 or (freeze and controller == null) or not actor.is_alive or actor.jump_height > 0 or actor.is_dashing(): return false
	if actor.global_position.distance_to(global_position) > float(actor.get("control_reach")): return false
	# A well-timed trap may catch a fast shot. The double-touch rule still
	# prevents recapturing your own loose ball before a wall/opponent touch.
	if controller == null and repeat_toucher == actor: return false
	var stolen := controller != null
	controller = actor
	control_left = 1.6
	_control_lock = 0.22
	last_touched_by = actor
	repeat_toucher = actor
	linear_velocity = Vector2.ZERO
	freeze = true
	control_changed.emit(stolen)
	return true

func release_control() -> void:
	if controller == null: return
	var actor := controller
	controller = null
	control_left = 0
	_control_lock = 0.3
	freeze = false
	$BallSprite.position.y = 0
	if is_instance_valid(actor): linear_velocity = actor.facing * 100

func _physics_process(delta: float) -> void:
	_control_lock = maxf(0, _control_lock - delta)
	if controller == null: return
	if not is_instance_valid(controller) or not controller.is_alive:
		release_control()
		return
	control_left -= delta
	if control_left <= 0 or controller.jump_height > 0 or controller.is_dashing():
		release_control()
		return
	var desired: Vector2 = controller.global_position + controller.facing * 32
	var query := PhysicsRayQueryParameters2D.create(controller.global_position, desired, CollisionLayers.WALLS)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		release_control()
		return
	global_position = desired
	linear_velocity = Vector2.ZERO
	_dribble_clock += delta
	$BallSprite.position.y = -absf(sin(_dribble_clock * 14)) * 10

func _process(_delta: float) -> void:
	_trail.push_front(global_position)
	if _trail.size() > 10:
		_trail.pop_back()
	queue_redraw()

func _draw() -> void:
	for i in range(1, _trail.size()):
		var alpha := (1.0 - float(i) / _trail.size()) * 0.3
		draw_circle(to_local(_trail[i]), 12.0 - i * 0.7, Color(1.0, 0.77, 0.3, alpha))
	draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 32,
			Color("ffb45e") if linear_velocity.length() >= 120.0 else Color("81e0c2"), 2.0)

func is_repeat_touch(character: Node) -> bool:
	return repeat_toucher == character and controller != character

func _ready() -> void:
	add_to_group(&"balls")
	process_physics_priority = 5
	physics_material_override = physics_material_override.duplicate()
	physics_material_override.bounce = 0.96
	body_entered.connect(_on_body_entered)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Clamp inside the physics step so power slaps and stacked bounces can
	# never launch the ball fast enough to feel unfair (or tunnel).
	if state.linear_velocity.length_squared() > max_speed * max_speed:
		state.linear_velocity = state.linear_velocity.limit_length(max_speed)

## Send the ball flying from a slap or power slap.
func strike(direction: Vector2, speed: float, striker: Node) -> void:
	release_control()
	last_touched_by = striker
	repeat_toucher = striker
	linear_velocity = direction.normalized() * minf(speed, max_speed)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group(&"characters"):
		# Contact is not a legal strike. Never grant immunity before the
		# referee sees the incoming hit.
		character_touched.emit(body)
	elif body is StaticBody2D:
		# Pit walls are the only static bodies in the ball's collision mask.
		repeat_toucher = null
		wall_bounced.emit()
