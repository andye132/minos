extends Node2D
class_name MinimapYarnDrawer

var minimap: Minimap
var maze_ref: MazeGen
var yarn_trail_ref: YarnTrail
var fog_of_war_ref: FogOfWar
var world_scale: float = 0.8  # Maze tile scale in world
var base_tile_size: float = 160.0  # Base tile size before scaling
var minimap_tile_size: float = 16.0  # Tile size for minimap drawing

# Colors
var unexplored_color: Color = Color(0.0, 0.0, 0.0, 1.0)  # Pitch black
var revealed_wall_color: Color = Color(0.12, 0.1, 0.08, 1.0)  # Dark walls
var revealed_hallway_color: Color = Color(0.18, 0.15, 0.12, 1.0)  # Dark hallways
var visible_wall_color: Color = Color(0.3, 0.25, 0.2, 1.0)  # Lit walls
var visible_hallway_color: Color = Color(0.4, 0.35, 0.28, 1.0)  # Lit hallways
var yarn_color: Color = Color(1.0, 0.7, 0.2, 1.0)
var yarn_width: float = 3.0

# Visibility radius for "currently lit" on minimap (in world units)
var player_visible_radius: float = 200.0  # Adjusted for 128px tile size
var yarn_visible_radius: float = 150.0  # Adjusted for 128px tile size


func _ready() -> void:
	minimap = get_parent().get_parent() as Minimap


func _draw() -> void:
	if not minimap:
		return

	# Get references from minimap if not set directly
	if not maze_ref and minimap.maze_ref:
		maze_ref = minimap.maze_ref
	if not yarn_trail_ref and minimap.yarn_trail_ref:
		yarn_trail_ref = minimap.yarn_trail_ref
	if not fog_of_war_ref and minimap.fog_of_war_ref:
		fog_of_war_ref = minimap.fog_of_war_ref

	if not maze_ref:
		return

	# Calculate conversion factors
	var world_tile_size = base_tile_size * world_scale  # 128 pixels per tile in world

	# Get player position for visibility check
	var player_world_pos: Vector2 = Vector2.ZERO
	if minimap.players.size() > 0 and is_instance_valid(minimap.players[0]):
		player_world_pos = minimap.players[0].global_position

	# Get yarn points for visibility check
	var yarn_points: Array[Vector2] = []
	if yarn_trail_ref:
		yarn_points = yarn_trail_ref.get_points()

	# Draw each tile based on fog of war state
	for y in range(maze_ref.y_dim):
		for x in range(maze_ref.x_dim):
			var tile_pos = Vector2i(x, y)
			# Draw tile at minimap coordinates
			var tile_rect = Rect2(x * minimap_tile_size, y * minimap_tile_size, minimap_tile_size, minimap_tile_size)

			# Convert tile center to world position for fog checks
			var tile_center_world = Vector2((x + 0.5) * world_tile_size, (y + 0.5) * world_tile_size)

			# Determine visibility state
			var is_wall = maze_ref.is_wall(tile_pos)
			var is_revealed = _is_tile_revealed(tile_center_world)
			var is_visible = _is_tile_currently_visible(tile_center_world, player_world_pos, yarn_points)

			# Draw based on state
			if is_visible:
				# Currently lit - bright colors
				if is_wall:
					draw_rect(tile_rect, visible_wall_color)
				else:
					draw_rect(tile_rect, visible_hallway_color)
			elif is_revealed:
				# Previously seen - dark but visible
				if is_wall:
					draw_rect(tile_rect, revealed_wall_color)
				else:
					draw_rect(tile_rect, revealed_hallway_color)
			else:
				# Never seen - pitch black
				draw_rect(tile_rect, unexplored_color)

	# Draw yarn trail on top
	if yarn_trail_ref:
		var points = yarn_trail_ref.get_points()
		if points.size() >= 2:
			# Convert world positions to minimap positions
			var scaled_points: PackedVector2Array = PackedVector2Array()
			for point in points:
				# world_pos / world_tile_size * minimap_tile_size
				scaled_points.append(point / world_tile_size * minimap_tile_size)

			# Draw glow around yarn
			for i in range(0, scaled_points.size(), 3):
				draw_circle(scaled_points[i], 6.0, Color(1.0, 0.8, 0.3, 0.4))

			draw_polyline(scaled_points, yarn_color, yarn_width, true)


func _is_tile_revealed(world_pos: Vector2) -> bool:
	if fog_of_war_ref:
		return fog_of_war_ref.is_position_revealed(world_pos)
	return false


func _is_tile_currently_visible(world_pos: Vector2, player_world_pos: Vector2, yarn_points: Array[Vector2]) -> bool:
	# Check if near player
	if player_world_pos != Vector2.ZERO:
		if world_pos.distance_to(player_world_pos) < player_visible_radius:
			return true

	# Check if near yarn trail
	for i in range(yarn_points.size() - 1):
		var dist = _distance_to_line_segment(world_pos, yarn_points[i], yarn_points[i + 1])
		if dist < yarn_visible_radius:
			return true

	# Check last yarn point
	if yarn_points.size() > 0:
		if world_pos.distance_to(yarn_points[yarn_points.size() - 1]) < yarn_visible_radius:
			return true

	return false


func _distance_to_line_segment(point: Vector2, seg_start: Vector2, seg_end: Vector2) -> float:
	var line_vec = seg_end - seg_start
	var line_length = line_vec.length()

	if line_length < 0.1:
		return point.distance_to(seg_start)

	var line_dir = line_vec / line_length
	var to_point = point - seg_start
	var t = clampf(to_point.dot(line_dir) / line_length, 0.0, 1.0)
	var closest = seg_start + line_dir * (t * line_length)

	return point.distance_to(closest)
