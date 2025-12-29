extends Node2D
class_name MinimapYarnDrawer

var minimap: Minimap
var maze_ref: MazeGen
var yarn_trail_ref: YarnTrail

# Colors
var fog_color: Color = Color(0.08, 0.08, 0.1, 1.0)
var wall_color: Color = Color(0.25, 0.2, 0.18, 1.0)
var lit_hallway_color: Color = Color(0.5, 0.45, 0.35, 1.0)
var yarn_color: Color = Color(1.0, 0.7, 0.2, 1.0)
var yarn_color_broken: Color = Color(0.4, 0.3, 0.2, 0.5)
var yarn_width: float = 4.0
var glow_radius: float = 80.0


func _ready() -> void:
	minimap = get_parent().get_parent() as Minimap


func _draw() -> void:
	if not minimap:
		return

	var tile_size = 16.0

	# Draw background
	var bg_size = 2000.0
	draw_rect(Rect2(-bg_size, -bg_size, bg_size * 2, bg_size * 2), fog_color)

	# Get references from minimap if not set directly
	if not maze_ref and minimap.maze_ref:
		maze_ref = minimap.maze_ref
	if not yarn_trail_ref and minimap.yarn_trail_ref:
		yarn_trail_ref = minimap.yarn_trail_ref

	# Draw maze walls
	if maze_ref:
		for wall_pos in maze_ref.all_wall_locs:
			draw_rect(Rect2(wall_pos.x * tile_size, wall_pos.y * tile_size, tile_size, tile_size), wall_color)

	# Draw yarn trail
	if yarn_trail_ref:
		var points = yarn_trail_ref.get_points()
		if points.size() >= 2:
			var scaled_points: PackedVector2Array = PackedVector2Array()
			for point in points:
				scaled_points.append(point / 3.0)

			# Draw glow around yarn
			for i in range(0, scaled_points.size(), 4):
				draw_circle(scaled_points[i], 25.0, Color(1.0, 0.8, 0.3, 0.3))

			draw_polyline(scaled_points, yarn_color, yarn_width, true)

	# Also try getting yarn from players
	for player in minimap.players:
		if is_instance_valid(player):
			var yarn_trail = player.get_yarn_trail()
			if yarn_trail and yarn_trail != yarn_trail_ref:
				var points = yarn_trail.get_points()
				if points.size() >= 2:
					var scaled_points: PackedVector2Array = PackedVector2Array()
					for point in points:
						scaled_points.append(point / 3.0)
					draw_polyline(scaled_points, yarn_color, yarn_width, true)
