extends Node2D
class_name PuppeteerFogOfWar

# Reference to maze for wall detection
var maze_ref: MazeGen

# List of entities that provide vision (enemies)
var vision_providers: Array = []

# Fog settings
@export var fog_color: Color = Color(0.0, 0.0, 0.0, 0.95)
@export var revealed_color: Color = Color(0.0, 0.0, 0.0, 0.7)
@export var default_vision_radius: float = 100.0  # Default vision AMNT for minions

# Revealed cells for fog memory
var revealed_cells: Dictionary = {}
var cell_size: float = 64.0  # Cell size for tracking revealed areas

# Tile size settings (should match maze)
var base_tile_size: float = 160.0
var world_scale: float = 0.8


func _ready() -> void:
	z_index = 90


func setup(maze: MazeGen) -> void:
	maze_ref = maze


func _process(_delta: float) -> void:
	_update_revealed_cells()
	queue_redraw()


func _update_revealed_cells() -> void:
	# Reveal around each vision provider (enemy minion)
	for provider in vision_providers:
		if is_instance_valid(provider):
			var vision_radius = default_vision_radius
			if provider.has_method("get_vision_radius"):
				vision_radius = provider.get_vision_radius()
			_reveal_circle(provider.global_position, vision_radius)


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
	# Get camera for visible area calculation
	var camera = get_viewport().get_camera_2d()
	if not camera:
		print("PuppeteerFog: No camera found!")
		return

	if not maze_ref:
		print("PuppeteerFog: No maze_ref!")
		return

	var viewport_size = get_viewport_rect().size
	var zoom = camera.zoom
	var visible_size = viewport_size / zoom
	var camera_pos = camera.global_position
	var top_left = camera_pos - visible_size / 2 - Vector2(cell_size * 2, cell_size * 2)
	var bottom_right = camera_pos + visible_size / 2 + Vector2(cell_size * 2, cell_size * 2)

	# Draw fog for the entire maze area (not just visible cells)
	# This ensures fog covers the maze regardless of camera position
	var world_tile_size = base_tile_size * world_scale  # 128
	var maze_width = maze_ref.x_dim * world_tile_size
	var maze_height = maze_ref.y_dim * world_tile_size

	# Calculate cell range for entire maze
	var start_cell = Vector2i(0, 0)
	var end_cell = Vector2i(maze_width / cell_size, maze_height / cell_size)

	var drawn_count = 0
	var wall_count = 0
	var visible_count = 0

	for cy in range(start_cell.y, end_cell.y + 1):
		for cx in range(start_cell.x, end_cell.x + 1):
			var cell = Vector2i(cx, cy)
			var cell_pos = Vector2(cell) * cell_size
			var cell_center = cell_pos + Vector2(cell_size / 2, cell_size / 2)

			# Check if this cell is a wall - walls are always visible to puppeteer
			if _is_wall_at_world_pos(cell_center):
				wall_count += 1
				continue  # Don't draw fog on walls

			# Skip cells that are currently visible (within vision radius of a minion)
			if _is_in_visible_area(cell_center):
				visible_count += 1
				continue

			# Draw fog for non-visible cells
			drawn_count += 1
			var was_revealed = revealed_cells.has(cell)
			if was_revealed:
				draw_rect(Rect2(cell_pos, Vector2(cell_size, cell_size)), revealed_color)
			else:
				draw_rect(Rect2(cell_pos, Vector2(cell_size, cell_size)), fog_color)

	# Debug output (print first 5 frames then every 120 frames)
	var frame = Engine.get_frames_drawn()
	if frame < 5 or frame % 120 == 0:
		print("PuppeteerFog: drawn=", drawn_count, " walls=", wall_count, " visible=", visible_count, " cells_total=", (end_cell.x + 1) * (end_cell.y + 1))


func _is_wall_at_world_pos(world_pos: Vector2) -> bool:
	if not maze_ref:
		return false

	# Convert world position to tile position
	var world_tile_size = base_tile_size * world_scale  # 128
	var tile_x = int(world_pos.x / world_tile_size)
	var tile_y = int(world_pos.y / world_tile_size)

	return maze_ref.is_wall(Vector2i(tile_x, tile_y))


func _is_in_visible_area(pos: Vector2) -> bool:
	# Check if position is within vision radius of any minion
	for provider in vision_providers:
		if is_instance_valid(provider):
			var vision_radius = default_vision_radius
			if provider.has_method("get_vision_radius"):
				vision_radius = provider.get_vision_radius()

			if pos.distance_to(provider.global_position) < vision_radius * 1.2:
				return true

	return false


# ===== PUBLIC API =====

func add_vision_provider(provider: Node2D) -> void:
	if provider not in vision_providers:
		vision_providers.append(provider)


func remove_vision_provider(provider: Node2D) -> void:
	vision_providers.erase(provider)


func is_position_revealed(world_pos: Vector2) -> bool:
	var cell = Vector2i(world_pos / cell_size)
	return revealed_cells.has(cell)


func is_position_visible(world_pos: Vector2) -> bool:
	return _is_in_visible_area(world_pos)
