extends RigidBody2D
class_name PlayerFigure
## A single football player figure with configurable base prongs.

signal tackled(by: PlayerFigure)

# Team affiliation
enum Team { HOME = 0, AWAY = 1 }
@export var team: Team = Team.HOME

# Position roles
enum Role { LINEMAN, RECEIVER, QUARTERBACK, RUNNING_BACK, LINEBACKER, DEFENSIVE_BACK }
@export var role: Role = Role.LINEMAN

# Base configuration (the "coached" prong settings)
@export_range(-PI, PI) var base_direction: float = 0.0  # Primary movement angle (radians)
@export_range(0.1, 3.0) var base_speed: float = 1.0     # Movement magnitude multiplier
@export_range(-2.0, 2.0) var base_curve: float = 0.0    # Rotational drift (radians/sec)

# Ball carrier state
var _has_ball: bool = false
var has_ball: bool:
	get:
		return _has_ball
	set(value):
		_has_ball = value
		_update_ball_indicator()

# Reference to VibrationController (autoload)
@onready var _vibration: Node = get_node("/root/VibrationController")
@onready var _sprite: Polygon2D = $Sprite
@onready var _outline: Line2D = $Outline
@onready var _direction_indicator: Line2D = $DirectionIndicator
@onready var _selection_ring: Line2D = $SelectionRing
@onready var _ball_indicator: Line2D = $BallIndicator


func _ready() -> void:
	# Set up collision
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	# Set team color
	if team == Team.HOME:
		_sprite.color = Color(0.8, 0.2, 0.2)  # Red
	else:
		_sprite.color = Color(0.2, 0.4, 0.8)  # Blue

	# Set shape based on role
	var shape := _get_shape_for_role()
	_sprite.polygon = shape

	# Set outline to match shape
	_update_outline(shape)

	# Set initial rotation to match base_direction
	_update_visual_rotation()


func _get_shape_for_role() -> PackedVector2Array:
	match role:
		Role.LINEMAN:
			# Wide blocky shape
			return PackedVector2Array([
				Vector2(-14, -10), Vector2(14, -10),
				Vector2(16, -6), Vector2(16, 6),
				Vector2(14, 10), Vector2(-14, 10),
				Vector2(-16, 6), Vector2(-16, -6)
			])
		Role.RECEIVER:
			# Slim fast shape
			return PackedVector2Array([
				Vector2(-8, -14), Vector2(8, -14),
				Vector2(10, -10), Vector2(10, 10),
				Vector2(8, 14), Vector2(-8, 14),
				Vector2(-10, 10), Vector2(-10, -10)
			])
		Role.QUARTERBACK:
			# Distinct shape with pointed front
			return PackedVector2Array([
				Vector2(-10, -12), Vector2(10, -12),
				Vector2(14, 0), Vector2(10, 12),
				Vector2(-10, 12), Vector2(-14, 0)
			])
		Role.RUNNING_BACK:
			# Medium rounded shape
			return PackedVector2Array([
				Vector2(-10, -12), Vector2(10, -12),
				Vector2(13, -6), Vector2(13, 6),
				Vector2(10, 12), Vector2(-10, 12),
				Vector2(-13, 6), Vector2(-13, -6)
			])
		Role.LINEBACKER:
			# Wide defensive shape
			return PackedVector2Array([
				Vector2(-12, -12), Vector2(12, -12),
				Vector2(15, -4), Vector2(15, 4),
				Vector2(12, 12), Vector2(-12, 12),
				Vector2(-15, 4), Vector2(-15, -4)
			])
		Role.DEFENSIVE_BACK:
			# Slim defensive shape
			return PackedVector2Array([
				Vector2(-8, -13), Vector2(8, -13),
				Vector2(11, -8), Vector2(11, 8),
				Vector2(8, 13), Vector2(-8, 13),
				Vector2(-11, 8), Vector2(-11, -8)
			])
		_:
			# Default shape
			return PackedVector2Array([
				Vector2(-12, -15), Vector2(12, -15),
				Vector2(15, -8), Vector2(15, 8),
				Vector2(12, 15), Vector2(-12, 15),
				Vector2(-15, 8), Vector2(-15, -8)
			])


func _physics_process(delta: float) -> void:
	# Always update visual rotation to match base_direction
	_update_visual_rotation()

	# Update ball carrier pulse effect
	_update_ball_pulse(delta)

	if not _vibration or not _vibration.is_vibrating:
		return

	# Get vibration impulse from controller
	var impulse: Vector2 = _vibration.get_vibration_impulse(base_direction, base_speed)
	apply_central_impulse(impulse)

	# Apply rotational drift (base curve)
	if base_curve != 0.0:
		base_direction += base_curve * delta


func _update_visual_rotation() -> void:
	_sprite.rotation = base_direction
	if _outline:
		_outline.rotation = base_direction
	_direction_indicator.rotation = base_direction


func _update_outline(shape: PackedVector2Array) -> void:
	if not _outline:
		return
	# Create closed loop for outline
	var outline_points := PackedVector2Array()
	for point in shape:
		outline_points.append(point)
	# Close the loop
	if shape.size() > 0:
		outline_points.append(shape[0])
	_outline.points = outline_points


var _ball_pulse_time: float = 0.0

func _update_ball_indicator() -> void:
	if _ball_indicator:
		_ball_indicator.visible = _has_ball
		_ball_pulse_time = 0.0


func _update_ball_pulse(delta: float) -> void:
	if _ball_indicator and _has_ball:
		_ball_pulse_time += delta * 4.0  # Pulse speed
		var pulse := 0.7 + 0.3 * sin(_ball_pulse_time)
		_ball_indicator.modulate.a = pulse


func _on_body_entered(body: Node) -> void:
	if body is PlayerFigure:
		var other := body as PlayerFigure
		# Check for tackle (different teams, one has ball)
		if other.team != team:
			if _has_ball:
				tackled.emit(other)
			elif other.has_ball:
				other.tackled.emit(self)


## Set the base configuration (direction, speed, curve)
func set_base_config(direction: float, speed: float, curve: float) -> void:
	base_direction = direction
	base_speed = speed
	base_curve = curve


## Rotate the base direction by an amount (for pre-snap adjustments)
func adjust_direction(angle_delta: float) -> void:
	base_direction = wrapf(base_direction + angle_delta, -PI, PI)


## Set whether this player is selected (shows selection ring)
func set_selected(selected: bool) -> void:
	_selection_ring.visible = selected


## Check if this player is eligible to catch a pass.
## Eligible: RECEIVER, RUNNING_BACK, QUARTERBACK (but not the one who threw)
func is_eligible_receiver() -> bool:
	return role in [Role.RECEIVER, Role.RUNNING_BACK, Role.QUARTERBACK]


## Check if this player is a quarterback.
func is_quarterback() -> bool:
	return role == Role.QUARTERBACK
