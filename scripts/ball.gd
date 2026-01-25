extends RigidBody2D
class_name FootballBall
## The football entity for passing and kicking.

signal caught(player: PlayerFigure)
signal incomplete(reason: String)
signal intercepted(player: PlayerFigure)

enum BallState { HELD, IN_FLIGHT, CAUGHT, INCOMPLETE, KICKED }

var _state: BallState = BallState.HELD
var state: BallState:
	get:
		return _state
	set(value):
		_state = value
		_update_visual()

# Throwing info
var _thrower: PlayerFigure = null
var _throwing_team: PlayerFigure.Team = PlayerFigure.Team.HOME
var _flight_time: float = 0.0
const MAX_FLIGHT_TIME: float = 2.0

# Kick info
var _is_kick: bool = false
var _kick_height: float = 0.0  # Simulated height for trajectory

# Field boundaries
const FIELD_WIDTH: float = 520.0
const FIELD_HEIGHT: float = 1000.0
const END_ZONE_DEPTH: float = 80.0

@onready var _sprite: Polygon2D = $Sprite


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	_update_visual()


func _physics_process(delta: float) -> void:
	if _state == BallState.IN_FLIGHT or _state == BallState.KICKED:
		_flight_time += delta

		# Check for max flight time (incomplete)
		if _flight_time >= MAX_FLIGHT_TIME:
			_mark_incomplete("timeout")
			return

		# Check for out of bounds
		if _is_out_of_bounds():
			_mark_incomplete("out_of_bounds")
			return

		# Check if ball stopped moving (incomplete pass)
		if linear_velocity.length() < 10.0:
			_mark_incomplete("stopped")
			return

		# For kicks, simulate arc by adjusting scale (visual only)
		if _is_kick:
			_update_kick_arc(delta)


func _update_kick_arc(delta: float) -> void:
	# Simple parabolic arc simulation (visual only)
	var flight_progress := _flight_time / MAX_FLIGHT_TIME
	# Height peaks at 0.5 progress
	_kick_height = sin(flight_progress * PI) * 50.0
	# Visual scale to simulate height
	var scale_factor := 1.0 + (_kick_height / 100.0)
	scale = Vector2(scale_factor, scale_factor)


func _is_out_of_bounds() -> bool:
	return global_position.x < 0 or global_position.x > FIELD_WIDTH or \
		   global_position.y < 0 or global_position.y > FIELD_HEIGHT


func _on_body_entered(body: Node) -> void:
	if _state != BallState.IN_FLIGHT and _state != BallState.KICKED:
		return

	if body is PlayerFigure:
		var player := body as PlayerFigure

		if _is_kick:
			# Any player can catch a kick
			_complete_catch(player)
		elif player.team == _throwing_team:
			# Same team - potential catch
			if player != _thrower and player.is_eligible_receiver():
				_complete_catch(player)
		else:
			# Different team - interception
			_complete_interception(player)


func _complete_catch(player: PlayerFigure) -> void:
	state = BallState.CAUGHT
	freeze = true
	caught.emit(player)


func _complete_interception(player: PlayerFigure) -> void:
	state = BallState.CAUGHT
	freeze = true
	intercepted.emit(player)


func _mark_incomplete(reason: String) -> void:
	state = BallState.INCOMPLETE
	linear_velocity = Vector2.ZERO
	freeze = true
	incomplete.emit(reason)


func _update_visual() -> void:
	if not is_inside_tree():
		return

	match _state:
		BallState.HELD:
			visible = false
		BallState.IN_FLIGHT, BallState.KICKED:
			visible = true
			modulate = Color.WHITE
		BallState.CAUGHT:
			visible = true
			modulate = Color.GREEN
		BallState.INCOMPLETE:
			visible = true
			modulate = Color.RED


## Throw the ball from a player toward a target position.
func throw_ball(thrower: PlayerFigure, target: Vector2, power: float) -> void:
	_thrower = thrower
	_throwing_team = thrower.team
	_is_kick = false
	_flight_time = 0.0
	scale = Vector2.ONE

	# Position at thrower
	global_position = thrower.global_position

	# Calculate velocity toward target
	var direction := (target - global_position).normalized()
	var throw_power := clampf(power, 200.0, 600.0)

	freeze = false
	linear_velocity = direction * throw_power

	state = BallState.IN_FLIGHT


## Kick the ball from a position toward a target.
func kick_ball(from_position: Vector2, target: Vector2, power: float, team: PlayerFigure.Team) -> void:
	_thrower = null
	_throwing_team = team
	_is_kick = true
	_flight_time = 0.0
	_kick_height = 0.0
	scale = Vector2.ONE

	global_position = from_position

	var direction := (target - global_position).normalized()
	var kick_power := clampf(power, 300.0, 800.0)

	freeze = false
	linear_velocity = direction * kick_power

	state = BallState.KICKED


## Check if this kick is a field goal (crosses goal line within uprights).
func check_field_goal(goal_y: float, upright_left_x: float, upright_right_x: float) -> bool:
	if not _is_kick:
		return false

	# Check if ball crossed the goal line at sufficient height
	var crossed_goal := global_position.y <= goal_y
	var within_uprights := global_position.x >= upright_left_x and global_position.x <= upright_right_x
	var sufficient_height := _kick_height > 20.0  # Must be elevated

	return crossed_goal and within_uprights and sufficient_height


## Reset ball to held state.
func reset() -> void:
	_thrower = null
	_flight_time = 0.0
	_is_kick = false
	_kick_height = 0.0
	scale = Vector2.ONE
	freeze = true
	linear_velocity = Vector2.ZERO
	state = BallState.HELD
