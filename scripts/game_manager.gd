extends Node
class_name GameManager
## Manages game state, rules, and flow.

signal play_started
signal play_ended(reason: String)
signal score_changed(home: int, away: int)
signal down_changed(down: int, yards_to_go: int)
signal scrimmage_changed(los: int, first_down_line: int)
signal phase_changed(phase: GamePhase)

enum GamePhase { SETUP, PRE_SNAP, PLAYING, PLAY_OVER, GAME_OVER }

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

# Down and distance
var current_down: int = 1
var yards_to_go: int = 10
var _line_of_scrimmage: int = 50  # Yard line (0-100, 0 = away end zone, 50 = midfield)

## Line of scrimmage yard line (0 = away end zone, 100 = home end zone)
var line_of_scrimmage: int:
	get:
		return _line_of_scrimmage
	set(value):
		_line_of_scrimmage = clampi(value, 0, 100)
		scrimmage_changed.emit(_line_of_scrimmage, get_first_down_line())


## Get the yard line where first down is achieved
func get_first_down_line() -> int:
	# First down line is toward the home end zone (higher y values)
	return mini(_line_of_scrimmage + yards_to_go, 100)

# Ball carrier tracking
var _ball_carrier: PlayerFigure = null

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
	current_phase = GamePhase.PLAY_OVER
	play_ended.emit("tackle")


## Called when player wants to snap the ball. Returns true if snap was successful.
func snap() -> bool:
	if current_phase != GamePhase.PRE_SNAP:
		return false

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
