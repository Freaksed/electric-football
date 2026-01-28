extends Node2D
## Main scene controller - handles input and debug UI.

const FormationScript := preload("res://scripts/formation.gd")
const BallScene := preload("res://scenes/ball.tscn")

@onready var _vibration: Node = get_node("/root/VibrationController")
@onready var _game_manager: GameManager = $GameManager
@onready var _field: Node = $Field
@onready var _vibration_status: Label = $DebugUI/VBoxContainer/VibrationStatus
@onready var _scrimmage_label: Label = $DebugUI/VBoxContainer/ScrimmageLabel
@onready var _frequency_label: Label = $DebugUI/VBoxContainer/FrequencyLabel
@onready var _frequency_slider: HSlider = $DebugUI/VBoxContainer/FrequencySlider
@onready var _amplitude_label: Label = $DebugUI/VBoxContainer/AmplitudeLabel
@onready var _amplitude_slider: HSlider = $DebugUI/VBoxContainer/AmplitudeSlider

# Player tuning UI
@onready var _player_panel: VBoxContainer = $DebugUI/PlayerPanel
@onready var _player_label: Label = $DebugUI/PlayerPanel/PlayerLabel
@onready var _direction_slider: HSlider = $DebugUI/PlayerPanel/DirectionSlider
@onready var _direction_label: Label = $DebugUI/PlayerPanel/DirectionLabel
@onready var _speed_slider: HSlider = $DebugUI/PlayerPanel/SpeedSlider
@onready var _speed_label: Label = $DebugUI/PlayerPanel/SpeedLabel
@onready var _curve_slider: HSlider = $DebugUI/PlayerPanel/CurveSlider
@onready var _curve_label: Label = $DebugUI/PlayerPanel/CurveLabel

var _initial_positions: Dictionary = {}
var _selected_player: PlayerFigure = null
var _is_rotating: bool = false  # Right-click drag to rotate selected player
var _is_dragging: bool = false  # Left-click drag to move selected player
var _drag_offset: Vector2 = Vector2.ZERO

# Ball and passing (using Node for load-order compatibility)
var _ball: Node = null
var _is_aiming: bool = false
var _aiming_qb: PlayerFigure = null
var _aim_indicator: Line2D = null

# Kicking
var _kick_mode: bool = false
var _kick_position: Vector2 = Vector2.ZERO

# Formation management
var _current_formation_slot: int = 1
const FORMATIONS_DIR := "user://formations/"
const MAX_FORMATION_SLOTS := 9

# Preset formations
const OFFENSE_PRESETS := [
	"res://resources/formations/offense_i_formation.tres",
	"res://resources/formations/offense_shotgun.tres",
	"res://resources/formations/offense_singleback.tres",
	"res://resources/formations/offense_spread.tres",
	"res://resources/formations/offense_goal_line.tres",
]
const DEFENSE_PRESETS := [
	"res://resources/formations/defense_4_3.tres",
	"res://resources/formations/defense_3_4.tres",
	"res://resources/formations/defense_nickel.tres",
	"res://resources/formations/defense_46.tres",
	"res://resources/formations/defense_goal_line.tres",
]


