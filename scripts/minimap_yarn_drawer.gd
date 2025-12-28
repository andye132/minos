extends Node2D
class_name MinimapYarnDrawer

var minimap: Minimap
var maze_ref: MazeGen
var yarn_trail_ref: YarnTrail

# Colors
var fog_color: Color = Color(0.05, 0.05, 0.08, 1.0)  # Dark fog
var wall_color: Color = Color(0.15, 0.12, 0.1, 1.0)  # Slightly visible walls
var lit_hallway_color: Color = Color(0.4, 0.35, 0.25, 1.0)  # Lit floor
var yarn_color: Color = Color(1.0, 0.7, 0.2, 1.0)
var yarn_color_broken: Color = Color(0.4, 0.3, 0.2, 0.5)
var yarn_width: float = 6.0
var glow_radius: float = 60.0  # Radius around yarn that gets lit


func _ready() -> void:
	minimap = get_parent().get_parent() as Minimap


func _draw() -> void:
	if not minimap:
		return

	var tile_size = 16.0  # Base tile size (before scale)

	# Draw fog background covering everything
	if maze_ref:
		var maze_pixel_width = maze_ref.x_dim * tile_size
		var maze_pixel_height = maze_ref.y_dim * tile_size
		draw_rect(Rect2(-tile_size, -tile_size, maze_pixel_width + tile_size * 2, maze_pixel_height + tile_size * 2), fog_color)

	# Get yarn points for lighting calculation
	var yarn_points: Array[Vector2] = []
	if yarn_trail_ref:
		yarn_points = yarn_trail_ref.get_points()

	# Get player positions for flashlight lighting
	var player_positions: Array[Dictionary] = []
	for player in minimap.players:
		if is_instance_valid(player):
			player_positions.append({
				"pos": player.global_position / 3.0,  # Account for maze scale
				"dir": player.look_direction,
				"angle": deg_to_rad(45.0),  # Flashlight half-angle
				"range": 150.0  # Flashlight range on minimap
			})

	# Draw maze tiles - walls and lit hallways
	if maze_ref:
		var half_tile = tile_size / 2.0

		# Draw all cells
		for y in range(-1, maze_ref.y_dim + 1):
			for x in range(-1, maze_ref.x_dim + 1):
				var cell_pos = Vector2i(x, y)
				var world_pos = Vector2(x * tile_size + half_tile, y * tile_size + half_tile)
				var is_wall = maze_ref.is_wall(cell_pos) or x < 0 or y < 0 or x >= maze_ref.x_dim or y >= maze_ref.y_dim

				if is_wall:
					# Always show walls dimly
					draw_rect(Rect2(x * tile_size, y * tile_size, tile_size, tile_size), wall_color)
				else:
					# Check if this hallway is lit by yarn or flashlight
					var is_lit = _is_position_lit(world_pos, yarn_points, player_positions)
					if is_lit:
						draw_rect(Rect2(x * tile_size, y * tile_size, tile_size, tile_size), lit_hallway_color)
					# Unlit hallways stay as fog (already drawn)

	# Draw yarn trail on top
	for player in minimap.players:
		if is_instance_valid(player):
			var yarn_trail = player.get_yarn_trail()
			if yarn_trail:
				var points = yarn_trail.get_points()
				var is_continuous = yarn_trail.is_continuous

				if points.size() >= 2:
					# Scale points to match minimap (maze is scaled 3x in world)
					var scaled_points: PackedVector2Array = PackedVector2Array()
					for point in points:
						scaled_points.append(point / 3.0)

					var color = yarn_color if is_continuous else yarn_color_broken
					draw_polyline(scaled_points, color, yarn_width, true)


func _is_position_lit(pos: Vector2, yarn_points: Array[Vector2], player_lights: Array[Dictionary]) -> bool:
	# Check if lit by yarn
	for yarn_pos in yarn_points:
		var scaled_yarn = yarn_pos / 3.0  # Account for maze scale
		if pos.distance_to(scaled_yarn) < glow_radius:
			return true

	# Check if lit by player flashlight
	for light in player_lights:
		var to_pos = pos - light.pos
		var distance = to_pos.length()

		if distance < light.range:
			# Check if within flashlight cone
			var angle_to_pos = to_pos.angle()
			var light_angle = light.dir.angle()
			var angle_diff = abs(angle_difference(angle_to_pos, light_angle))

			if angle_diff < light.angle:
				return true

	return false
