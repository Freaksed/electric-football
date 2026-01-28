extends Node
class_name GameManager
## Manages game state, rules, and flow.

signal play_started
signal play_ended(reason: String)
signal score_changed(home: int, away: int)
signal down_changed(down: int, yards_to_go: int)
signal scrimmage_changed(los: int, first_down_line: int)
signal phase_changed(phase: GamePhase)
signal ball_thrown(thrower: PlayerFigure, target: Vector2)
signal pass_complete(receiver: PlayerFigure)
signal pass_incomplete(reason: String)
signal pass_intercepted(interceptor: PlayerFigure)
signal kick_started(from: Vector2, target: Vector2)
signal possession_changed(team: PlayerFigure.Team)
signal touchdown_scored(team: PlayerFigure.Team)
signal field_goal_scored(team: PlayerFigure.Team)
signal safety_scored(team: PlayerFigure.Team)
signal first_down_achieved()
signal turnover_on_downs()

enum GamePhase { SETUP, PRE_SNAP, PLAYING, PLAY_OVER, GAME_OVER }
enum PlayResult { NONE, TACKLE, PASS_COMPLETE, PASS_INCOMPLETE, INTERCEPTION, TOUCHDOWN, FIELD_GOAL, SAFETY }

var _current_phase: GamePhase = GamePhase.PRE_SNAP

var current_phase: GamePhase:
	get:
		return _current_phase
	set(value):
		if _current_phase != value:
			_current_phase = value
			phase_changed.emit(_current_phase)

# Score
var home_score: int = 0
var away_score: int = 0

# Possession tracking (HOME offense starts by default)
var _possession: PlayerFigure.Team = PlayerFigure.Team.HOME

var possession: PlayerFigure.Team:
	get:
		return _possession
	set(value):
		if _possession != value:
			_possession = value
			possession_changed.emit(_possession)

# Down and distance
var current_down: int = 1
var yards_to_go: int = 10
var _line_of_scrimmage: int = 20  # Yard line (0-100, 0 = away end zone, 100 = home end zone)
var _los_at_snap: int = 20  # LOS when play started (for yards gained calculation)

# Field reference for position conversion
var field: Node = null  # FootballField for y_to_yard() conversion

# Field constants (duplicated for when field ref not available)
const FIELD_HEIGHT: float = 1000.0
const END_ZONE_DEPTH: float = 80.0

## Line of scrimmage yard line (0 = away end zone, 100 = home end zone)
var line_of_scrimmage: int:
	get:
		return _line_of_scrimmage
	set(value):
		_line_of_scrimmage = clampi(value, 0, 100)
		scrimmage_changed.emit(_line_of_scrimmage, get_first_down_line())


## Get the yard line where first down is achieved
func get_first_down_line() -> int:
	# First down line depends on possession direction
	# HOME offense moves toward yard 0 (away end zone)
	# AWAY offense moves toward yard 100 (home end zone)
	if _possession == PlayerFigure.Team.HOME:
		return maxi(_line_of_scrimmage - yards_to_go, 0)
	else:
		return mini(_line_of_scrimmage + yards_to_go, 100)

# Ball carrier tracking
var _ball_carrier: PlayerFigure = null

# Ball entity reference (FootballBall type, using Node for load-order compatibility)
var ball: Node = null
var _throwing_qb: PlayerFigure = null
var _last_play_result: PlayResult = PlayResult.NONE

@onready var _vibration: Node = get_node("/root/VibrationController")


func _ready() -> void:
	if _vibration:
		_vibration.vibration_started.connect(_on_vibration_started)
		_vibration.vibration_stopped.connect(_on_vibration_stopped)


func _on_vibration_started() -> void:
	if current_phase == GamePhase.PRE_SNAP:
		current_phase = GamePhase.PLAYING
		play_started.emit()


func _on_vibration_stopped() -> void:
	if current_phase == GamePhase.PLAYING:
		current_phase = GamePhase.PLAY_OVER
		play_ended.emit("whistle")


func set_ball_carrier(player: PlayerFigure) -> void:
	if _ball_carrier:
		_ball_carrier.has_ball = false
		_ball_carrier.tackled.disconnect(_on_ball_carrier_tackled)

	_ball_carrier = player
	if _ball_carrier:
		_ball_carrier.has_ball = true
		_ball_carrier.tackled.connect(_on_ball_carrier_tackled)