func _ready() -> void:
	# Ensure formations directory exists
	DirAccess.make_dir_recursive_absolute(FORMATIONS_DIR.replace("user://", OS.get_user_data_dir() + "/"))

	# Store initial player state for reset
	for player in $Players.get_children():
		_initial_positions[player] = {
			"position": player.global_position,
			"rotation": player.global_rotation,
			"base_direction": player.base_direction
		}

	# Create and add the ball
	_ball = BallScene.instantiate()
	add_child(_ball)
	_ball.reset()

	# Create aim indicator (line from QB to target)
	_aim_indicator = Line2D.new()
	_aim_indicator.width = 3.0
	_aim_indicator.default_color = Color(1.0, 0.5, 0.0, 0.8)  # Orange
	_aim_indicator.visible = false
	add_child(_aim_indicator)

	# Connect UI signals
	_frequency_slider.value_changed.connect(_on_frequency_changed)
	_amplitude_slider.value_changed.connect(_on_amplitude_changed)

	# Connect player tuning UI signals
	_direction_slider.value_changed.connect(_on_direction_changed)
	_speed_slider.value_changed.connect(_on_speed_changed)
	_curve_slider.value_changed.connect(_on_curve_changed)

	# Connect vibration signals
	if _vibration:
		_vibration.vibration_started.connect(_on_vibration_started)
		_vibration.vibration_stopped.connect(_on_vibration_stopped)

	# Connect game manager signals
	if _game_manager:
		_game_manager.scrimmage_changed.connect(_on_scrimmage_changed)
		_game_manager.phase_changed.connect(_on_phase_changed)
		_game_manager.play_started.connect(_on_play_started)
		_game_manager.play_ended.connect(_on_play_ended)
		_game_manager.pass_complete.connect(_on_pass_complete)
		_game_manager.pass_incomplete.connect(_on_pass_incomplete)
		_game_manager.pass_intercepted.connect(_on_pass_intercepted)
		_game_manager.score_changed.connect(_on_score_changed)
		_game_manager.possession_changed.connect(_on_possession_changed)
		_game_manager.touchdown_scored.connect(_on_touchdown_scored)
		_game_manager.field_goal_scored.connect(_on_field_goal_scored)
		_game_manager.safety_scored.connect(_on_safety_scored)
		_game_manager.first_down_achieved.connect(_on_first_down)
		_game_manager.turnover_on_downs.connect(_on_turnover_on_downs)
		_game_manager.set_ball(_ball)
		# Set field reference for yard-to-position conversion
		_game_manager.field = _field

	_update_ui()
	_update_scrimmage_ui()
	_update_player_ui()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # Space bar
		_handle_space_pressed()

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_reset_players()
		if event.keycode == KEY_ESCAPE:
			if _is_aiming:
				_cancel_aim()
			elif _kick_mode:
				_cancel_kick_mode()
			else:
				_select_player(null)
		if event.keycode == KEY_Q:
			get_tree().quit()
		# Move line of scrimmage with arrow keys (only when not playing)
		if event.keycode == KEY_UP and _game_manager.can_edit_players():
			_game_manager.line_of_scrimmage -= 5
		if event.keycode == KEY_DOWN and _game_manager.can_edit_players():
			_game_manager.line_of_scrimmage += 5

		# K to enter kick mode (pre-snap only)
		if event.keycode == KEY_K and _game_manager.current_phase == GameManager.GamePhase.PRE_SNAP:
			_enter_kick_mode()

		# Formation save/load
		if event.keycode == KEY_F5 and _game_manager.can_edit_players():
			_save_formation(_current_formation_slot)
		if event.keycode == KEY_F9 and _game_manager.can_edit_players():
			_load_formation(_current_formation_slot)

		# Number keys 1-9 to switch formation slots (no modifiers)
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var slot: int = event.keycode - KEY_1 + 1
			if event.shift_pressed and _game_manager.can_edit_players():
				# Shift+1-5: Load offense preset
				if slot <= OFFENSE_PRESETS.size():
					_load_preset_formation(OFFENSE_PRESETS[slot - 1])
			elif event.ctrl_pressed and _game_manager.can_edit_players():
				# Ctrl+1-5: Load defense preset
				if slot <= DEFENSE_PRESETS.size():
					_load_preset_formation(DEFENSE_PRESETS[slot - 1])
			else:
				# Plain 1-9: Switch save slot
				_current_formation_slot = slot
				_update_ui()


func _handle_space_pressed() -> void:
	match _game_manager.current_phase:
		GameManager.GamePhase.PRE_SNAP:
			# Snap the ball - start the play
			_game_manager.snap()
		GameManager.GamePhase.PLAYING:
			# Blow the whistle - stop the play
			_game_manager.whistle()
		GameManager.GamePhase.PLAY_OVER:
			# Ready up for next play
			_game_manager.ready_for_next_play()
		_:
			# In SETUP or other phases, just ready for snap
			_game_manager.ready_for_next_play()


