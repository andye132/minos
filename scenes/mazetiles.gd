extends TileMapLayer
class_name MazeGen

var starting_pos = Vector2i()
const main_layer = 0
const terrain_set = 0
const terrain_id = 0
#const normal_wall_atlas_coords = Vector2i(10, 1)
#const walkable_atlas_coords = Vector2i(9, 4)
#const SOURCE_ID = 0
#var spot_to_letter = {}
#var spot_to_label = {}
#var current_letter_num = 65

@export var y_dim = 35
@export var x_dim = 35
@export var starting_coords = Vector2i(0, 0)
var adj4 = [
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]
var all_wall_locs: Array[Vector2i] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	place_border()
	dfs(starting_coords)
	place_all_walls()
	

func place_border():
	for y in range(-1, y_dim):
		place_wall(Vector2i(-1, y))
	for x in range(-1, x_dim):
		place_wall(Vector2i(x, -1))
	for y in range(-1, y_dim + 1):
		place_wall(Vector2i(x_dim, y))
	for x in range(-1, x_dim + 1):
		place_wall(Vector2i(x, y_dim))


func delete_cell_at(pos: Vector2i):
	all_wall_locs.erase(pos)
	
	
func place_wall(pos: Vector2i):
	all_wall_locs.append(pos)
	


func will_be_converted_to_wall(spot: Vector2i):
	return (spot.x % 2 == 1 and spot.y % 2 == 1)
	
	
func is_wall(pos):
	return all_wall_locs.has(pos)


func can_move_to(current: Vector2i):
	return (
			current.x >= 0 and current.y >= 0 and\
			current.x < x_dim and current.y < y_dim and\
			not is_wall(current)
	)

func dfs(start: Vector2i):
	var fringe: Array[Vector2i] = [start]
	var seen = {}

	while fringe.size() > 0:
		var current: Vector2i = fringe.pop_back()

		# 1. Standard DFS check: Skip if already visited or invalid
		if current in seen or not can_move_to(current):
			continue
			
		seen[current] = true

		# 2. Grid-based wall logic (from your original code)
		if current.x % 2 == 1 and current.y % 2 == 1:
			place_wall(current)
			continue
		
		var found_new_path = false
		adj4.shuffle()
		
		for pos in adj4:
			var new_pos = current + pos
			
			if new_pos not in seen and can_move_to(new_pos):
				# Loop logic
				var chance_of_no_loop = 1
				
				if will_be_converted_to_wall(new_pos) and chance_of_no_loop == 1:
					place_wall(new_pos)
				else:
					found_new_path = true
					fringe.append(new_pos)
					
		# 3. Dead-end logic: If no neighbors were added, turn current into wall
		if not found_new_path:
			place_wall(current)

func place_all_walls():
	print(all_wall_locs)
	set_cells_terrain_connect(all_wall_locs, terrain_set, terrain_id)
	_create_light_occluders()


func _create_light_occluders() -> void:
	# Create a single LightOccluder2D with all wall polygons
	var occluder_node = LightOccluder2D.new()
	occluder_node.name = "WallOccluders"

	var occluder = OccluderPolygon2D.new()
	occluder.cull_mode = OccluderPolygon2D.CULL_DISABLED

	# Get tile size (16x16 scaled by 3)
	var tile_size = 16.0  # Base tile size before scaling
	var half_tile = tile_size / 2.0

	# Build polygon points for each wall tile
	# We'll create individual occluders for each wall for proper shadowing
	for wall_pos in all_wall_locs:
		var wall_occluder = LightOccluder2D.new()
		var wall_polygon = OccluderPolygon2D.new()
		wall_polygon.cull_mode = OccluderPolygon2D.CULL_DISABLED

		# Calculate world position (tile coords * tile_size, centered)
		var world_pos = Vector2(wall_pos.x * tile_size + half_tile, wall_pos.y * tile_size + half_tile)

		# Create a square polygon for this wall tile
		wall_polygon.polygon = PackedVector2Array([
			world_pos + Vector2(-half_tile, -half_tile),
			world_pos + Vector2(half_tile, -half_tile),
			world_pos + Vector2(half_tile, half_tile),
			world_pos + Vector2(-half_tile, half_tile)
		])

		wall_occluder.occluder = wall_polygon
		add_child(wall_occluder)
