extends Node2D
class_name FogOfWar

# References (set from main.gd)
var player: Player
var yarn_trail: YarnTrail

# Fog settings (scaled for 160x160 tiles at 0.8 scale = 128px per tile)
@export var fog_color: Color = Color(0.0, 0.0, 0.0, 0.95)
@export var revealed_color: Color = Color(0.0, 0.0, 0.0, 0.702)
@export var flashlight_range: float = 120.0  # ~6 tiles
@export var flashlight_angle: float = 35.0  # degrees
@export var yarn_glow_radius: float = 30.0  # ~1 tile
@export var ambient_radius: float = 30.0  # ~1.5 tiles

# Revealed cells for fog memory
var revealed_cells: Dictionary = {}
var cell_size: float = 20.0  # ~0.5 tile per cell for tracking revealed areas

# Gradient textures (created once, reused)
var ambient_gradient: GradientTexture2D
var cone_gradient: GradientTexture2D


func _ready() -> void:
	z_index = 90
	_create_gradient_textures()


func _create_gradient_textures() -> void:
	# Create radial gradient for ambient light
	ambient_gradient = GradientTexture2D.new()
	ambient_gradient.gradient = Gradient.new()
	ambient_gradient.gradient.colors = [Color(1, 1, 1, 1), Color(1.0, 1.0, 1.0, 0.0)]
	ambient_gradient.gradient.offsets = [0.0, 1.0]
	ambient_gradient.fill = GradientTexture2D.FILL_RADIAL
	ambient_gradient.fill_from = Vector2(0.5, 0.5)
	ambient_gradient.fill_to = Vector2(1.0, 0.5)
	ambient_gradient.width = 128
	ambient_gradient.height = 128


func setup(_maze_width: float, _maze_height: float) -> void:
	pass


func _process(_delta: float) -> void:
	if player:
		_update_revealed_cells()
	queue_redraw()


func _update_revealed_cells() -> void:
	if not player:
		return

	var player_pos = player.global_position
	var mouse_pos = player.get_global_mouse_position()
	var look_dir = (mouse_pos - player_pos).normalized()
	if look_dir.length() < 0.1:
		look_dir = player.look_direction

	# Reveal in flashlight cone
	_reveal_cone(player_pos, look_dir, flashlight_range, flashlight_angle)

	# Reveal around player
	_reveal_circle(player_pos, ambient_radius)

	# Reveal along yarn
	if yarn_trail:
		var points = yarn_trail.get_points()
		for i in range(points.size() - 1):
			_reveal_line_segment(points[i], points[i + 1], yarn_glow_radius)
		if points.size() > 0:
			_reveal_circle(points[points.size() - 1], yarn_glow_radius)


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


func _reveal_line_segment(start: Vector2, end: Vector2, radius: float) -> void:
	var line_vec = end - start
	var line_length = line_vec.length()
	if line_length < 0.1:
		return

	var line_dir = line_vec / line_length
	var min_pos = Vector2(min(start.x, end.x) - radius, min(start.y, end.y) - radius)
	var max_pos = Vector2(max(start.x, end.x) + radius, max(start.y, end.y) + radius)

	var start_cell = Vector2i(min_pos / cell_size)
	var end_cell = Vector2i(max_pos / cell_size)

	for cy in range(start_cell.y, end_cell.y + 1):
		for cx in range(start_cell.x, end_cell.x + 1):
			var cell = Vector2i(cx, cy)
			var cell_center = Vector2(cell) * cell_size + Vector2(cell_size / 2, cell_size / 2)

			var to_cell = cell_center - start
			var t = clampf(to_cell.dot(line_dir) / line_length, 0.0, 1.0)
			var closest_point = start + line_dir * (t * line_length)
			var dist = cell_center.distance_to(closest_point)

			if dist < radius:
				revealed_cells[cell] = true


func _draw() -> void:
	if not player:
		return

	var camera = player.get_node_or_null("Camera2D") as Camera2D
	if not camera:
		return

	var viewport_size = get_viewport_rect().size
	var zoom = camera.zoom
	var visible_size = viewport_size / zoom
	var camera_pos = camera.global_position
	var top_left = camera_pos - visible_size / 2 - Vector2(cell_size * 2, cell_size * 2)
	var bottom_right = camera_pos + visible_size / 2 + Vector2(cell_size * 2, cell_size * 2)

	var player_pos = player.global_position
	var mouse_pos = player.get_global_mouse_position()
	var look_dir = (mouse_pos - player_pos).normalized()
	if look_dir.length() < 0.1:
		look_dir = player.look_direction

	# STEP 1: Draw fog for unrevealed and revealed-but-not-visible cells
	var start_cell = Vector2i(top_left / cell_size)
	var end_cell = Vector2i(bottom_right / cell_size)

	for cy in range(start_cell.y, end_cell.y + 1):
		for cx in range(start_cell.x, end_cell.x + 1):
			var cell = Vector2i(cx, cy)
			var cell_pos = Vector2(cell) * cell_size
			var cell_center = cell_pos + Vector2(cell_size / 2, cell_size / 2)

			# Skip cells that are currently visible (we'll handle those with gradients)
			if _is_in_visible_area(cell_center, player_pos, look_dir):
				continue

			var was_revealed = revealed_cells.has(cell)
			if was_revealed:
				draw_rect(Rect2(cell_pos, Vector2(cell_size, cell_size)), revealed_color)
			else:
				draw_rect(Rect2(cell_pos, Vector2(cell_size, cell_size)), fog_color)

	# Visible areas are already skipped above, so game shows through
	# No extra drawing needed - the fog cells handle it