func _unhandled_input(event: InputEvent) -> void:
	var can_edit: bool = _game_manager.can_edit_players()
	var is_playing: bool = _game_manager.current_phase == GameManager.GamePhase.PLAYING

	# Left-click handling
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var clicked_player := _get_player_at_position(get_global_mouse_position())

			# During play: click on QB to start aiming
			if is_playing and not _is_aiming:
				if clicked_player and clicked_player.is_quarterback() and clicked_player.team == PlayerFigure.Team.HOME:
					_start_aim(clicked_player)
					return

			# Pre-snap editing
			if clicked_player and clicked_player == _selected_player and can_edit:
				# Start dragging the selected player
				_is_dragging = true
				_drag_offset = _selected_player.global_position - get_global_mouse_position()
				_selected_player.freeze = true
			else:
				# Select a different player
				_select_player(clicked_player)
		else:
			# Release drag
			if _is_dragging and _selected_player:
				_selected_player.freeze = false
				_update_player_initial_position(_selected_player)
			_is_dragging = false

	# Right-click handling
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			# If aiming, right-click throws the ball
			if _is_aiming and _aiming_qb:
				_throw_ball()
				return

			# If in kick mode during play, right-click kicks
			if is_playing and _kick_mode:
				_execute_kick()
				return

			# Otherwise, rotate selected player (pre-snap)
			if _selected_player and can_edit:
				_is_rotating = true
				_rotate_player_toward_mouse()
		else:
			if _is_rotating and _selected_player:
				_update_player_initial_position(_selected_player)
			_is_rotating = false

	# Mouse motion
	if event is InputEventMouseMotion:
		if _is_dragging and _selected_player and can_edit:
			_drag_player_to_mouse()
		if _is_rotating and _selected_player:
			_rotate_player_toward_mouse()
		if _is_aiming or _kick_mode:
			_update_aim_indicator()


func _rotate_player_toward_mouse() -> void:
	if not _selected_player:
		return
	var mouse_pos := get_global_mouse_position()
	var player_pos := _selected_player.global_position
	var direction := mouse_pos - player_pos
	_selected_player.base_direction = direction.angle()
	_update_player_ui()


func _drag_player_to_mouse() -> void:
	if not _selected_player:
		return
	var new_pos := get_global_mouse_position() + _drag_offset
	_selected_player.global_position = new_pos
	_selected_player.linear_velocity = Vector2.ZERO


func _update_player_initial_position(player: PlayerFigure) -> void:
	# Update the stored initial position so R resets to the new formation
	_initial_positions[player] = {
		"position": player.global_position,
		"rotation": player.global_rotation,
		"base_direction": player.base_direction
	}


func _on_vibration_started() -> void:
	_update_ui()


func _on_vibration_stopped() -> void:
	_update_ui()


func _on_frequency_changed(value: float) -> void:
	if _vibration:
		_vibration.vibration_frequency = value
	_update_ui()


func _on_amplitude_changed(value: float) -> void:
	if _vibration:
		_vibration.vibration_amplitude = value
	_update_ui()


func _update_ui() -> void:
	if _vibration and _game_manager:
		var phase_names := {
			GameManager.GamePhase.SETUP: "SETUP",
			GameManager.GamePhase.PRE_SNAP: "PRE-SNAP (Press SPACE to snap)",
			GameManager.GamePhase.PLAYING: "PLAYING (Press SPACE to whistle)",
			GameManager.GamePhase.PLAY_OVER: "PLAY OVER (Press R to reset)",
			GameManager.GamePhase.GAME_OVER: "GAME OVER",
		}
		var phase_name: String = phase_names.get(_game_manager.current_phase, "UNKNOWN")

		# Add mode indicators
		if _kick_mode:
			phase_name = "KICK MODE (Right-click to kick, ESC to cancel)"
		elif _is_aiming:
			phase_name = "AIMING (Right-click to throw, ESC to cancel)"

		# Add formation slot info
		var slot_status := "*" if _formation_exists(_current_formation_slot) else ""
		phase_name += " | Slot %d%s" % [_current_formation_slot, slot_status]

		_vibration_status.text = phase_name
		_frequency_label.text = "Frequency: %.0f Hz" % _vibration.vibration_frequency
		_amplitude_label.text = "Amplitude: %.0f" % _vibration.vibration_amplitude


