extends TileMapLayer
class_name MazeGen

var starting_pos = Vector2i()
const main_layer = 0
const terrain_set = 0
const wall_id = 0
const floor_id = 1
#const normal_wall_atlas_coords = Vector2i(10, 1)
#const walkable_atlas_coords = Vector2i(9, 4)
#const SOURCE_ID = 0
#var spot_to_letter = {}
#var spot_to_label = {}
#var current_letter_num = 65

@export var y_dim = 35
@export var x_dim = 35
@export var starting_coords = Vector2i(0, 0)
@export var usbroom_y = 10
@export var usbroom_x = 10
@export var usb_density = 4

var adj4 = [
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]
var all_wall_locs: Array[Vector2i] = []
var all_floor_locs: Array[Vector2i] = []
var usb_room_walls: Array[int] = []
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	place_border(-1, -1, x_dim, y_dim)
	generate_usb_room_coords()
	print(usb_room_walls)
	print(usb_room_walls[0])
	place_border(usb_room_walls[0],usb_room_walls[1],usb_room_walls[2],usb_room_walls[3])
	dfs(starting_coords)
	open_box_doors(-1,-1,x_dim,y_dim)
	open_box_doors(0,0,x_dim-1,y_dim-1)
	open_box_doors(usb_room_walls[0],usb_room_walls[1],usb_room_walls[2],usb_room_walls[3])
	place_floor_border(-2,-2, x_dim+1,y_dim+1)
	place_all_walls()
	place_all_floors()
	

func place_border(x_min, y_min, x_max, y_max):
	for x in range(x_min, x_max + 1):
		place_wall(Vector2i(x, y_min))
		place_wall(Vector2i(x, y_max))
	for y in range(y_min+1, y_max):
		place_wall(Vector2i(x_min, y))
		place_wall(Vector2i(x_max, y))
		
func place_floor_border(x_min, y_min, x_max, y_max):
	for x in range(x_min, x_max + 1):
		place_floor(Vector2i(x, y_min))
		place_floor(Vector2i(x, y_max))
	for y in range(y_min+1, y_max):
		place_floor(Vector2i(x_min, y))
		place_floor(Vector2i(x_max, y))
		

func generate_usb_room_coords():
	var usbcenter_x = int(clamp(randfn(x_dim/2, x_dim/usb_density), 0 + usbroom_x/2, x_dim - usbroom_x/2 - 1))
	var usbcenter_y = int(clamp(randfn(y_dim/2, y_dim/usb_density), 0 + usbroom_y/2, y_dim - usbroom_y/2 - 1))
	print(usbcenter_x)
	print(usbcenter_y)
	usb_room_walls.append(int(usbcenter_x - usbroom_x/2) | 1)
	usb_room_walls.append(int(usbcenter_y - usbroom_y/2) | 1)
	usb_room_walls.append(int(usbcenter_x + usbroom_x/2) | 1)
	usb_room_walls.append(int(usbcenter_y + usbroom_y/2) | 1)
	return
	
func open_box_doors(x_min, y_min, x_max, y_max):
	# 1. Calculate the midpoints
	# We use integer division (abs / 2) to find the center
	var center_x = (x_min + x_max) / 2
	var center_y = (y_min + y_max) / 2
	
	delete_cell_at(Vector2i(center_x, y_min))
	delete_cell_at(Vector2i(center_x, y_max))
	delete_cell_at(Vector2i(x_min, center_y))
	delete_cell_at(Vector2i(x_max, center_y))
	return

func delete_cell_at(pos: Vector2i):
	all_wall_locs.erase(pos)
	all_floor_locs.append(pos)
	
	
func place_wall(pos: Vector2i):
	all_wall_locs.append(pos)
	
func place_floor(pos: Vector2i):
	all_floor_locs.append(pos)

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
		else:
			all_floor_locs.append(current)

func place_all_walls():
	set_cells_terrain_connect(all_wall_locs, terrain_set, wall_id)
	_create_light_occluders()
	
func place_all_floors():
	print(all_floor_locs)
	set_cells_terrain_connect(all_floor_locs, terrain_set, floor_id)


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
