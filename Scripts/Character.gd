class_name Character
extends CharacterBody2D
## Base class for every pit fighter (player and CPU). Owns the 8-way movement
## physics once; subclasses only supply a movement direction by overriding
## get_move_input() — PlayerCharacter reads the input map, and the future
## AI_Controller returns steering decisions.
##
## Extension points left for later iterations:
##   - facing: 8-way aim direction the slap mechanic will strike along.
##   - ball_contact_below_waist: the elimination rule listens to this.
##   - get_move_input(): the AI override seam.

## Emitted when the ball touches this character's lower hurtbox.
## The elimination rules (a later iteration) decide what happens.
signal ball_contact_below_waist(ball: GagaBall)

@export var move_speed: float = 230.0
@export var acceleration: float = 1600.0
@export var deceleration: float = 2000.0
## Impulse applied when walking into the ball, so characters can nudge/dribble
## it around the pit before the slap mechanic exists.
@export var push_force: float = 48.0

## Last non-zero movement direction, snapped to 8 directions.
var facing := Vector2.DOWN

func _physics_process(delta: float) -> void:
	var input_dir := get_move_input()
	if input_dir.length_squared() > 1.0:
		input_dir = input_dir.normalized()

	var target_velocity := input_dir * move_speed
	var rate := acceleration if input_dir != Vector2.ZERO else deceleration
	velocity = velocity.move_toward(target_velocity, rate * delta)

	if input_dir != Vector2.ZERO:
		var new_facing := _snap_to_8_way(input_dir)
		if new_facing != facing:
			facing = new_facing
			queue_redraw()

	move_and_slide()
	_push_ball()

## Virtual. Return the desired movement direction (length <= 1).
## Base characters stand still.
func get_move_input() -> Vector2:
	return Vector2.ZERO

func _push_ball() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is GagaBall:
			collider.last_touched_by = self
			collider.apply_central_impulse(-collision.get_normal() * push_force)

func _snap_to_8_way(direction: Vector2) -> Vector2:
	return Vector2.from_angle(snappedf(direction.angle(), TAU / 8.0))

func _on_lower_hurtbox_body_entered(body: Node2D) -> void:
	if body is GagaBall:
		ball_contact_below_waist.emit(body)

func _draw() -> void:
	# Placeholder until pixel art lands: torso block, darker "below the waist"
	# zone matching the LowerHurtbox, and a facing tick for aiming the slap.
	draw_rect(Rect2(-11, -34, 22, 38), Color("4a7dc9"))
	draw_rect(Rect2(-11, -12, 22, 16), Color("31558c"))
	draw_line(Vector2.ZERO, facing * 20.0, Color.WHITE, 2.0)