func _on_scrimmage_changed(_los: int, _first_down: int) -> void:
	_update_scrimmage_ui()


func _on_phase_changed(_phase: GameManager.GamePhase) -> void:
	_update_ui()


func _on_play_started() -> void:
	_select_player(null)  # Deselect player when play starts


func _on_play_ended(_reason: String) -> void:
	_update_ui()


func _update_scrimmage_ui() -> void:
	if _game_manager:
		var los := _game_manager.line_of_scrimmage
		var down := _game_manager.current_down
		var ytg := _game_manager.yards_to_go
		var home_score := _game_manager.home_score
		var away_score := _game_manager.away_score
		var possession := _game_manager.possession
		var poss_str := "HOME" if possession == PlayerFigure.Team.HOME else "AWAY"

		var down_str := "%dst" % down if down == 1 else ("%dnd" % down if down == 2 else ("%drd" % down if down == 3 else "%dth" % down))
		_scrimmage_label.text = "HOME %d - AWAY %d | %s ball | LOS: %d yd | %s & %d" % [home_score, away_score, poss_str, los, down_str, ytg]


func _reset_players() -> void:
	# Stop play if in progress
	if _game_manager.current_phase == GameManager.GamePhase.PLAYING:
		_game_manager.whistle()

	# Cancel any aiming/kicking
	_cancel_aim()
	_cancel_kick_mode()

	for player in $Players.get_children():
		if player in _initial_positions:
			var data: Dictionary = _initial_positions[player]
			# Reset physics state
			player.linear_velocity = Vector2.ZERO
			player.angular_velocity = 0.0
			player.sleeping = true
			# Reset transform via physics server
			var state := PhysicsServer2D.body_get_direct_state(player.get_rid())
			if state:
				state.transform = Transform2D(data["rotation"], data["position"])
			else:
				player.global_position = data["position"]
				player.global_rotation = data["rotation"]
			player.sleeping = false
			# Reset base direction (drifts during play)
			player.base_direction = data["base_direction"]

	# Reset ball and play state
	_game_manager.reset_play_state()

	# Ready for next play
	_game_manager.ready_for_next_play()
	_update_player_ui()


func _get_formation_path(slot: int) -> String:
	return FORMATIONS_DIR + "formation_%d.tres" % slot


func _save_formation(slot: int) -> void:
	var players_array: Array = []
	for player in $Players.get_children():
		players_array.append(player)

	var formation := FormationScript.from_players(
		players_array,
		_game_manager.line_of_scrimmage,
		"Formation %d" % slot
	)

	var path := _get_formation_path(slot)
	var error: Error = formation.save_to_file(path)

	if error == OK:
		print("Formation saved to slot %d" % slot)
		# Update initial positions to match saved formation
		for player in $Players.get_children():
			_update_player_initial_position(player)
		_update_ui()
	else:
		print("Failed to save formation: %s" % error_string(error))


func _load_formation(slot: int) -> void:
	var path := _get_formation_path(slot)
	var formation := FormationScript.load_from_file(path)

	if formation == null:
		print("No formation found in slot %d" % slot)
		return

	# Stop play if in progress
	if _game_manager.current_phase == GameManager.GamePhase.PLAYING:
		_game_manager.whistle()

	var players_array: Array = []
	for player in $Players.get_children():
		players_array.append(player)

	var count: int = formation.apply_to_players(players_array)
	_game_manager.line_of_scrimmage = formation.line_of_scrimmage

	# Update initial positions to match loaded formation
	for player in $Players.get_children():
		_update_player_initial_position(player)

	_game_manager.ready_for_next_play()
	_update_ui()
	_update_player_ui()
	print("Loaded formation from slot %d (%d players)" % [slot, count])


