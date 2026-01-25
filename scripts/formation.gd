extends Resource
class_name Formation
## A saved formation containing player positions and base configurations.

## Formation name for display
@export var formation_name: String = "Custom Formation"

## Player data stored as dictionaries with keys: name, position, base_direction, base_speed, base_curve
@export var players: Array[Dictionary] = []

## Line of scrimmage when this formation was saved
@export var line_of_scrimmage: int = 50


## Create a formation from current player positions.
static func from_players(player_nodes: Array, los: int, fname: String = "Custom Formation") -> Resource:
	var script: GDScript = load("res://scripts/formation.gd")
	var formation: Resource = script.new()
	formation.formation_name = fname
	formation.line_of_scrimmage = los

	for player in player_nodes:
		if player is PlayerFigure:
			formation.players.append({
				"name": player.name,
				"position_x": player.global_position.x,
				"position_y": player.global_position.y,
				"base_direction": player.base_direction,
				"base_speed": player.base_speed,
				"base_curve": player.base_curve,
			})

	return formation


## Apply this formation to player nodes.
## Returns the number of players successfully positioned.
func apply_to_players(player_nodes: Array) -> int:
	var count := 0

	# Build a lookup by player name
	var player_lookup := {}
	for player in player_nodes:
		if player is PlayerFigure:
			player_lookup[player.name] = player

	# Apply saved positions
	for data in players:
		var player_name: String = data.get("name", "")
		if player_name in player_lookup:
			var player: PlayerFigure = player_lookup[player_name]

			# Stop any physics movement
			player.linear_velocity = Vector2.ZERO
			player.angular_velocity = 0.0
			player.sleeping = true

			# Set position via physics server for immediate effect
			var state := PhysicsServer2D.body_get_direct_state(player.get_rid())
			var pos := Vector2(data.get("position_x", 0.0), data.get("position_y", 0.0))
			if state:
				state.transform = Transform2D(0, pos)
			else:
				player.global_position = pos

			player.sleeping = false

			# Apply base configuration
			player.base_direction = data.get("base_direction", 0.0)
			player.base_speed = data.get("base_speed", 1.0)
			player.base_curve = data.get("base_curve", 0.0)

			count += 1

	return count


## Save this formation to a file.
func save_to_file(path: String) -> Error:
	return ResourceSaver.save(self, path)


## Load a formation from a file.
static func load_from_file(path: String) -> Resource:
	if not FileAccess.file_exists(path):
		return null
	var resource = ResourceLoader.load(path)
	if resource and resource.has_method("apply_to_players"):
		return resource
	return null


## Get a list of saved formation files in the formations directory.
static func get_saved_formations() -> Array[String]:
	var formations: Array[String] = []
	var dir := DirAccess.open("res://resources/formations")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				formations.append(file_name.get_basename())
			file_name = dir.get_next()
		dir.list_dir_end()
	return formations
