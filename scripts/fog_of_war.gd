extends Node2D
class_name FogOfWar

# References (set from main.gd)
var player: Player
var yarn_trail: YarnTrail

# Fog settings
<<<<<<< HEAD
@export var fog_color: Color = Color(0.0, 0.0, 0.02, 0.97)
@export var revealed_color: Color = Color(0.0, 0.0, 0.0, 1.0)  # Previously seen areas
@export var clear_color: Color = Color(0.0, 0.0, 0.0, 0.49)  # Currently visible

@export var flashlight_range: float = 100.0
@export var flashlight_angle: float = 30.0
@export var yarn_glow_radius: float = 50.0
@export var resolution_scale: float = 0.15  # Lower = better performance
=======
@export var fog_color: Color = Color(0.0, 0.0, 0.05, 0.92)
@export var revealed_color: Color = Color(0.0, 0.0, 0.05, 0.5)
@export var flashlight_range: float = 280.0
@export var flashlight_angle: float = 50.0
@export var yarn_glow_radius: float = 120.0
@export var ambient_radius: float = 80.0  # Small area around player always visible
>>>>>>> 91596098a7820fa085a0384810b45488f66b2748

# Revealed cells for fog of war memory
var revealed_cells: Dictionary = {}
var cell_size: float = 48.0


func _ready() -> void:
	z_index = 90


func setup(maze_width: float, maze_height: float) -> void:
	# Just store dimensions, we'll draw directly
	pass


func _process(_delta: float) -> void:
	if player:
		_update_revealed_cells()
	queue_redraw()


func _update_revealed_cells() -> void:
	if not player:
		return

	var player_pos = player.global_position
	var look_dir = player.look_direction

	# Reveal cells in flashlight cone
	_reveal_cone(player_pos, look_dir, flashlight_range, flashlight_angle)

	# Reveal cells around player (ambient)
	_reveal_circle(player_pos, ambient_radius)

<<<<<<< HEAD
	# Clear areas around flashlight (follows mouse cursor)
	if player:
		var player_pos = player.global_position
		var mouse_pos = player.get_global_mouse_position()
		var look_dir = (mouse_pos - player_pos).normalized()
		if look_dir.length() < 0.1:
			look_dir = Vector2.RIGHT
		_clear_flashlight_cone(player_pos, look_dir, scale_x, scale_y)

	# Clear areas along the entire yarn LINE (not just at points)
	if yarn_trail:
		var points = yarn_trail.get_points()
		if points.size() > 0:
			# Clear along each line segment
			for i in range(points.size() - 1):
				_clear_line_segment(points[i], points[i + 1], yarn_glow_radius, scale_x, scale_y)
			# Also clear at the last point
			if points.size() > 0:
				_clear_circle(points[points.size() - 1], yarn_glow_radius, scale_x, scale_y)

	# Apply revealed areas (show as slightly less dark)
	_apply_revealed_areas()

	# Update texture
	fog_texture.update(fog_image)
=======
	# Reveal cells near yarn
	if yarn_trail:
		var points = yarn_trail.get_points()
		# Only check every few points for performance
		for i in range(0, points.size(), 3):
			_reveal_circle(points[i], yarn_glow_radius * 0.7)
>>>>>>> 91596098a7820fa085a0384810b45488f66b2748


func _reveal_cone(origin: Vector2, direction: Vector2, range_dist: float, half_angle_deg: float) -> void:
	var angle = direction.angle()
	var half_angle = deg_to_rad(half_angle_deg)
	var check_dist = int(range_dist / cell_size) + 1

	var origin_cell = Vector2i(origin / cell_size)

	for dy in range(-check_dist, check_dist + 1):
		for dx in range(-check_dist, check_dist + 1):
			var cell = origin_cell + Vector2i(dx, dy)
			var cell_center = Vector2(cell) * cell_size + Vector2(cell_size / 2, cell_size / 2)
			var to_cell = cell_center - origin
			var dist = to_cell.length()

			if dist > range_dist:
				continue

			var cell_angle = to_cell.angle()
			var angle_diff = abs(angle_difference(cell_angle, angle))

			if angle_diff < half_angle:
				revealed_cells[cell] = true


func _reveal_circle(center: Vector2, radius: float) -> void:
	var check_dist = int(radius / cell_size) + 1
	var center_cell = Vector2i(center / cell_size)

	for dy in range(-check_dist, check_dist + 1):
		for dx in range(-check_dist, check_dist + 1):
			var cell = center_cell + Vector2i(dx, dy)
			var cell_center = Vector2(cell) * cell_size + Vector2(cell_size / 2, cell_size / 2)

			if center.distance_to(cell_center) < radius:
				revealed_cells[cell] = true

