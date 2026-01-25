extends Node
## Autoload singleton that controls the global vibration state.
## All player figures query this for vibration parameters.

signal vibration_started
signal vibration_stopped

# Vibration parameters
var vibration_frequency: float = 60.0  # Perturbations per second
var vibration_amplitude: float = 50.0  # Force magnitude

var _is_vibrating: bool = false
var _vibration_timer: float = 0.0

# Read-only access to vibration state
var is_vibrating: bool:
	get:
		return _is_vibrating


func _physics_process(delta: float) -> void:
	if _is_vibrating:
		_vibration_timer += delta


func start_vibration() -> void:
	if not _is_vibrating:
		_is_vibrating = true
		_vibration_timer = 0.0
		vibration_started.emit()


func stop_vibration() -> void:
	if _is_vibrating:
		_is_vibrating = false
		vibration_stopped.emit()


func toggle_vibration() -> void:
	if _is_vibrating:
		stop_vibration()
	else:
		start_vibration()


## Returns a randomized vibration impulse for this physics frame.
## Called by each player to get their per-frame force.
func get_vibration_impulse(base_direction: float, base_speed: float) -> Vector2:
	if not _is_vibrating:
		return Vector2.ZERO

	# Base direction vector
	var direction := Vector2.from_angle(base_direction)

	# Add random perturbation (the "chaos" of the vibrating field)
	var noise_angle := randf_range(-PI / 6, PI / 6)  # +/- 30 degrees
	var noise_magnitude := randf_range(0.5, 1.5)

	direction = direction.rotated(noise_angle)

	# Calculate final impulse
	var impulse := direction * vibration_amplitude * base_speed * noise_magnitude

	return impulse
