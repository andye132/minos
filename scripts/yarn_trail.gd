extends Node2D
class_name YarnTrail

# Yarn properties
<<<<<<< HEAD
@export var max_yarn_length: float = 5000.0  # Maximum length in yarn units
@export var point_spacing: float = 50.0  # dist between yarn points in pixels - 50 is chopp;y
=======
@export var max_yarn_length: float = 500.0  # Maximum length in yarn units
@export var point_spacing: float = 15.0  # Distance between yarn points in pixels
>>>>>>> 91596098a7820fa085a0384810b45488f66b2748
@export var pixels_per_unit: float = 1.0  # How many pixels = 1 yarn unit

# Current state
var yarn_points: Array[Vector2] = []
var current_length: float = 0.0  # In yarn units
var is_continuous: bool = true  # Yarn lights up only if continuous
var is_active: bool = true  # Yarn is being laid down

<<<<<<< HEAD
=======
# Single light that follows the yarn end
var yarn_light: PointLight2D
var radial_texture: GradientTexture2D

>>>>>>> 91596098a7820fa085a0384810b45488f66b2748
# Visual
@onready var line: Line2D = $Line2D

signal yarn_length_changed(current: float, max_length: float)
signal yarn_broken()
signal yarn_restored()


func _ready() -> void:
<<<<<<< HEAD
	_setup_line()
	_update_visual()


func _setup_line() -> void:
	line.width = 5.0
	line.default_color = Color(1.0, 0.8, 0.3, 1.0)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
=======
	_create_light_texture()
	_create_yarn_light()
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
>>>>>>> 91596098a7820fa085a0384810b45488f66b2748


func _create_yarn_light() -> void:
	# Single light at the yarn start point (anchor)
	yarn_light = PointLight2D.new()
	yarn_light.color = Color(1.0, 0.8, 0.4, 1.0)
	yarn_light.energy = 0.6
	yarn_light.texture_scale = 1.0
	yarn_light.texture = radial_texture
	yarn_light.shadow_enabled = true
	yarn_light.shadow_color = Color(0, 0, 0, 0.7)
	add_child(yarn_light)


func add_point(pos: Vector2, available_yarn: float) -> float:
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

<<<<<<< HEAD
	var yarn_needed = distance_pixels / pixels_per_unit

=======
	# Convert pixel distance to yarn units
	var yarn_needed = distance_pixels / pixels_per_unit

	# Check if we have enough yarn in inventory to LAY DOWN more
>>>>>>> 91596098a7820fa085a0384810b45488f66b2748
	if available_yarn >= yarn_needed:
		yarn_points.append(pos)
		current_length += yarn_needed
<<<<<<< HEAD
		_trim_to_max_length()
=======

		# Trim excess if over max length
		_trim_to_max_length()

>>>>>>> 91596098a7820fa085a0384810b45488f66b2748
		_update_visual()
		yarn_length_changed.emit(current_length, max_yarn_length)
		return yarn_needed
	else:
<<<<<<< HEAD
=======
		# No yarn in inventory - DRAG the trail (constant length)
>>>>>>> 91596098a7820fa085a0384810b45488f66b2748
		_drag_trail(pos)
		return 0.0


func _drag_trail(new_pos: Vector2) -> void:
<<<<<<< HEAD
=======
	# When out of inventory yarn, we drag the trail behind us
	# The trail stays the SAME length - we just move it

>>>>>>> 91596098a7820fa085a0384810b45488f66b2748
	if yarn_points.size() < 2:
		yarn_points.append(new_pos)
		_update_visual()
		return

<<<<<<< HEAD
	var last_point = yarn_points[yarn_points.size() - 1]
	var add_distance = new_pos.distance_to(last_point) / pixels_per_unit

	yarn_points.append(new_pos)
	current_length += add_distance

=======
	# Calculate how much we're adding
	var last_point = yarn_points[yarn_points.size() - 1]
	var add_distance = new_pos.distance_to(last_point) / pixels_per_unit

	# Add the new point
	yarn_points.append(new_pos)
	current_length += add_distance

	# Remove from the START until we're back to original length
>>>>>>> 91596098a7820fa085a0384810b45488f66b2748
	var target_length = max_yarn_length

	while current_length > target_length and yarn_points.size() > 2:
		var first = yarn_points[0]
		var second = yarn_points[1]
		var segment_length = first.distance_to(second) / pixels_per_unit
<<<<<<< HEAD
=======

>>>>>>> 91596098a7820fa085a0384810b45488f66b2748
		yarn_points.remove_at(0)
		current_length -= segment_length

	_update_visual()
	yarn_length_changed.emit(current_length, max_yarn_length)


func _trim_to_max_length() -> void:
	while current_length > max_yarn_length and yarn_points.size() > 2:
		var first = yarn_points[0]
		var second = yarn_points[1]
<<<<<<< HEAD
		var segment_yarn = first.distance_to(second) / pixels_per_unit
=======
		var segment_pixels = first.distance_to(second)
		var segment_yarn = segment_pixels / pixels_per_unit

>>>>>>> 91596098a7820fa085a0384810b45488f66b2748
		yarn_points.remove_at(0)
		current_length -= segment_yarn


func _update_visual() -> void:
	if not line:
		return

	line.clear_points()

	if not is_continuous:
		line.default_color = Color(0.4, 0.3, 0.2, 0.5)
	else:
<<<<<<< HEAD
		line.default_color = Color(1.0, 0.8, 0.3, 1.0)

=======
		line.default_color = Color(1.0, 0.7, 0.2, 0.9)  # Bright when continuous

	# Since YarnTrail is top-level at origin, global coords work directly
>>>>>>> 91596098a7820fa085a0384810b45488f66b2748
	for point in yarn_points:
		line.add_point(point)

	# Update light position to yarn start (anchor point)
	if yarn_light and yarn_points.size() > 0:
		yarn_light.global_position = yarn_points[0]
		yarn_light.visible = is_continuous


func break_yarn() -> void:
	is_continuous = false
<<<<<<< HEAD
=======

	if yarn_light:
		yarn_light.energy = 0.0

>>>>>>> 91596098a7820fa085a0384810b45488f66b2748
	_update_visual()
	yarn_broken.emit()


func restore_yarn() -> void:
	is_continuous = true
<<<<<<< HEAD
=======

	if yarn_light:
		yarn_light.energy = 0.6

>>>>>>> 91596098a7820fa085a0384810b45488f66b2748
	_update_visual()
	yarn_restored.emit()


func extend_max_length(amount: float) -> void:
	max_yarn_length += amount
	yarn_length_changed.emit(current_length, max_yarn_length)


func get_points() -> Array[Vector2]:
	return yarn_points


func get_length() -> float:
	return current_length
