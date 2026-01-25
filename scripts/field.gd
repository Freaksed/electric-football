extends Node2D
class_name FootballField
## The football field with yard lines and boundaries.

# Standard field dimensions (scaled for game) - PORTRAIT orientation
# Field is now vertical with end zones at top and bottom
const FIELD_WIDTH: float = 520.0
const FIELD_HEIGHT: float = 1000.0
const END_ZONE_DEPTH: float = 80.0
const YARD_LINE_SPACING: float = (FIELD_HEIGHT - 2 * END_ZONE_DEPTH) / 10.0  # 10 yard lines

# Colors
const FIELD_COLOR := Color(0.133, 0.545, 0.133)  # Forest green
const LINE_COLOR := Color.WHITE
const END_ZONE_HOME_COLOR := Color(0.6, 0.1, 0.1)  # Dark red
const END_ZONE_AWAY_COLOR := Color(0.1, 0.1, 0.6)  # Dark blue
const LOS_COLOR := Color(0.2, 0.6, 1.0, 0.8)  # Blue line of scrimmage
const FIRST_DOWN_COLOR := Color(1.0, 0.9, 0.0, 0.8)  # Yellow first down marker
const GOAL_POST_COLOR := Color(1.0, 0.9, 0.0, 1.0)  # Yellow goal posts

# Goal post positions (centered, NFL-style 18.5 feet apart scaled down)
const GOAL_POST_LEFT_X: float = FIELD_WIDTH / 2.0 - 40.0
const GOAL_POST_RIGHT_X: float = FIELD_WIDTH / 2.0 + 40.0
const GOAL_POST_HEIGHT: float = 30.0

# Game state reference
var _game_manager: GameManager = null
var _los_yard: int = 50
var _first_down_yard: int = 60


func _ready() -> void:
	# Find GameManager in parent scene
	await get_tree().process_frame  # Wait for scene tree to be ready
	_game_manager = get_node_or_null("../GameManager")
	if _game_manager:
		_game_manager.scrimmage_changed.connect(_on_scrimmage_changed)
		_los_yard = _game_manager.line_of_scrimmage
		_first_down_yard = _game_manager.get_first_down_line()
	queue_redraw()


func _on_scrimmage_changed(los: int, first_down_line: int) -> void:
	_los_yard = los
	_first_down_yard = first_down_line
	queue_redraw()


func _draw() -> void:
	_draw_field_surface()
	_draw_end_zones()
	_draw_yard_lines()
	_draw_scrimmage_lines()
	_draw_goal_posts()
	_draw_boundary()


func _draw_field_surface() -> void:
	# Main playing surface
	var field_rect := Rect2(Vector2.ZERO, Vector2(FIELD_WIDTH, FIELD_HEIGHT))
	draw_rect(field_rect, FIELD_COLOR)


func _draw_end_zones() -> void:
	# Home end zone (bottom)
	var home_ez := Rect2(Vector2(0, FIELD_HEIGHT - END_ZONE_DEPTH), Vector2(FIELD_WIDTH, END_ZONE_DEPTH))
	draw_rect(home_ez, END_ZONE_HOME_COLOR)

	# Away end zone (top)
	var away_ez := Rect2(Vector2.ZERO, Vector2(FIELD_WIDTH, END_ZONE_DEPTH))
	draw_rect(away_ez, END_ZONE_AWAY_COLOR)


func _draw_yard_lines() -> void:
	var line_width := 2.0

	# Goal lines (horizontal, at edge of end zones)
	draw_line(Vector2(0, END_ZONE_DEPTH), Vector2(FIELD_WIDTH, END_ZONE_DEPTH), LINE_COLOR, line_width)
	draw_line(Vector2(0, FIELD_HEIGHT - END_ZONE_DEPTH), Vector2(FIELD_WIDTH, FIELD_HEIGHT - END_ZONE_DEPTH), LINE_COLOR, line_width)

	# 10-yard lines (horizontal)
	for i in range(1, 10):
		var y := END_ZONE_DEPTH + i * YARD_LINE_SPACING
		draw_line(Vector2(0, y), Vector2(FIELD_WIDTH, y), LINE_COLOR, 1.0)

	# 50-yard line (thicker)
	var midfield_y := FIELD_HEIGHT / 2.0
	draw_line(Vector2(0, midfield_y), Vector2(FIELD_WIDTH, midfield_y), LINE_COLOR, 3.0)

	# Hash marks (vertical dashes on yard lines)
	var hash_x_left := FIELD_WIDTH * 0.35
	var hash_x_right := FIELD_WIDTH * 0.65
	var hash_length := 10.0

	for i in range(0, 11):
		var y := END_ZONE_DEPTH + i * YARD_LINE_SPACING
		# Left hash
		draw_line(Vector2(hash_x_left, y - hash_length/2), Vector2(hash_x_left, y + hash_length/2), LINE_COLOR, 1.0)
		# Right hash
		draw_line(Vector2(hash_x_right, y - hash_length/2), Vector2(hash_x_right, y + hash_length/2), LINE_COLOR, 1.0)


