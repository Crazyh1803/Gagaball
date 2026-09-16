class_name AIController
extends Character
## State machine for CPU pit fighters, per the PRD difficulty matrix:
##   EASY   — wanders randomly; only slaps when the ball rolls into reach;
##            never dodges.
##   MEDIUM — tracks the ball, sidesteps incoming shots, slaps at opponents.
##   HARD   — leads the ball's path, sometimes dodge-dashes, and charges.
## Every difficulty is a free-for-all: CPUs target any surviving opponent.
##
## All physics, strike, and dash behavior is inherited from Character — this
## script only makes decisions: get_move_input() steers, handle_actions()
## pulls the trigger. Campaign bosses (later) extend this with wall-bounce
## prediction and signature shots.

enum Difficulty { EASY, MEDIUM, HARD }
enum State { WANDER, CHASE, DODGE }

@export var difficulty := Difficulty.EASY
## Past this fraction of the pit radius, steering pulls back toward center.
@export var safe_radius_fraction := 0.8

var _state := State.WANDER
var _move_dir := Vector2.ZERO
var _think_timer := 0.0
var _wander_timer := 0.0
var _charge_target := 0.0
var _ball: GagaBall
var _pit_radius := 300.0
var _reach_time := 0.0
var _save_decision := -1

func _ready() -> void:
	super()
	# Read the pit size without naming the Arena type: Arena loads this scene,
	# so a type reference back to it would be a cyclic dependency.
	var arena := get_parent()
	if arena != null:
		var radius = arena.get("pit_radius")  # null when the parent isn't an Arena
		if radius != null:
			_pit_radius = radius

func get_move_input() -> Vector2:
	return _move_dir

func handle_actions(delta: float) -> void:
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = _think_interval()
		_think()
	if _ball == null:
		return
	_act_on_ball(delta)

## Decision cadence doubles as reaction time: easier AI literally thinks
## slower, so fast shots get past it.
func _think_interval() -> float:
	match difficulty:
		Difficulty.HARD:
			return 0.1
		Difficulty.MEDIUM:
			return 0.2
		_:
			return 0.35

func _think() -> void:
	# Retarget every think so double-ball stages keep the AI honest.
	_ball = _nearest_ball()
	if _ball == null:
		_state = State.WANDER
	elif difficulty >= Difficulty.MEDIUM and _ball_threatens_me() \
			and randf() < [0.0, 0.45, 0.68][difficulty]:
		_state = State.DODGE
	elif difficulty >= Difficulty.MEDIUM and not _ball.is_repeat_touch(self):
		_state = State.CHASE
	else:
		_state = State.WANDER
	# Even easy CPUs retrieve a dying ball; wandering forever used to
	# leave entire matches stalled once the opening roll lost its speed.
	if _ball != null and _ball.linear_velocity.length() < 150.0 and not _ball.is_repeat_touch(self):
		_state = State.CHASE

	match _state:
		State.WANDER:
			_wander_timer -= _think_interval()
			if _wander_timer <= 0.0:
				_wander_timer = randf_range(0.8, 1.8)
				_move_dir = Vector2.from_angle(randf() * TAU) * randf_range(0.3, 0.8)
		State.CHASE:
			var target_point := _ball.position
			if difficulty == Difficulty.HARD:
				# Lead the moving ball. True wall-bounce reflection is a
				# campaign-boss upgrade.
				target_point += _ball.linear_velocity * 0.12
			_move_dir = (target_point - position).normalized()
		State.DODGE:
			var side := _ball.linear_velocity.normalized().orthogonal()
			# Sidestep toward whichever side is farther from the wall.
			if (position + side * 60.0).length() > (position - side * 60.0).length():
				side = -side
			_move_dir = side
			if difficulty == Difficulty.HARD and randf() < 0.18:
				start_dash()

	# Never hug the wall: past the safe radius, blend in a pull to center.
	if position.length() > _pit_radius * safe_radius_fraction:
		_move_dir = (_move_dir - position.normalized() * 1.2).normalized()

func _act_on_ball(delta: float) -> void:
	if is_charging():
		set_charge(charge_ratio + delta / charge_time)
		if charge_ratio >= _charge_target or not _ball_in_reach():
			_aim()
			release_strike()
		return
	if _ball_in_reach() and not _ball.is_repeat_touch(self):
		if _incoming_fast_ball():
			if _save_decision < 0:
				_save_decision = 1 if randf() < [0.08, 0.32, 0.58][difficulty] else 0
			if _save_decision == 0:
				# A missed read is committed until the ball leaves reach. This
				# prevents frame-by-frame rerolls from making every CPU perfect.
				return
		_reach_time += delta
		var reaction: float = [0.18, 0.11, 0.07][difficulty]
		if _reach_time < reaction:
			return
		_reach_time = 0.0
		if difficulty == Difficulty.HARD and _ball.linear_velocity.length() < 90.0 and randf() < 0.3:
			_charge_target = randf_range(0.5, 1.0)
			begin_charge()
		else:
			_aim()
			begin_charge()
			release_strike()
	else:
		_reach_time = 0.0
		_save_decision = -1

func _incoming_fast_ball() -> bool:
	if _ball.linear_velocity.length() < 180.0:
		return false
	var to_me := global_position - _ball.global_position
	return to_me.length_squared() > 1.0 \
			and _ball.linear_velocity.normalized().dot(to_me.normalized()) > 0.55

func _nearest_ball() -> GagaBall:
	var best: GagaBall = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group(&"balls"):
		var candidate := node as GagaBall
		var dist := position.distance_squared_to(candidate.position)
		if dist < best_dist:
			best_dist = dist
			best = candidate
	return best

func _ball_in_reach() -> bool:
	return can_reach_ball(_ball)

func _ball_threatens_me() -> bool:
	if _ball.is_repeat_touch(self):
		return false
	var to_me := position - _ball.position
	if to_me.length() > 230.0 or _ball.linear_velocity.length() < 140.0:
		return false
	return _ball.linear_velocity.normalized().dot(to_me.normalized()) > 0.7

func _aim() -> void:
	var target := _pick_target()
	var dir := -position.normalized() if position != Vector2.ZERO else Vector2.DOWN
	if target:
		dir = (target.position - position).normalized()
	# Aim from the ball, not the fighter's feet: the ball starts offset.
	facing = (target.global_position - _ball.global_position).normalized() if target else dir

func _pick_target() -> Character:
	var options: Array[Character] = []
	for node in get_tree().get_nodes_in_group(&"characters"):
		var other := node as Character
		if other == null or other == self or not other.is_alive:
			continue
		options.append(other)
	if options.is_empty():
		return null
	return options.pick_random()