func _on_ball_carrier_tackled(tackler: PlayerFigure) -> void:
	if _vibration:
		_vibration.stop_vibration()

	# Get ball carrier's final position as yard line
	var final_yard := _y_to_yard(_ball_carrier.global_position.y)

	# Check for touchdown first
	if _check_touchdown(final_yard):
		_last_play_result = PlayResult.TOUCHDOWN
		current_phase = GamePhase.PLAY_OVER
		play_ended.emit("touchdown")
		return

	# Check for safety (tackled in own end zone)
	if _check_safety(final_yard):
		_last_play_result = PlayResult.SAFETY
		current_phase = GamePhase.PLAY_OVER
		play_ended.emit("safety")
		return

	# Normal tackle - process yards gained and down progression
	_last_play_result = PlayResult.TACKLE
	_process_play_result(final_yard)
	current_phase = GamePhase.PLAY_OVER
	play_ended.emit("tackle")


## Called when player wants to snap the ball. Returns true if snap was successful.
func snap() -> bool:
	if current_phase != GamePhase.PRE_SNAP:
		return false

	# Record LOS at snap for yards gained calculation
	_los_at_snap = _line_of_scrimmage

	if _vibration:
		_vibration.start_vibration()
	# Phase transition happens in _on_vibration_started
	return true


## Called to blow the whistle and end the current play.
func whistle() -> void:
	if current_phase == GamePhase.PLAYING:
		if _vibration:
			_vibration.stop_vibration()
		# Phase transition happens in _on_vibration_stopped


## Prepare for the next play after a play ends.
func ready_for_next_play() -> void:
	if current_phase == GamePhase.PLAY_OVER or current_phase == GamePhase.SETUP:
		current_phase = GamePhase.PRE_SNAP


## Check if players can be edited (positioned, rotated).
func can_edit_players() -> bool:
	return current_phase in [GamePhase.SETUP, GamePhase.PRE_SNAP, GamePhase.PLAY_OVER]


func start_play() -> void:
	if current_phase == GamePhase.SETUP or current_phase == GamePhase.PLAY_OVER:
		current_phase = GamePhase.PRE_SNAP


func ready_for_snap() -> void:
	current_phase = GamePhase.PRE_SNAP


func reset_downs() -> void:
	current_down = 1
	yards_to_go = 10
	down_changed.emit(current_down, yards_to_go)
	scrimmage_changed.emit(_line_of_scrimmage, get_first_down_line())


func advance_down() -> void:
	current_down += 1
	if current_down > 4:
		# Turnover on downs
		current_down = 1
		yards_to_go = 10
	down_changed.emit(current_down, yards_to_go)
	scrimmage_changed.emit(_line_of_scrimmage, get_first_down_line())


func add_score(team: PlayerFigure.Team, points: int) -> void:
	if team == PlayerFigure.Team.HOME:
		home_score += points
	else:
		away_score += points
	score_changed.emit(home_score, away_score)


## Set up the ball entity reference and connect signals.
func set_ball(ball_entity: Node) -> void:
	ball = ball_entity
	if ball:
		ball.caught.connect(_on_ball_caught)
		ball.incomplete.connect(_on_ball_incomplete)
		ball.intercepted.connect(_on_ball_intercepted)
		ball.field_goal_made.connect(_on_field_goal_made)


## Called when QB throws the ball.
func throw_pass(qb: PlayerFigure, target: Vector2, power: float) -> void:
	if current_phase != GamePhase.PLAYING:
		return
	if not ball:
		return

	_throwing_qb = qb

	# Remove ball from current carrier
	if _ball_carrier:
		_ball_carrier.has_ball = false
		_ball_carrier = null

	ball.throw_ball(qb, target, power)
	ball_thrown.emit(qb, target)


## Called when a kick is initiated.
func kick(from_position: Vector2, target: Vector2, power: float, team: PlayerFigure.Team) -> void:
	if not ball:
		return

	# Remove ball from carrier
	if _ball_carrier:
		_ball_carrier.has_ball = false
		_ball_carrier = null

	ball.kick_ball(from_position, target, power, team)
	kick_started.emit(from_position, target)