func _formation_exists(slot: int) -> bool:
	return FileAccess.file_exists(_get_formation_path(slot))


func _load_preset_formation(path: String) -> void:
	var formation := FormationScript.load_from_file(path)
	if formation == null:
		print("Failed to load preset: %s" % path)
		return

	# Stop play if in progress
	if _game_manager.current_phase == GameManager.GamePhase.PLAYING:
		_game_manager.whistle()

	var players_array: Array = []
	for player in $Players.get_children():
		players_array.append(player)

	var count: int = formation.apply_to_players(players_array)

	# Update initial positions to match loaded formation
	for player in $Players.get_children():
		_update_player_initial_position(player)

	_game_manager.ready_for_next_play()
	_update_ui()
	_update_player_ui()
	print("Loaded preset: %s (%d players)" % [formation.formation_name, count])


func _get_player_at_position(pos: Vector2) -> PlayerFigure:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collision_mask = 1  # Players layer
	var results := space_state.intersect_point(query, 1)
	if results.size() > 0:
		var collider = results[0]["collider"]
		if collider is PlayerFigure:
			return collider
	return null


func _select_player(player: PlayerFigure) -> void:
	# Deselect previous player
	if _selected_player:
		_selected_player.set_selected(false)

	_selected_player = player

	# Select new player
	if _selected_player:
		_selected_player.set_selected(true)

	_update_player_ui()


func _update_player_ui() -> void:
	if _selected_player:
		_player_panel.visible = true
		var team_name := "Home" if _selected_player.team == PlayerFigure.Team.HOME else "Away"
		_player_label.text = "Selected: %s (%s)" % [_selected_player.name, team_name]

		# Update sliders without triggering callbacks
		_direction_slider.set_value_no_signal(rad_to_deg(_selected_player.base_direction))
		_speed_slider.set_value_no_signal(_selected_player.base_speed)
		_curve_slider.set_value_no_signal(rad_to_deg(_selected_player.base_curve))

		_direction_label.text = "Direction: %.0f°" % rad_to_deg(_selected_player.base_direction)
		_speed_label.text = "Speed: %.1f" % _selected_player.base_speed
		_curve_label.text = "Curve: %.1f°/s" % rad_to_deg(_selected_player.base_curve)
	else:
		_player_panel.visible = false


func _on_direction_changed(value: float) -> void:
	if _selected_player:
		_selected_player.base_direction = deg_to_rad(value)
		_direction_label.text = "Direction: %.0f°" % value


func _on_speed_changed(value: float) -> void:
	if _selected_player:
		_selected_player.base_speed = value
		_speed_label.text = "Speed: %.1f" % value


func _on_curve_changed(value: float) -> void:
	if _selected_player:
		_selected_player.base_curve = deg_to_rad(value)
		_curve_label.text = "Curve: %.1f°/s" % value


# ========== PASSING MECHANICS ==========

func _start_aim(qb: PlayerFigure) -> void:
	_is_aiming = true
	_aiming_qb = qb
	_aim_indicator.visible = true
	_update_aim_indicator()


func _cancel_aim() -> void:
	_is_aiming = false
	_aiming_qb = null
	_aim_indicator.visible = false


