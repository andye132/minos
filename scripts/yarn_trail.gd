extends Node2D
class_name YarnTrail

# Yarn properties
@export var max_yarn_length: float = 500.0  # Maximum length in yarn units
@export var point_spacing: float = 15.0  # Distance between yarn points in pixels
@export var light_spacing: int = 1  # Place light every N points (1 = every point)
@export var pixels_per_unit: float = 1.0  # How many pixels = 1 yarn unit

# Current state
var yarn_points: Array[Vector2] = []
var current_length: float = 0.0  # In yarn units
var is_continuous: bool = true  # Yarn lights up only if continuous
var is_active: bool = true  # Yarn is being laid down

# Light management
var yarn_lights: Array[PointLight2D] = []
var radial_texture: GradientTexture2D

# Visual
@onready var line: Line2D = $Line2D

signal yarn_length_changed(current: float, max_length: float)
signal yarn_broken()
signal yarn_restored()


func _ready() -> void:
	_create_light_texture()
	_update_visual()


func _create_light_texture() -> void:
	radial_texture = GradientTexture2D.new()
	radial_texture.width = 128
	radial_texture.height = 128
	radial_texture.fill = GradientTexture2D.FILL_RADIAL
	radial_texture.fill_from = Vector2(0.5, 0.5)
	radial_texture.fill_to = Vector2(0.5, 0.0)
	
	var gradient = Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(1, 1, 1, 0))
	radial_texture.gradient = gradient


func add_point(pos: Vector2, available_yarn: float) -> float:
	# Returns how much yarn was consumed (in yarn units)
	if not is_active:
		return 0.0
	
	if yarn_points.size() == 0:
		yarn_points.append(pos)
		_update_visual()
		return 0.0
	
	var last_point = yarn_points[yarn_points.size() - 1]
	var distance_pixels = pos.distance_to(last_point)
	
	if distance_pixels < point_spacing:
		return 0.0
	
	# Convert pixel distance to yarn units
	var yarn_needed = distance_pixels / pixels_per_unit
	
	# Check if we have enough yarn in inventory to LAY DOWN more
	if available_yarn >= yarn_needed:
		# We have yarn to lay down - trail grows
		yarn_points.append(pos)
		current_length += yarn_needed
		
		# Add light at intervals
		if yarn_points.size() % light_spacing == 0:
			_add_yarn_light(pos)
		
		# Trim excess if over max length
		_trim_to_max_length()
		
		_update_visual()
		yarn_length_changed.emit(current_length, max_yarn_length)
		return yarn_needed
	else:
		# No yarn in inventory - DRAG the trail (constant length)
		# Add new point at front, remove equal length from back
		_drag_trail(pos)
		return 0.0  # No yarn consumed from inventory when dragging


func _drag_trail(new_pos: Vector2) -> void:
	# When out of inventory yarn, we drag the trail behind us
	# The trail stays the SAME length - we just move it
	
	if yarn_points.size() < 2:
		yarn_points.append(new_pos)
		_update_visual()
		return
	
	# Calculate how much we're adding
	var last_point = yarn_points[yarn_points.size() - 1]
	var add_distance = new_pos.distance_to(last_point) / pixels_per_unit
	
	# Add the new point
	yarn_points.append(new_pos)
	current_length += add_distance
	
	# Remove from the START until we're back to original length
	# (or slightly under due to discrete points)
	var target_length = max_yarn_length  # Trail should be at max when dragging
	
	while current_length > target_length and yarn_points.size() > 2:
		var first = yarn_points[0]
		var second = yarn_points[1]
		var segment_length = first.distance_to(second) / pixels_per_unit
		
		yarn_points.remove_at(0)
		current_length -= segment_length
		
		# Remove associated light
		if yarn_lights.size() > 0:
			var light = yarn_lights[0]
			yarn_lights.remove_at(0)
			light.queue_free()
	
	# Add light at intervals
	if yarn_points.size() % light_spacing == 0:
		_add_yarn_light(new_pos)
	
	_update_visual()
	yarn_length_changed.emit(current_length, max_yarn_length)


func _trim_to_max_length() -> void:
	while current_length > max_yarn_length and yarn_points.size() > 2:
		var first = yarn_points[0]
		var second = yarn_points[1]
		var segment_pixels = first.distance_to(second)
		var segment_yarn = segment_pixels / pixels_per_unit
		
		yarn_points.remove_at(0)
		current_length -= segment_yarn
		
		# Remove old lights
		if yarn_lights.size() > 0:
			var light = yarn_lights[0]
			yarn_lights.remove_at(0)
			light.queue_free()


func _add_yarn_light(pos: Vector2) -> void:
	if not is_continuous:
		return

	var light = PointLight2D.new()
	light.color = Color(1.0, 0.8, 0.4, 1.0)
	light.energy = 1.5  # Strong enough to be visible in darkness
	light.texture_scale = 2.0  # Larger glow radius
	light.texture = radial_texture
	light.global_position = pos
	light.z_index = 10

	# Enable shadows so light doesn't pass through walls
	light.shadow_enabled = true
	light.shadow_color = Color(0, 0, 0, 0.8)
	light.shadow_filter = 1  # PCF5 filter for smoother shadows

	add_child(light)
	yarn_lights.append(light)


func _update_visual() -> void:
	if not line:
		return
	
	line.clear_points()
	
	if not is_continuous:
		line.default_color = Color(0.4, 0.3, 0.2, 0.5)  # Dim when broken
	else:
		line.default_color = Color(1.0, 0.7, 0.2, 0.9)  # Bright when continuous
	
	# Since YarnTrail is top-level at origin, global coords work directly
	for point in yarn_points:
		line.add_point(point)


func break_yarn() -> void:
	is_continuous = false
	
	# Turn off all lights
	for light in yarn_lights:
		light.energy = 0.0
	
	_update_visual()
	yarn_broken.emit()


func restore_yarn() -> void:
	is_continuous = true

	# Turn lights back on
	for light in yarn_lights:
		light.energy = 1.5

	_update_visual()
	yarn_restored.emit()


func extend_max_length(amount: float) -> void:
	max_yarn_length += amount
	yarn_length_changed.emit(current_length, max_yarn_length)


func get_points() -> Array[Vector2]:
	return yarn_points


func get_length() -> float:
	return current_length