func _on_ball_caught(player: PlayerFigure) -> void:
	_last_play_result = PlayResult.PASS_COMPLETE
	set_ball_carrier(player)
	pass_complete.emit(player)


func _on_ball_incomplete(reason: String) -> void:
	_last_play_result = PlayResult.PASS_INCOMPLETE
	if _vibration:
		_vibration.stop_vibration()
	current_phase = GamePhase.PLAY_OVER
	pass_incomplete.emit(reason)
	play_ended.emit("incomplete_pass")


func _on_ball_intercepted(player: PlayerFigure) -> void:
	_last_play_result = PlayResult.INTERCEPTION
	# Change possession immediately on interception
	change_possession()
	set_ball_carrier(player)
	pass_intercepted.emit(player)
	# Play continues with new ball carrier - when tackled, they get ball where they are


func _on_field_goal_made(team: PlayerFigure.Team) -> void:
	_last_play_result = PlayResult.FIELD_GOAL
	if _vibration:
		_vibration.stop_vibration()
	_score_field_goal(team)
	current_phase = GamePhase.PLAY_OVER
	play_ended.emit("field_goal")


## Get the last play result.
func get_last_play_result() -> PlayResult:
	return _last_play_result


## Reset play state for next play.
func reset_play_state() -> void:
	_throwing_qb = null
	_last_play_result = PlayResult.NONE
	if ball:
		ball.reset()


# ========== POSITION CONVERSION ==========

## Convert y position to yard line (0-100)
## Returns: 0 = away goal line, 100 = home goal line
func _y_to_yard(y: float) -> int:
	if field and field.has_method("y_to_yard"):
		return field.y_to_yard(y)
	# Fallback calculation if no field reference
	var playing_field_height := FIELD_HEIGHT - 2 * END_ZONE_DEPTH
	var yard := ((y - END_ZONE_DEPTH) / playing_field_height) * 100.0
	return clampi(int(yard), 0, 100)


## Convert yard line to y position
func _yard_to_y(yard_line: int) -> float:
	if field and field.has_method("yard_to_y"):
		return field.yard_to_y(yard_line)
	# Fallback calculation
	var playing_field_height := FIELD_HEIGHT - 2 * END_ZONE_DEPTH
	return END_ZONE_DEPTH + (yard_line / 100.0) * playing_field_height


# ========== SCORING DETECTION ==========

## Check if ball carrier reached the opponent's end zone (touchdown)
func _check_touchdown(final_yard: int) -> bool:
	var carrier_y := _ball_carrier.global_position.y if _ball_carrier else FIELD_HEIGHT / 2.0

	if _possession == PlayerFigure.Team.HOME:
		# HOME offense scores at away end zone (y < END_ZONE_DEPTH, yard <= 0)
		if carrier_y < END_ZONE_DEPTH:
			_score_touchdown(PlayerFigure.Team.HOME)
			return true
	else:
		# AWAY offense scores at home end zone (y > FIELD_HEIGHT - END_ZONE_DEPTH, yard >= 100)
		if carrier_y > FIELD_HEIGHT - END_ZONE_DEPTH:
			_score_touchdown(PlayerFigure.Team.AWAY)
			return true
	return false


## Check if ball carrier was tackled in their own end zone (safety)
func _check_safety(final_yard: int) -> bool:
	var carrier_y := _ball_carrier.global_position.y if _ball_carrier else FIELD_HEIGHT / 2.0

	if _possession == PlayerFigure.Team.HOME:
		# HOME offense tackled in home end zone = safety for AWAY
		if carrier_y > FIELD_HEIGHT - END_ZONE_DEPTH:
			_score_safety(PlayerFigure.Team.AWAY)
			return true
	else:
		# AWAY offense tackled in away end zone = safety for HOME
		if carrier_y < END_ZONE_DEPTH:
			_score_safety(PlayerFigure.Team.HOME)
			return true
	return false


# ========== DOWN PROGRESSION ==========