func _is_in_visible_area(pos: Vector2, player_pos: Vector2, look_dir: Vector2) -> bool:
	var to_pos = pos - player_pos
	var dist = to_pos.length()

	# Near player (ambient)
	if dist < ambient_radius * 1.5:
		return true

	# In flashlight cone
	if dist < flashlight_range * 1.2:
		var angle = look_dir.angle()
		var pos_angle = to_pos.angle()
		var angle_diff = abs(angle_difference(pos_angle, angle))
		if angle_diff < deg_to_rad(flashlight_angle * 1.2):
			return true

	# Near yarn
	if yarn_trail:
		var points = yarn_trail.get_points()
		for i in range(points.size() - 1):
			var dist_to_yarn = _distance_to_segment(pos, points[i], points[i + 1])
			if dist_to_yarn < yarn_glow_radius * 1.3:
				return true

	return false


func _draw_ambient_light(player_pos: Vector2) -> void:
	if not ambient_gradient:
		return

	var size = ambient_radius * 2.5
	var rect = Rect2(player_pos - Vector2(size/2, size/2), Vector2(size, size))
	draw_texture_rect(ambient_gradient, rect, false, Color(0, 0, 0, 0.9))


func _draw_flashlight_cone(player_pos: Vector2, look_dir: Vector2) -> void:
	# Draw cone as a polygon with gradient alpha
	var cone_angle = deg_to_rad(flashlight_angle)
	var base_angle = look_dir.angle()

	# Create cone polygon points
	var segments = 12
	var points: PackedVector2Array = []
	var colors: PackedColorArray = []

	# Center point (player position) - fully lit
	points.append(player_pos)
	colors.append(Color(0, 0, 0, 0))  # Transparent at center

	# Arc points
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var angle = base_angle - cone_angle + (cone_angle * 2.0 * t)
		var point = player_pos + Vector2.from_angle(angle) * flashlight_range
		points.append(point)
		# Fade out at edges of cone
		var edge_factor = abs(t - 0.5) * 2.0  # 0 at center, 1 at edges
		var alpha = 0.3 + edge_factor * 0.6  # More transparent at center
		colors.append(Color(0, 0, 0, alpha))

	if points.size() >= 3:
		draw_polygon(points, colors)


func _draw_yarn_glow() -> void:
	if not yarn_trail:
		return

	var points = yarn_trail.get_points()
	if points.size() < 2:
		return

	# Draw glow circles along yarn (sampled, not every point)
	var sample_dist = yarn_glow_radius * 0.8
	var accumulated_dist = 0.0

	for i in range(points.size() - 1):
		var segment_start = points[i]
		var segment_end = points[i + 1]
		var segment_vec = segment_end - segment_start
		var segment_length = segment_vec.length()

		if segment_length < 0.1:
			continue

		var segment_dir = segment_vec / segment_length
		var pos_along = 0.0

		while pos_along < segment_length:
			if accumulated_dist >= sample_dist:
				var glow_pos = segment_start + segment_dir * pos_along
				_draw_glow_circle(glow_pos, yarn_glow_radius)
				accumulated_dist = 0.0

			var step = min(sample_dist - accumulated_dist, segment_length - pos_along)
			pos_along += step
			accumulated_dist += step

	# Always draw at the end
	if points.size() > 0:
		_draw_glow_circle(points[points.size() - 1], yarn_glow_radius)


func _draw_glow_circle(pos: Vector2, radius: float) -> void:
	# Draw concentric circles with decreasing alpha for soft glow
	var steps = 4
	for i in range(steps, 0, -1):
		var t = float(i) / float(steps)
		var r = radius * t
		var alpha = (1.0 - t) * 0.4
		draw_circle(pos, r, Color(0, 0, 0, alpha))


func _distance_to_segment(point: Vector2, seg_start: Vector2, seg_end: Vector2) -> float:
	var line_vec = seg_end - seg_start
	var line_length = line_vec.length()

	if line_length < 0.1:
		return point.distance_to(seg_start)

	var line_dir = line_vec / line_length
	var to_point = point - seg_start
	var t = clampf(to_point.dot(line_dir) / line_length, 0.0, 1.0)
	var closest = seg_start + line_dir * (t * line_length)

	return point.distance_to(closest)


# ===== PUBLIC API FOR MINIMAP =====

func is_position_revealed(world_pos: Vector2) -> bool:
	var cell = Vector2i(world_pos / cell_size)
	return revealed_cells.has(cell)


func is_position_visible(world_pos: Vector2) -> bool:
	if not player:
		return false

	var player_pos = player.global_position
	var mouse_pos = player.get_global_mouse_position()
	var look_dir = (mouse_pos - player_pos).normalized()
	if look_dir.length() < 0.1:
		look_dir = player.look_direction

	return _is_in_visible_area(world_pos, player_pos, look_dir)


func get_revealed_cells() -> Dictionary:
	return revealed_cells
