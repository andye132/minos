extends CharacterBody2D

@export var speed := 120.0
@export var roam_radius := 150.0  # how far roaming can go
@export var pause_time := 1.0
@export var stuck_time := 5.0
@export var stuck_threshold := 2.0
@export var vision_radius := 200.0  # how far this minion can see (for fog of war)

@export var max_health := 100
var health := max_health
@onready var health_bar := $HealthBar

@export var attack_radius := 80.0
@export var dash_prep_time := 0.5
@export var dash_speed := 400.0
@export var dash_distance := 200.0

var dash_state := "idle"        # "idle", "prep", "dashing", "post_pause"
var dash_timer := 0.0
var dash_target := Vector2.ZERO

@export var chase_speed := 150.0  # faster than normal speed
var players := []
var current_target_player: Node2D = null
var player_last_seen: Vector2 = Vector2.ZERO
var chasing_player := false
var investigating_last_seen := false

var current_scene
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
		
	health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	current_scene = get_tree().current_scene
	
	_update_players()

func _physics_process(delta):
	_update_player_detection()
	
	if current_target_player != null:
		var dist_to_player = global_position.distance_to(current_target_player.global_position)
		
		# Start prep if close and idle
		if dash_state == "idle" and dist_to_player <= attack_radius:
			dash_state = "prep"
			dash_timer = dash_prep_time
			# Lock dash target as a fixed position at a set distance toward the player
			var dir = (current_target_player.global_position - global_position).normalized()
			dash_target = global_position + dir * dash_distance  # dash_distance can be set as you like
			velocity = Vector2.ZERO
			move_and_slide()
			return
		
		# Handle dash phases
		match dash_state:
			"prep":
				dash_timer -= delta
				velocity = Vector2.ZERO
				move_and_slide()
				if dash_timer <= 0:
					dash_state = "dashing"
				return
			"dashing":
				var dir = dash_target - global_position
				var dist_left = dir.length()
				if dist_left < 1:
					# Reached target → post-pause
					dash_state = "post_pause"
					dash_timer = dash_prep_time
					velocity = Vector2.ZERO
				else:
					velocity = dir.normalized() * dash_speed
					# Move and check collision
					var collision = move_and_collide(velocity * delta)
					
					print (collision)
					if collision:
						# Hit something → post-pause immediately
						_resolve_player_overlap()
						dash_state = "post_pause"
						dash_timer = dash_prep_time
						velocity = Vector2.ZERO
				return
			"post_pause":
				dash_timer -= delta
				velocity = Vector2.ZERO
				move_and_slide()
				_resolve_player_overlap()
				if dash_timer <= 0:
					dash_state = "idle"
				return

	
	if chasing_player and current_target_player:
		# Chase the player
		agent.target_position = current_target_player.global_position
		velocity = (agent.target_position - global_position).normalized() * chase_speed
		move_and_slide()
		return
	elif investigating_last_seen:
		# Go to last seen position
		agent.target_position = player_last_seen
		if agent.is_navigation_finished():
			# Arrived → resume normal behavior
			investigating_last_seen = false
			chasing_player = false
		else:
			var next_pos = agent.get_next_path_position()
			velocity = (next_pos - global_position).normalized() * speed
			move_and_slide()
		return
	
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
	
func _update_player_detection():
	var closest_player: Node2D = null
	var closest_distance := vision_radius + 1
	for p in players:
		var dist = global_position.distance_to(p.global_position)
		if dist <= vision_radius and _has_line_of_sight_to(p):
			if dist < closest_distance:
				closest_distance = dist
				closest_player = p

	if closest_player != null:
		# Player visible → chase
		chasing_player = true
		investigating_last_seen = false
		current_target_player = closest_player
		player_last_seen = closest_player.global_position
	else:
		# No visible player → investigate last seen if was chasing
		if chasing_player:
			chasing_player = false
			investigating_last_seen = true

# LOS check using Godot 4 PhysicsRayQueryParameters2D
func _has_line_of_sight_to(target: Node2D) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.exclude = [self]
	query.collision_mask = 2  # walls layer
	var result = space_state.intersect_ray(query)
	return result.keys().size() == 0
	
func _update_players():
	players = []
	for child in current_scene.get_children():
		if child.name == "Player":  # or `if child is Player`
			players.append(child)
			
func _resolve_player_overlap():
	for p in players:
		var overlap = global_position - p.global_position
		var distance = overlap.length()
		var min_distance = 50  # adjust based on your enemy+player size
		if distance < min_distance and distance > 0:
			var push_dir = overlap.normalized()
			# Smoothly interpolate away from player
			global_position = global_position.lerp(global_position + push_dir * (min_distance - distance), 0.5)

func take_damage(amount: int):
	health -= amount
	health = max(health, 0)

	if health_bar:
		health_bar.value = health

	if health <= 0:
		die()

func die():
	queue_free()
