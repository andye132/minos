extends SubViewportContainer
class_name Minimap

const SIZE_1_PLAYER: Vector2 = Vector2(150, 150)
const SIZE_2_PLAYER: Vector2 = Vector2(180, 180)
const SIZE_3_PLAYER: Vector2 = Vector2(210, 210)
const SIZE_4_PLAYER: Vector2 = Vector2(250, 250)

@export var maze_bounds: Vector2 = Vector2(800, 600)
@export var margin: Vector2 = Vector2(20, 20)

@export var player_count: int = 1:
	set(value):
		player_count = clampi(value, 1, 4)
		_update_minimap_size()

@onready var viewport: SubViewport = $SubViewport
@onready var minimap_camera: Camera2D = $SubViewport/MinimapCamera
@onready var yarn_drawer: Node2D = $SubViewport/YarnDrawer
@onready var player_markers: Node2D = $SubViewport/PlayerMarkers

var players: Array[Player] = []
var current_size: Vector2 = SIZE_1_PLAYER


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
	position = Vector2(screen_size.x - current_size.x - margin.x, margin.y)


func _update_minimap_size() -> void:
	match player_count:
		1: current_size = SIZE_1_PLAYER
		2: current_size = SIZE_2_PLAYER
		3: current_size = SIZE_3_PLAYER
		_: current_size = SIZE_4_PLAYER
	
	custom_minimum_size = current_size
	size = current_size
	
	if viewport:
		viewport.size = Vector2i(current_size)
	
	if minimap_camera:
		var zoom_x = current_size.x / maze_bounds.x
		var zoom_y = current_size.y / maze_bounds.y
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
		player_count = players.size()


func remove_player(player: Player) -> void:
	players.erase(player)
	player_count = max(1, players.size())


func get_current_size() -> Vector2:
	return current_size
