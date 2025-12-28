extends Node2D
class_name FogOfWar

# References (set from main.gd)
var player: Player
var yarn_trail: YarnTrail

# Components
var fog_texture: ImageTexture
var fog_image: Image

# Fog settings
@export var fog_color: Color = Color(0.0, 0.0, 0.02, 0.97)
@export var revealed_color: Color = Color(0.0, 0.0, 0.02, 0.6)  # Previously seen areas
@export var clear_color: Color = Color(0, 0, 0, 0)  # Currently visible

@export var flashlight_range: float = 250.0
@export var flashlight_angle: float = 45.0
@export var yarn_glow_radius: float = 100.0
@export var resolution_scale: float = 0.15  # Lower = better performance

# Fog map dimensions (will be set based on maze)
var fog_width: int = 512
var fog_height: int = 512
var world_width: float = 2048.0
var world_height: float = 2048.0

# Track revealed areas permanently
var revealed_map: Image


func _ready() -> void:
	z_index = 90  # Above game elements, below UI


func setup(maze_width: float, maze_height: float) -> void:
	world_width = maze_width
	world_height = maze_height

	# Calculate fog texture size based on resolution scale
	fog_width = maxi(int(maze_width * resolution_scale), 64)
	fog_height = maxi(int(maze_height * resolution_scale), 64)

	# Create fog image
	fog_image = Image.create(fog_width, fog_height, false, Image.FORMAT_RGBA8)
	fog_image.fill(fog_color)

	# Create revealed map (persistent memory of explored areas)
	revealed_map = Image.create(fog_width, fog_height, false, Image.FORMAT_R8)
	revealed_map.fill(Color(0, 0, 0, 1))  # All unexplored initially

	# Create texture
	fog_texture = ImageTexture.create_from_image(fog_image)


func _process(_delta: float) -> void:
	if not player or not fog_image:
		return

	_update_fog()
	queue_redraw()


func _draw() -> void:
	if not fog_texture:
		return

	# Draw fog texture scaled to world size
	var dest_rect = Rect2(0, 0, world_width, world_height)
	draw_texture_rect(fog_texture, dest_rect, false)


func _update_fog() -> void:
	# Reset fog to dark
	fog_image.fill(fog_color)

	var scale_x = float(fog_width) / world_width
	var scale_y = float(fog_height) / world_height

	# Clear areas around flashlight
	if player:
		var player_pos = player.global_position
		var look_dir = player.look_direction
		_clear_flashlight_cone(player_pos, look_dir, scale_x, scale_y)

	# Clear areas around yarn
	if yarn_trail:
		for yarn_pos in yarn_trail.get_points():
			_clear_circle(yarn_pos, yarn_glow_radius, scale_x, scale_y)

	# Apply revealed areas (show as slightly less dark)
	_apply_revealed_areas()

	# Update texture
	fog_texture.update(fog_image)


func _clear_flashlight_cone(origin: Vector2, direction: Vector2, scale_x: float, scale_y: float) -> void:
	var angle = direction.angle()
	var half_angle = deg_to_rad(flashlight_angle)

	var fog_origin = Vector2(origin.x * scale_x, origin.y * scale_y)
	var fog_range = flashlight_range * max(scale_x, scale_y)

	# Clear pixels in the cone
	var check_radius = int(fog_range) + 1
	var origin_x = int(fog_origin.x)
	var origin_y = int(fog_origin.y)

	for dy in range(-check_radius, check_radius + 1):
		for dx in range(-check_radius, check_radius + 1):
			var px = origin_x + dx
			var py = origin_y + dy

			if px < 0 or px >= fog_width or py < 0 or py >= fog_height:
				continue

			var pixel_pos = Vector2(px, py)
			var to_pixel = pixel_pos - fog_origin
			var dist = to_pixel.length()

			if dist > fog_range:
				continue

			var pixel_angle = to_pixel.angle()
			var angle_diff = abs(angle_difference(pixel_angle, angle))

			if angle_diff < half_angle:
				# Calculate alpha based on distance (soft edge)
				var alpha = 0.0
				var edge_dist = fog_range * 0.15
				if dist > fog_range - edge_dist:
					alpha = (dist - (fog_range - edge_dist)) / edge_dist * fog_color.a

				fog_image.set_pixel(px, py, Color(fog_color.r, fog_color.g, fog_color.b, alpha))

				# Mark as revealed
				revealed_map.set_pixel(px, py, Color(1, 1, 1, 1))


func _clear_circle(center: Vector2, radius: float, scale_x: float, scale_y: float) -> void:
	var fog_center = Vector2(center.x * scale_x, center.y * scale_y)
	var fog_radius = radius * max(scale_x, scale_y)

	var check_radius = int(fog_radius) + 1
	var center_x = int(fog_center.x)
	var center_y = int(fog_center.y)

	for dy in range(-check_radius, check_radius + 1):
		for dx in range(-check_radius, check_radius + 1):
			var px = center_x + dx
			var py = center_y + dy

			if px < 0 or px >= fog_width or py < 0 or py >= fog_height:
				continue

			var dist = Vector2(dx, dy).length()

			if dist <= fog_radius:
				# Soft edge
				var alpha = 0.0
				var edge_dist = fog_radius * 0.2
				if dist > fog_radius - edge_dist:
					alpha = (dist - (fog_radius - edge_dist)) / edge_dist * fog_color.a

				fog_image.set_pixel(px, py, Color(fog_color.r, fog_color.g, fog_color.b, alpha))

				# Mark as revealed
				revealed_map.set_pixel(px, py, Color(1, 1, 1, 1))


func _apply_revealed_areas() -> void:
	# Make previously revealed areas slightly visible (fog of war memory)
	for y in range(fog_height):
		for x in range(fog_width):
			var revealed = revealed_map.get_pixel(x, y).r > 0.5
			var current = fog_image.get_pixel(x, y)

			if revealed and current.a > revealed_color.a:
				# This area was revealed before but not currently visible
				fog_image.set_pixel(x, y, revealed_color)
