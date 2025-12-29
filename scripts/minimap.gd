extends SubViewportContainer
class_name Minimap

# Minimap display settings
@export var minimap_width: float = 280.0  # Width in pixels on screen
@export var margin: Vector2 = Vector2(20, 20)

@onready var viewport: SubViewport = $SubViewport
@onready var minimap_camera: Camera2D = $SubViewport/MinimapCamera
@onready var yarn_drawer: MinimapYarnDrawer = $SubViewport/YarnDrawer
@onready var player_markers: Node2D = $SubViewport/PlayerMarkers

var players: Array[Player] = []
var maze_bounds: Vector2 = Vector2(4480, 4480)  # Default: 35 * 160 * 0.8
var maze_ref: MazeGen
var yarn_trail_ref: YarnTrail
var fog_of_war_ref: FogOfWar
var minimap_size: Vector2 = Vector2(200, 200)
var world_scale: float = 0.8  # Maze tile scale in world
var base_tile_size: float = 160.0  # Base tile size before scaling
var minimap_tile_size: float = 16.0  # Tile size for minimap drawing


func _ready() -> void:
	_update_minimap_size()
	_position_minimap()


func _process(_delta: float) -> void:
	_position_minimap()
	_update_player_markers()

	if yarn_drawer:
		yarn_drawer.queue_redraw()


func _position_minimap() -> void:
	var screen_size = get_viewport_rect().size
	position = Vector2(screen_size.x - minimap_size.x - margin.x, margin.y)


func set_maze_bounds(bounds: Vector2) -> void:
	maze_bounds = bounds
	# Calculate minimap size to maintain aspect ratio
	# Maze is 70x35 tiles = 2:1 aspect ratio
	var aspect = bounds.x / bounds.y
	minimap_size = Vector2(minimap_width, minimap_width / aspect)
	_update_minimap_size()


func set_maze_reference(maze: MazeGen) -> void:
	maze_ref = maze
	if yarn_drawer:
		yarn_drawer.maze_ref = maze
		yarn_drawer.world_scale = world_scale
		yarn_drawer.base_tile_size = base_tile_size
		yarn_drawer.minimap_tile_size = minimap_tile_size


func set_yarn_trail(trail: YarnTrail) -> void:
	yarn_trail_ref = trail
	if yarn_drawer:
		yarn_drawer.yarn_trail_ref = trail
		yarn_drawer.world_scale = world_scale
		yarn_drawer.base_tile_size = base_tile_size
		yarn_drawer.minimap_tile_size = minimap_tile_size


func set_fog_of_war(fog: FogOfWar) -> void:
	fog_of_war_ref = fog
	if yarn_drawer:
		yarn_drawer.fog_of_war_ref = fog
		yarn_drawer.world_scale = world_scale
		yarn_drawer.base_tile_size = base_tile_size
		yarn_drawer.minimap_tile_size = minimap_tile_size


func _update_minimap_size() -> void:
	custom_minimum_size = minimap_size
	size = minimap_size

	if viewport:
		viewport.size = Vector2i(minimap_size)

	if minimap_camera:
		# The yarn drawer draws tiles at minimap_tile_size (16px each)
		# Calculate how many tiles we have and the drawable area
		var world_tile_size = base_tile_size * world_scale  # 128 pixels per tile in world
		var num_tiles_x = int(maze_bounds.x / world_tile_size)  # 35 tiles
		var num_tiles_y = int(maze_bounds.y / world_tile_size)  # 35 tiles

		var drawable_width = num_tiles_x * minimap_tile_size  # 35 * 16 = 560
		var drawable_height = num_tiles_y * minimap_tile_size  # 35 * 16 = 560

		# Calculate zoom to fit entire drawable area in minimap
		var zoom_x = minimap_size.x / drawable_width
		var zoom_y = minimap_size.y / drawable_height
		var zoom_val = min(zoom_x, zoom_y)
		minimap_camera.zoom = Vector2(zoom_val, zoom_val)
		minimap_camera.position = Vector2(drawable_width / 2, drawable_height / 2)


func _update_player_markers() -> void:
	if not player_markers:
		return

	for child in player_markers.get_children():
		child.queue_free()

	for player in players:
		if is_instance_valid(player):
			var marker = _create_player_marker(player)
			player_markers.add_child(marker)


func _create_player_marker(player: Player) -> Node2D:
	var marker = Node2D.new()
	# Convert world position to minimap position
	# World uses 160*0.8=128px tiles, minimap draws at 16px per tile
	var world_tile_size = base_tile_size * world_scale  # 128
	marker.position = player.global_position / world_tile_size * minimap_tile_size

	var circle = Polygon2D.new()
	circle.color = Color(0.3, 0.8, 1.0, 1.0)
	# Scale marker size for visibility
	var marker_size = 6.0
	circle.polygon = PackedVector2Array([
		Vector2(-marker_size, 0), Vector2(-marker_size * 0.6, -marker_size * 0.6),
		Vector2(0, -marker_size), Vector2(marker_size * 0.6, -marker_size * 0.6),
		Vector2(marker_size, 0), Vector2(marker_size * 0.6, marker_size * 0.6),
		Vector2(0, marker_size), Vector2(-marker_size * 0.6, marker_size * 0.6)
	])
	marker.add_child(circle)

	var direction = Polygon2D.new()
	direction.color = Color(1.0, 1.0, 0.5, 1.0)
	direction.polygon = PackedVector2Array([
		Vector2(marker_size, 0), Vector2(marker_size * 0.5, -marker_size * 0.5), Vector2(marker_size * 0.5, marker_size * 0.5)
	])
	direction.rotation = player.look_direction.angle()
	marker.add_child(direction)

	return marker


func add_player(player: Player) -> void:
	if player not in players:
		players.append(player)


func remove_player(player: Player) -> void:
	players.erase(player)


func get_current_size() -> Vector2:
	return minimap_size