## Process the result of a play - update LOS, check first down, advance down
func _process_play_result(final_yard: int) -> void:
	# Ensure vibration stops when down is processed
	if _vibration:
		_vibration.stop_vibration()

	var yards_gained := _calculate_yards_gained(final_yard)

	# Update line of scrimmage to where ball carrier was tackled
	_line_of_scrimmage = final_yard

	# Check for first down
	if _check_first_down(yards_gained, final_yard):
		# First down achieved
		current_down = 1
		yards_to_go = 10
		first_down_achieved.emit()
	else:
		# Subtract yards gained from yards_to_go
		yards_to_go -= yards_gained
		current_down += 1

		# Check for turnover on downs
		if current_down > 4:
			_turnover_on_downs()
			return

	down_changed.emit(current_down, yards_to_go)
	scrimmage_changed.emit(_line_of_scrimmage, get_first_down_line())


## Calculate yards gained (positive = toward opponent's end zone)
func _calculate_yards_gained(final_yard: int) -> int:
	if _possession == PlayerFigure.Team.HOME:
		# HOME moves toward yard 0, so yards gained = start - end
		return _los_at_snap - final_yard
	else:
		# AWAY moves toward yard 100, so yards gained = end - start
		return final_yard - _los_at_snap


## Check if first down was achieved
func _check_first_down(yards_gained: int, final_yard: int) -> bool:
	if _possession == PlayerFigure.Team.HOME:
		# HOME needs to reach or pass the first down line (lower yard values)
		return final_yard <= get_first_down_line()
	else:
		# AWAY needs to reach or pass the first down line (higher yard values)
		return final_yard >= get_first_down_line()


## Handle turnover on downs - possession changes
func _turnover_on_downs() -> void:
	if _vibration:
		_vibration.stop_vibration()
	turnover_on_downs.emit()
	change_possession()
	# New team gets ball where it was
	current_down = 1
	yards_to_go = 10
	down_changed.emit(current_down, yards_to_go)
	scrimmage_changed.emit(_line_of_scrimmage, get_first_down_line())


# ========== POSSESSION ==========

## Change possession to the other team
func change_possession() -> void:
	if _possession == PlayerFigure.Team.HOME:
		possession = PlayerFigure.Team.AWAY
	else:
		possession = PlayerFigure.Team.HOME


# ========== SCORING ==========

## Score a touchdown (6 points)
func _score_touchdown(team: PlayerFigure.Team) -> void:
	add_score(team, 6)
	touchdown_scored.emit(team)
	_setup_kickoff(team)


## Score a field goal (3 points)
func _score_field_goal(team: PlayerFigure.Team) -> void:
	add_score(team, 3)
	field_goal_scored.emit(team)
	_setup_kickoff(team)


## Score a safety (2 points to opponent, scored-on team kicks)
func _score_safety(scoring_team: PlayerFigure.Team) -> void:
	add_score(scoring_team, 2)
	safety_scored.emit(scoring_team)

	# The team that was scored on kicks from their own 20
	var kicking_team := PlayerFigure.Team.AWAY if scoring_team == PlayerFigure.Team.HOME else PlayerFigure.Team.HOME
	possession = kicking_team

	# Set LOS to 20 yard line on kicking team's side
	if kicking_team == PlayerFigure.Team.HOME:
		_line_of_scrimmage = 80  # 20 yards from home goal line
	else:
		_line_of_scrimmage = 20  # 20 yards from away goal line

	current_down = 1
	yards_to_go = 10
	down_changed.emit(current_down, yards_to_go)
	scrimmage_changed.emit(_line_of_scrimmage, get_first_down_line())


## Set up for kickoff after a score
func _setup_kickoff(scoring_team: PlayerFigure.Team) -> void:
	# The team that scored kicks off (opponent receives)
	# For now, just change possession and set LOS to receiving team's 20
	if scoring_team == PlayerFigure.Team.HOME:
		possession = PlayerFigure.Team.AWAY
		_line_of_scrimmage = 80  # AWAY starts at their 20 (yard 80 = 20 from home end zone)
	else:
		possession = PlayerFigure.Team.HOME
		_line_of_scrimmage = 20  # HOME starts at their 20 (yard 20 = 20 from away end zone)

	current_down = 1
	yards_to_go = 10
	down_changed.emit(current_down, yards_to_go)
	scrimmage_changed.emit(_line_of_scrimmage, get_first_down_line())
