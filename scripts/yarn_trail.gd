extends Node2D
class_name YarnTrail

# Yarn properties
@export var max_yarn_length: float = 5000.0
@export var point_spacing: float = 15.0
@export var pixels_per_unit: float = 1.0

# Current state
var yarn_points: Array[Vector2] = []
var current_length: float = 0.0
var is_continuous: bool = true
var is_active: bool = true

# Visual
@onready var line: Line2D = $Line2D

signal yarn_length_changed(current: float, max_length: float)
signal yarn_broken()
signal yarn_restored()


func _ready() -> void:
	_setup_line()
	_update_visual()


func _setup_line() -> void:
	line.width = 5.0
	line.default_color = Color(1.0, 0.8, 0.3, 1.0)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND


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

	var yarn_needed = distance_pixels / pixels_per_unit

	if available_yarn >= yarn_needed:
		yarn_points.append(pos)
		current_length += yarn_needed
		_trim_to_max_length()
		_update_visual()
		yarn_length_changed.emit(current_length, max_yarn_length)
		return yarn_needed
	else:
		_drag_trail(pos)
		return 0.0


func _drag_trail(new_pos: Vector2) -> void:
	if yarn_points.size() < 2:
		yarn_points.append(new_pos)
		_update_visual()
		return

	var last_point = yarn_points[yarn_points.size() - 1]
	var add_distance = new_pos.distance_to(last_point) / pixels_per_unit

	yarn_points.append(new_pos)
	current_length += add_distance

	var target_length = max_yarn_length

	while current_length > target_length and yarn_points.size() > 2:
		var first = yarn_points[0]
		var second = yarn_points[1]
		var segment_length = first.distance_to(second) / pixels_per_unit
		yarn_points.remove_at(0)
		current_length -= segment_length

	_update_visual()
	yarn_length_changed.emit(current_length, max_yarn_length)


func _trim_to_max_length() -> void:
	while current_length > max_yarn_length and yarn_points.size() > 2:
		var first = yarn_points[0]
		var second = yarn_points[1]
		var segment_yarn = first.distance_to(second) / pixels_per_unit
		yarn_points.remove_at(0)
		current_length -= segment_yarn


func _update_visual() -> void:
	if not line:
		return

	line.clear_points()

	if not is_continuous:
		line.default_color = Color(0.4, 0.3, 0.2, 0.5)
	else:
		line.default_color = Color(1.0, 0.8, 0.3, 1.0)

	for point in yarn_points:
		line.add_point(point)


func break_yarn() -> void:
	is_continuous = false
	_update_visual()
	yarn_broken.emit()


func restore_yarn() -> void:
	is_continuous = true
	_update_visual()
	yarn_restored.emit()


func extend_max_length(amount: float) -> void:
	max_yarn_length += amount
	yarn_length_changed.emit(current_length, max_yarn_length)


func get_points() -> Array[Vector2]:
	return yarn_points


func get_length() -> float:
	return current_length
