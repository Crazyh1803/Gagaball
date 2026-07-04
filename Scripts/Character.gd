class_name Character
extends CharacterBody2D
## Base class for every pit fighter (player and CPU). Owns movement, the
## strike (tap slap / charged power slap), and the dash once; subclasses only
## supply decisions:
##   - get_move_input(): movement direction (PlayerCharacter reads the input
##     map, the future AI_Controller returns steering).
##   - handle_actions(): when to begin_charge()/release_strike()/start_dash().
##
## Extension points for later iterations:
##   - facing: 8-way aim direction every strike travels along.
##   - ball_contact_below_waist / struck_ball / dashed signals: elimination
##     rules, screenshake, and SFX subscribe to these.
##   - is_dashing(): the "leap over low balls" rule reads this later.

## Emitted when the ball touches this character's lower hurtbox.
## The elimination rules (a later iteration) decide what happens.
signal ball_contact_below_waist(ball: GagaBall)
## Emitted after a successful slap. power is 0 (tap) .. 1 (full charge).
signal struck_ball(ball: GagaBall, power: float)
## Emitted when a slap is refused by the double-touch rule (the ball hasn't
## hit a wall or another player since this character last touched it).
signal strike_blocked(ball: GagaBall)
signal dashed(direction: Vector2)
signal knocked_out(character: Character)

@export_group("Movement")
@export var move_speed: float = 230.0
@export var acceleration: float = 1600.0
@export var deceleration: float = 2000.0
## Impulse applied when walking into the ball, so characters can nudge/dribble
## it around the pit.
@export var push_force: float = 48.0

@export_group("Strike")
@export var strike_speed: float = 520.0
@export var power_slap_speed: float = 900.0
## Seconds of holding for a full-power slap.
@export var charge_time: float = 0.8
## Movement speed multiplier while charging (planting your feet to wind up).
@export var charge_move_penalty: float = 0.45

@export_group("Dash")
@export var dash_speed: float = 560.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.7

@export_group("Looks")
## Placeholder body color until pixel art lands; the player wears a different
## jersey than the CPUs.
@export var jersey_color := Color("4a7dc9")

## Last non-zero movement direction, snapped to 8 directions.
var facing := Vector2.DOWN
## 0..1 while charging a slap, -1 when not charging.
var charge_ratio := -1.0
var is_alive := true

var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0
var _dash_direction := Vector2.ZERO

@onready var strike_zone: Area2D = $StrikeZone

func _ready() -> void:
	add_to_group(&"characters")

func _physics_process(delta: float) -> void:
	handle_actions(delta)
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)

	var input_dir := get_move_input()
	if input_dir.length_squared() > 1.0:
		input_dir = input_dir.normalized()

	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		velocity = _dash_direction * dash_speed
	else:
		var speed := move_speed * (charge_move_penalty if is_charging() else 1.0)
		var rate := acceleration if input_dir != Vector2.ZERO else deceleration
		velocity = velocity.move_toward(input_dir * speed, rate * delta)

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

## Virtual. Called every physics frame before movement; subclasses trigger
## begin_charge()/release_strike()/start_dash() here.
func handle_actions(_delta: float) -> void:
	pass

# --- Strike ---

func is_charging() -> bool:
	return charge_ratio >= 0.0

func begin_charge() -> void:
	charge_ratio = 0.0
	queue_redraw()

func set_charge(ratio: float) -> void:
	charge_ratio = clampf(ratio, 0.0, 1.0)
	queue_redraw()

## Release the button: slap the ball if it's in reach. A tap is a plain slap,
## a full hold is a power slap. Whiffs harmlessly when the ball is away, and
## the double-touch rule refuses the slap until the ball hits a wall or
## another player.
func release_strike() -> void:
	var power := maxf(charge_ratio, 0.0)
	charge_ratio = -1.0
	queue_redraw()
	for body in strike_zone.get_overlapping_bodies():
		if body is GagaBall:
			if body.is_repeat_touch(self):
				strike_blocked.emit(body)
				continue
			body.strike(facing, lerpf(strike_speed, power_slap_speed, power), self)
			struck_ball.emit(body, power)

# --- Dash ---

func start_dash() -> void:
	if _dash_cooldown_left > 0.0:
		return
	var dir := get_move_input()
	_dash_direction = dir.normalized() if dir != Vector2.ZERO else facing
	_dash_time_left = dash_duration
	_dash_cooldown_left = dash_cooldown
	dashed.emit(_dash_direction)

func is_dashing() -> bool:
	return _dash_time_left > 0.0

# --- Elimination ---

## Knock this character out of the round: freeze it, remove it from physics
## (deferred — this is reached from physics signal callbacks), flash the
## sprite, and leave a faded ghost so the pit shows who's out.
func eliminate() -> void:
	if not is_alive:
		return
	is_alive = false
	charge_ratio = -1.0
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	$LowerHurtbox.set_deferred("monitoring", false)
	var tween := create_tween()
	for i in 4:
		tween.tween_property(self, "modulate:a", 0.1, 0.07)
		tween.tween_property(self, "modulate:a", 1.0, 0.07)
	tween.tween_property(self, "modulate:a", 0.25, 0.15)
	knocked_out.emit(self)

# --- Internals ---

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
	draw_rect(Rect2(-11, -34, 22, 38), jersey_color)
	draw_rect(Rect2(-11, -12, 22, 16), jersey_color.darkened(0.4))
	draw_line(Vector2.ZERO, facing * 20.0, Color.WHITE, 2.0)
	if is_charging():
		# Wind-up ring fills clockwise from 12 o'clock as the slap charges.
		var color := Color("ffd94d").lerp(Color("ff5533"), charge_ratio)
		draw_arc(Vector2(0, -16), 20.0, -PI / 2.0, -PI / 2.0 + TAU * charge_ratio, 24, color, 3.0)
