extends SubViewportContainer
class_name Minimap

const MINIMAP_SIZE: Vector2 = Vector2(200, 200)  # Fixed size for minimap display

@export var margin: Vector2 = Vector2(20, 20)

@onready var viewport: SubViewport = $SubViewport
@onready var minimap_camera: Camera2D = $SubViewport/MinimapCamera
@onready var yarn_drawer: MinimapYarnDrawer = $SubViewport/YarnDrawer
@onready var player_markers: Node2D = $SubViewport/PlayerMarkers

var players: Array[Player] = []
var maze_bounds: Vector2 = Vector2(800, 600)
var maze_ref: MazeGen
var yarn_trail_ref: YarnTrail


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
	position = Vector2(screen_size.x - MINIMAP_SIZE.x - margin.x, margin.y)


func set_maze_bounds(bounds: Vector2) -> void:
	maze_bounds = bounds
	_update_minimap_size()


func set_maze_reference(maze: MazeGen) -> void:
	maze_ref = maze
	if yarn_drawer:
		yarn_drawer.maze_ref = maze


func set_yarn_trail(trail: YarnTrail) -> void:
	yarn_trail_ref = trail
	if yarn_drawer:
		yarn_drawer.yarn_trail_ref = trail


func _update_minimap_size() -> void:
	custom_minimum_size = MINIMAP_SIZE
	size = MINIMAP_SIZE

	if viewport:
		viewport.size = Vector2i(MINIMAP_SIZE)

	if minimap_camera:
		# Calculate zoom to fit entire maze in minimap
		var zoom_x = MINIMAP_SIZE.x / maze_bounds.x
		var zoom_y = MINIMAP_SIZE.y / maze_bounds.y
		var zoom_val = min(zoom_x, zoom_y)
		minimap_camera.zoom = Vector2(zoom_val, zoom_val)
		minimap_camera.position = maze_bounds / 2


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
	marker.position = player.global_position

	var circle = Polygon2D.new()
	circle.color = Color(0.3, 0.8, 1.0, 1.0)
	circle.polygon = PackedVector2Array([
		Vector2(-8, 0), Vector2(-5, -5), Vector2(0, -8), Vector2(5, -5),
		Vector2(8, 0), Vector2(5, 5), Vector2(0, 8), Vector2(-5, 5)
	])
	marker.add_child(circle)

	var direction = Polygon2D.new()
	direction.color = Color(1.0, 1.0, 0.5, 1.0)
	direction.polygon = PackedVector2Array([
		Vector2(8, 0), Vector2(4, -4), Vector2(4, 4)
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
	return MINIMAP_SIZE