func _update_aim_indicator() -> void:
	if not _aim_indicator:
		return

	var start_pos: Vector2
	if _is_aiming and _aiming_qb:
		start_pos = _aiming_qb.global_position
		_aim_indicator.default_color = Color(1.0, 0.5, 0.0, 0.8)  # Orange for passing
	elif _kick_mode:
		start_pos = _kick_position
		_aim_indicator.default_color = Color(0.0, 0.8, 1.0, 0.8)  # Cyan for kicking
	else:
		_aim_indicator.visible = false
		return

	var end_pos := get_global_mouse_position()
	_aim_indicator.clear_points()
	_aim_indicator.add_point(start_pos)
	_aim_indicator.add_point(end_pos)

	# Show power indicator (distance)
	var distance := start_pos.distance_to(end_pos)
	var power := clampf(distance, 100.0, 400.0)
	var power_pct := (power - 100.0) / 300.0 * 100.0
	# Visual feedback: thicker line = more power
	_aim_indicator.width = 2.0 + power_pct / 25.0


func _throw_ball() -> void:
	if not _aiming_qb or not _game_manager:
		return

	var target := get_global_mouse_position()
	var distance := _aiming_qb.global_position.distance_to(target)
	var power := clampf(distance, 200.0, 600.0)

	_game_manager.throw_pass(_aiming_qb, target, power)
	_cancel_aim()


# ========== KICKING MECHANICS ==========

func _enter_kick_mode() -> void:
	_kick_mode = true
	# Find QB position for kick origin
	for player in $Players.get_children():
		if player is PlayerFigure and player.is_quarterback() and player.team == PlayerFigure.Team.HOME:
			_kick_position = player.global_position + Vector2(0, 50)  # Behind QB
			break
	_aim_indicator.visible = true
	_update_aim_indicator()
	_update_ui()


func _cancel_kick_mode() -> void:
	_kick_mode = false
	_aim_indicator.visible = false
	_update_ui()


func _execute_kick() -> void:
	if not _game_manager:
		return

	var target := get_global_mouse_position()
	var distance := _kick_position.distance_to(target)
	var power := clampf(distance, 300.0, 800.0)

	_game_manager.kick(_kick_position, target, power, PlayerFigure.Team.HOME)
	_cancel_kick_mode()


# ========== PASS RESULT HANDLERS ==========

func _on_pass_complete(receiver: PlayerFigure) -> void:
	print("Pass complete to %s!" % receiver.name)
	_update_ui()


func _on_pass_incomplete(reason: String) -> void:
	print("Incomplete pass: %s" % reason)
	_update_ui()


func _on_pass_intercepted(interceptor: PlayerFigure) -> void:
	print("INTERCEPTION by %s!" % interceptor.name)
	_update_ui()
	_update_scrimmage_ui()


# ========== GAME RULES EVENT HANDLERS ==========

func _on_score_changed(_home: int, _away: int) -> void:
	_update_scrimmage_ui()


func _on_possession_changed(team: PlayerFigure.Team) -> void:
	var team_name := "HOME" if team == PlayerFigure.Team.HOME else "AWAY"
	print(">>> POSSESSION: %s team now has the ball" % team_name)
	_update_scrimmage_ui()


func _on_touchdown_scored(team: PlayerFigure.Team) -> void:
	var team_name := "HOME" if team == PlayerFigure.Team.HOME else "AWAY"
	print("*** TOUCHDOWN! %s scores 6 points! ***" % team_name)
	_update_scrimmage_ui()


func _on_field_goal_scored(team: PlayerFigure.Team) -> void:
	var team_name := "HOME" if team == PlayerFigure.Team.HOME else "AWAY"
	print("*** FIELD GOAL! %s scores 3 points! ***" % team_name)
	_update_scrimmage_ui()


func _on_safety_scored(team: PlayerFigure.Team) -> void:
	var team_name := "HOME" if team == PlayerFigure.Team.HOME else "AWAY"
	print("*** SAFETY! %s scores 2 points! ***" % team_name)
	_update_scrimmage_ui()


func _on_first_down() -> void:
	print(">>> FIRST DOWN!")
	_update_scrimmage_ui()


func _on_turnover_on_downs() -> void:
	print(">>> TURNOVER ON DOWNS!")
	_update_scrimmage_ui()
