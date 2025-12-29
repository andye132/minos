extends CharacterBody2D

@export var speed := 120.0
@export var roam_radius := 150.0  # how far roaming can go
@export var pause_time := 1.0
@export var stuck_time := 5.0
@export var stuck_threshold := 2.0
@export var vision_radius := 200.0  # how far this minion can see (for fog of war)

@export var navigation_region_path: NodePath

@onready var agent := $NavigationAgent2D
@onready var nav_region := get_node_or_null(navigation_region_path) as NavigationRegion2D

var target_position: Vector2
var target_locked := false
var roaming := false
var wait_timer := 0.0

var last_position := Vector2.ZERO
var stuck_timer := 0.0

func _ready():
	last_position = global_position
	if nav_region != null and agent != null:
		agent.set_navigation_map(nav_region.get_navigation_map())

func _physics_process(delta):
	# Pause timer for roaming
	if wait_timer > 0:
		wait_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Stuck detection (only after first target)
	if target_locked:
		if global_position.distance_to(last_position) < stuck_threshold:
			stuck_timer += delta
			if stuck_timer >= stuck_time:
				roaming = true
				_pick_new_roam_target()
				stuck_timer = 0.0
		else:
			stuck_timer = 0.0
		last_position = global_position

	# Do nothing if no target and not roaming
	if not target_locked and not roaming:
		return

	# Check if path finished
	if agent.is_navigation_finished():
		if roaming:
			wait_timer = pause_time
			_pick_new_roam_target()
		elif target_locked:
			# Reached initial target → start roaming
			roaming = true
			_pick_new_roam_target()
		return

	# Move toward next path point
	var next_pos = agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	velocity = dir * speed
	move_and_slide()

# Assign first target
func set_target(pos: Vector2):
	if target_locked or pos == null:
		return
	target_position = pos
	agent.target_position = pos
	target_locked = true
	roaming = false

# Pick a new random roaming target (free roaming, no bounds)
func _pick_new_roam_target():
	if agent == null:
		return

	var offset = Vector2(randf_range(-roam_radius, roam_radius),
						 randf_range(-roam_radius, roam_radius))
	var candidate = global_position + offset

	agent.target_position = candidate
	# Optional debug: print("Roaming target:", candidate)


# Vision API for fog of war
func get_vision_radius() -> float:
	return vision_radius