func _draw_scrimmage_lines() -> void:
	var line_width := 4.0

	# Line of scrimmage (blue)
	var los_y := yard_to_y(_los_yard)
	draw_line(Vector2(0, los_y), Vector2(FIELD_WIDTH, los_y), LOS_COLOR, line_width)

	# First down marker (yellow) - only draw if different from LOS
	if _first_down_yard != _los_yard and _first_down_yard < 100:
		var fd_y := yard_to_y(_first_down_yard)
		draw_line(Vector2(0, fd_y), Vector2(FIELD_WIDTH, fd_y), FIRST_DOWN_COLOR, line_width)


func _draw_boundary() -> void:
	var boundary_rect := Rect2(Vector2.ZERO, Vector2(FIELD_WIDTH, FIELD_HEIGHT))
	draw_rect(boundary_rect, LINE_COLOR, false, 4.0)


## Convert yard line (0-100) to y position on field (0 = away/top end zone)
func yard_to_y(yard_line: int) -> float:
	var playing_field_height := FIELD_HEIGHT - 2 * END_ZONE_DEPTH
	return END_ZONE_DEPTH + (yard_line / 100.0) * playing_field_height


## Convert y position to yard line (0-100)
func y_to_yard(y: float) -> int:
	var playing_field_height := FIELD_HEIGHT - 2 * END_ZONE_DEPTH
	var yard := ((y - END_ZONE_DEPTH) / playing_field_height) * 100.0
	return clampi(int(yard), 0, 100)


func _draw_goal_posts() -> void:
	var line_width := 3.0

	# Away end zone goal posts (top)
	var away_goal_y := END_ZONE_DEPTH / 2.0
	# Crossbar
	draw_line(Vector2(GOAL_POST_LEFT_X, away_goal_y), Vector2(GOAL_POST_RIGHT_X, away_goal_y), GOAL_POST_COLOR, line_width)
	# Left upright (going up/into screen, represented as short line)
	draw_line(Vector2(GOAL_POST_LEFT_X, away_goal_y), Vector2(GOAL_POST_LEFT_X, away_goal_y - GOAL_POST_HEIGHT), GOAL_POST_COLOR, line_width)
	# Right upright
	draw_line(Vector2(GOAL_POST_RIGHT_X, away_goal_y), Vector2(GOAL_POST_RIGHT_X, away_goal_y - GOAL_POST_HEIGHT), GOAL_POST_COLOR, line_width)

	# Home end zone goal posts (bottom)
	var home_goal_y := FIELD_HEIGHT - END_ZONE_DEPTH / 2.0
	# Crossbar
	draw_line(Vector2(GOAL_POST_LEFT_X, home_goal_y), Vector2(GOAL_POST_RIGHT_X, home_goal_y), GOAL_POST_COLOR, line_width)
	# Left upright
	draw_line(Vector2(GOAL_POST_LEFT_X, home_goal_y), Vector2(GOAL_POST_LEFT_X, home_goal_y + GOAL_POST_HEIGHT), GOAL_POST_COLOR, line_width)
	# Right upright
	draw_line(Vector2(GOAL_POST_RIGHT_X, home_goal_y), Vector2(GOAL_POST_RIGHT_X, home_goal_y + GOAL_POST_HEIGHT), GOAL_POST_COLOR, line_width)


## Get goal post info for a given end zone (for field goal detection).
## Returns a dictionary with goal_y, left_x, right_x.
func get_goal_post_info(home_end_zone: bool) -> Dictionary:
	if home_end_zone:
		return {
			"goal_y": FIELD_HEIGHT - END_ZONE_DEPTH,
			"left_x": GOAL_POST_LEFT_X,
			"right_x": GOAL_POST_RIGHT_X
		}
	else:
		return {
			"goal_y": END_ZONE_DEPTH,
			"left_x": GOAL_POST_LEFT_X,
			"right_x": GOAL_POST_RIGHT_X
		}