<<<<<<< HEAD
func _clear_line_segment(start: Vector2, end: Vector2, radius: float, scale_x: float, scale_y: float) -> void:
	# Clear fog along the entire line segment with smooth edges
	var fog_start = Vector2(start.x * scale_x, start.y * scale_y)
	var fog_end = Vector2(end.x * scale_x, end.y * scale_y)
	var fog_radius = radius * max(scale_x, scale_y)

	var line_vec = fog_end - fog_start
	var line_length = line_vec.length()

	if line_length < 0.1:
		return

	var line_dir = line_vec / line_length

	# Calculate bounding box for the line segment
	var min_x = int(min(fog_start.x, fog_end.x) - fog_radius) - 1
	var max_x = int(max(fog_start.x, fog_end.x) + fog_radius) + 1
	var min_y = int(min(fog_start.y, fog_end.y) - fog_radius) - 1
	var max_y = int(max(fog_start.y, fog_end.y) + fog_radius) + 1

	min_x = clampi(min_x, 0, fog_width - 1)
	max_x = clampi(max_x, 0, fog_width - 1)
	min_y = clampi(min_y, 0, fog_height - 1)
	max_y = clampi(max_y, 0, fog_height - 1)

	for py in range(min_y, max_y + 1):
		for px in range(min_x, max_x + 1):
			var pixel_pos = Vector2(px, py)

			# Calculate distance from pixel to line segment
			var to_pixel = pixel_pos - fog_start
			var t = clampf(to_pixel.dot(line_dir) / line_length, 0.0, 1.0)
			var closest_point = fog_start + line_dir * (t * line_length)
			var dist = pixel_pos.distance_to(closest_point)

			if dist <= fog_radius:
				# Smooth falloff at edges
				var alpha = 0.0
				var edge_dist = fog_radius * 0.3
				if dist > fog_radius - edge_dist:
					alpha = (dist - (fog_radius - edge_dist)) / edge_dist * fog_color.a

				var current = fog_image.get_pixel(px, py)
				if alpha < current.a:
					fog_image.set_pixel(px, py, Color(fog_color.r, fog_color.g, fog_color.b, alpha))

				# Mark as revealed
				revealed_map.set_pixel(px, py, Color(1, 1, 1, 1))


func _clear_circle(center: Vector2, radius: float, scale_x: float, scale_y: float) -> void:
	var fog_center = Vector2(center.x * scale_x, center.y * scale_y)
	var fog_radius = radius * max(scale_x, scale_y)
=======
>>>>>>> 91596098a7820fa085a0384810b45488f66b2748

func _draw() -> void:
	if not player:
		return

	var camera = player.get_node_or_null("Camera2D") as Camera2D
	if not camera:
		return

	# Get visible area with padding
	var viewport_size = get_viewport_rect().size
	var zoom = camera.zoom
	var visible_size = viewport_size / zoom
	var camera_pos = camera.global_position
	var top_left = camera_pos - visible_size / 2 - Vector2(cell_size, cell_size)
	var bottom_right = camera_pos + visible_size / 2 + Vector2(cell_size, cell_size)

	var player_pos = player.global_position
	var look_dir = player.look_direction

	# Draw fog for each cell in view
	var start_cell = Vector2i(top_left / cell_size)
	var end_cell = Vector2i(bottom_right / cell_size)

	for cy in range(start_cell.y, end_cell.y + 1):
		for cx in range(start_cell.x, end_cell.x + 1):
			var cell = Vector2i(cx, cy)
			var cell_pos = Vector2(cell) * cell_size
			var cell_center = cell_pos + Vector2(cell_size / 2, cell_size / 2)

			# Check current visibility
			var is_visible = _is_currently_visible(cell_center, player_pos, look_dir)
			var was_revealed = revealed_cells.has(cell)

			if is_visible:
				# Fully visible - no fog
				continue
			elif was_revealed:
				# Previously seen - dim fog
				draw_rect(Rect2(cell_pos, Vector2(cell_size, cell_size)), revealed_color)
			else:
				# Never seen - full fog
				draw_rect(Rect2(cell_pos, Vector2(cell_size, cell_size)), fog_color)


func _is_currently_visible(pos: Vector2, player_pos: Vector2, look_dir: Vector2) -> bool:
	var to_pos = pos - player_pos
	var dist = to_pos.length()

	# Ambient visibility around player
	if dist < ambient_radius:
		return true

	# Flashlight cone
	if dist < flashlight_range:
		var angle = look_dir.angle()
		var pos_angle = to_pos.angle()
		var angle_diff = abs(angle_difference(pos_angle, angle))

		if angle_diff < deg_to_rad(flashlight_angle):
			return true

	# Yarn visibility
	if yarn_trail:
		var points = yarn_trail.get_points()
		for i in range(0, points.size(), 2):
			if pos.distance_to(points[i]) < yarn_glow_radius:
				return true

	return false
