extends Node2D
class_name SwordSwing

# Swing parameters
var swing_range: float = 70.0  # How far the swing reaches
var swing_width: float = 20.0  # Thickness of the crescent
var swing_color: Color = Color(0.9, 0.95, 1.0, 0.9)
var trail_color: Color = Color(0.845, 0.897, 1.0, 0.4)

# Swing state
var is_swinging: bool = false
var swing_start_angle: float = 0.0
var swing_end_angle: float = 0.0
var swing_progress: float = 0.0  # 0 to 1
var swing_duration: float = 0.15  # How fast the swing animates
var current_swing_angle: float = 0.0

# For mouse tracking
var is_tracking: bool = false
var track_start_angle: float = 0.0
var min_swing_arc: float = 0.3  # Minimum radians to trigger swing

# change damage
var damage: int = 25
var has_hit: Dictionary = {}  # Track what we've already hit this swing

# Signals
signal swing_hit(target: Node2D, damage: int)
signal swing_started()
signal swing_finished()


func _ready() -> void:
	z_index = 10


func _process(delta: float) -> void:
	if is_swinging:
		swing_progress += delta / swing_duration
		if swing_progress >= 1.0:
			swing_progress = 1.0
			is_swinging = false
			has_hit.clear()
			swing_finished.emit()

		# Calculate current angle based on progress
		current_swing_angle = lerp_angle(swing_start_angle, swing_end_angle, swing_progress)
		queue_redraw()

	if is_tracking:
		queue_redraw()


func start_tracking(mouse_pos: Vector2) -> void:
	# Start tracking mouse movement for swing
	var to_mouse = mouse_pos - global_position
	track_start_angle = to_mouse.angle()
	is_tracking = true


func update_tracking(mouse_pos: Vector2) -> void:
	if not is_tracking:
		return
	# Just update the visual preview
	queue_redraw()


func finish_tracking(mouse_pos: Vector2) -> void:
	if not is_tracking:
		return

	is_tracking = false

	var to_mouse = mouse_pos - global_position
	var end_angle = to_mouse.angle()

	# Calculate the arc swept
	var arc = angle_difference(track_start_angle, end_angle)

	# Only swing if we moved enough
	if abs(arc) >= min_swing_arc:
		_perform_swing(track_start_angle, end_angle)

	queue_redraw()


func _perform_swing(start_angle: float, end_angle: float) -> void:
	swing_start_angle = start_angle
	swing_end_angle = end_angle
	swing_progress = 0.0
	is_swinging = true
	has_hit.clear()
	current_swing_angle = start_angle
	swing_started.emit()

	# Check for hits along the entire arc
	_check_hits_in_arc(start_angle, end_angle)


func _check_hits_in_arc(start_angle: float, end_angle: float) -> void:
	# Get all bodies in range
	var space_state = get_world_2d().direct_space_state

	# Check multiple points along the arc
	var arc_length = angle_difference(start_angle, end_angle)
	var steps = int(abs(arc_length) / 0.2) + 1  # Check every ~11 degrees

	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var check_angle = lerp_angle(start_angle, end_angle, t)

		# Create a point at this angle
		var check_pos = global_position + Vector2.from_angle(check_angle) * (swing_range * 0.7)

		# Shape query at this position
		var query = PhysicsShapeQueryParameters2D.new()
		var circle = CircleShape2D.new()
		circle.radius = swing_width
		query.shape = circle
		query.transform = Transform2D(0, check_pos)
		query.collision_mask = 4  # Enemy layer

		var results = space_state.intersect_shape(query, 10)
		for result in results:
			var collider = result.collider
			if collider and not has_hit.has(collider.get_instance_id()):
				has_hit[collider.get_instance_id()] = true
				swing_hit.emit(collider, damage)


func _draw() -> void:
	if is_swinging:
		_draw_swing_arc()
	elif is_tracking:
		_draw_tracking_preview()


func _draw_swing_arc() -> void:
	# Draw the crescent slash effect
	var arc_start = swing_start_angle
	var arc_end = current_swing_angle

	# Draw trail (the swept area)
	_draw_crescent(arc_start, arc_end, swing_range, swing_width, trail_color)

	# Draw the leading edge (bright part)
	var edge_start = current_swing_angle - 0.1
	var edge_end = current_swing_angle + 0.1
	_draw_crescent(edge_start, edge_end, swing_range, swing_width * 1.5, swing_color)


func _draw_tracking_preview() -> void:
	# Draw a subtle preview of where the swing will go
	var mouse_pos = get_global_mouse_position()
	var to_mouse = mouse_pos - global_position
	var current_angle = to_mouse.angle()

	# Draw arc from start to current mouse position
	var preview_color = Color(1.0, 1.0, 1.0, 0.2)
	_draw_crescent(track_start_angle, current_angle, swing_range, swing_width * 0.5, preview_color)

	# Draw start indicator
	var start_pos = Vector2.from_angle(track_start_angle) * swing_range
	draw_circle(start_pos, 5.0, Color(1.0, 1.0, 1.0, 0.3))


func _draw_crescent(start_angle: float, end_angle: float, radius: float, width: float, color: Color) -> void:
	# Draw a crescent/arc shape
	var arc_diff = angle_difference(start_angle, end_angle)
	if abs(arc_diff) < 0.01:
		return

	var steps = int(abs(arc_diff) / 0.1) + 2
	steps = max(steps, 3)

	var outer_points: PackedVector2Array = []
	var inner_points: PackedVector2Array = []

	var inner_radius = radius - width
	var outer_radius = radius

	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var angle = lerp_angle(start_angle, end_angle, t)

		outer_points.append(Vector2.from_angle(angle) * outer_radius)
		inner_points.append(Vector2.from_angle(angle) * inner_radius)

	# Create polygon from outer and inner arcs
	var polygon: PackedVector2Array = []
	for point in outer_points:
		polygon.append(point)

	# Reverse inner points to close the shape
	inner_points.reverse()
	for point in inner_points:
		polygon.append(point)

	if polygon.size() >= 3:
		draw_polygon(polygon, [color])

		# Draw outline for extra effect
		var outline_color = Color(color.r, color.g, color.b, color.a * 0.5)
		draw_polyline(outer_points, outline_color, 2.0, true)


func set_weapon_stats(weapon_damage: int, weapon_range: float) -> void:
	damage = weapon_damage
	swing_range = weapon_range
