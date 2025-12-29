extends Node2D
class_name FogOfWar

# References (set from main.gd)
var player: Player
var yarn_trail: YarnTrail

# Fog settings
@export var fog_color: Color = Color(0.0, 0.0, 0.05, 0.92)
@export var revealed_color: Color = Color(0.0, 0.0, 0.05, 0.5)
@export var flashlight_range: float = 280.0
@export var flashlight_angle: float = 50.0
@export var yarn_glow_radius: float = 120.0
@export var ambient_radius: float = 80.0  # Small area around player always visible

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

	# Reveal cells near yarn
	if yarn_trail:
		var points = yarn_trail.get_points()
		# Only check every few points for performance
		for i in range(0, points.size(), 3):
			_reveal_circle(points[i], yarn_glow_radius * 0.7)


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
