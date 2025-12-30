extends CharacterBody2D
class_name Enemy

@export var speed := 120.0
@export var roam_radius := 150.0  # how far roaming can go
@export var pause_time := 1.0
@export var stuck_time := 10
@export var stuck_threshold := 2.0
@export var vision_radius := 200.0  # how far this minion can see (for fog of war)

@export var max_health := 100
var health := max_health
@onready var health_bar := $HealthBar
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var attack_radius := 80.0
@export var dash_prep_time := 0.5
@export var dash_speed := 400.0
@export var dash_distance := 200.0

var dash_state := "idle"        # "idle", "prep", "dashing", "post_pause"
var dash_timer := 0.0
var dash_target := Vector2.ZERO
var last_direction := Vector2.DOWN  # Track last movement direction for idle animation

@export var chase_speed := 150.0  # faster than normal speed
var players := []
var current_target_player: Node2D = null
var player_last_seen: Vector2 = Vector2.ZERO
var chasing_player := false
var investigating_last_seen := false

@export var overlap_distance := 50

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
				# Show dash direction during prep (wind up animation)
				var prep_dir = (dash_target - global_position).normalized()
				_update_animation(prep_dir, true)
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
					_update_animation(Vector2.ZERO, false)
				else:
					velocity = dir.normalized() * dash_speed
					_update_animation(dir, true)
					# Move and check collision
					var collision = move_and_collide(velocity * delta)

					if collision:
						dash_state = "post_pause"
						dash_timer = dash_prep_time
						velocity = Vector2.ZERO
						_update_animation(Vector2.ZERO, false)
						if collision.get_collider() is Player:
							_resolve_player_overlap()
							collision.get_collider().take_damage(20)
							if(collision.get_collider().get_hp() <= 0):
								players.erase(collision.get_collider())
				return
			"post_pause":
				dash_timer -= delta
				velocity = Vector2.ZERO
				_update_animation(Vector2.ZERO, false)
				move_and_slide()
				_resolve_player_overlap()
				if dash_timer <= 0:
					dash_state = "idle"
				return

	
	if chasing_player and current_target_player:
		# Chase the player
		agent.target_position = current_target_player.global_position
		var chase_dir = (agent.target_position - global_position).normalized()
		velocity = chase_dir * chase_speed
		_update_animation(chase_dir, false)
		move_and_slide()
		_resolve_enemy_overlap()
		return
	elif investigating_last_seen:
		# Go to last seen position
		agent.target_position = player_last_seen
		if agent.is_navigation_finished():
			# Arrived → resume normal behavior
			investigating_last_seen = false
			chasing_player = false
			_update_animation(Vector2.ZERO, false)
		else:
			var next_pos = agent.get_next_path_position()
			var investigate_dir = (next_pos - global_position).normalized()
			velocity = investigate_dir * speed
			_update_animation(investigate_dir, false)
			move_and_slide()
			_resolve_enemy_overlap()
		return
	
	# Pause timer for roaming
	if wait_timer > 0:
		wait_timer -= delta
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO, false)
		move_and_slide()
		_resolve_enemy_overlap()
		return

	# Stuck detection (only after first target)
	if target_locked:
		if global_position.distance_to(last_position) < stuck_threshold:
			stuck_timer += delta
			if stuck_timer >= stuck_time:
				print("giving up")
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
		_update_animation(Vector2.ZERO, false)
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
	_update_animation(dir, false)
	move_and_slide()
	_resolve_enemy_overlap()

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
		var min_distance = overlap_distance  # adjust based on your enemy+player size
		if distance < min_distance and distance > 0:
			var push_dir = overlap.normalized()
			# Smoothly interpolate away from player
			global_position = global_position.lerp(global_position + push_dir * (min_distance - distance), 0.5)
			
func _resolve_enemy_overlap():
	for e in get_parent().get_children():
		if e == self or not e is CharacterBody2D:
			continue
		var overlap = global_position - e.global_position
		var distance = overlap.length()
		var min_distance = overlap_distance  # adjust based on enemy size	
		if distance < min_distance and distance > 0:
			var push_dir = overlap.normalized()
			# Smoothly move away from other enemies
			global_position = global_position.lerp(global_position + push_dir * (min_distance - distance), 0.2)


func take_damage(amount: int) -> void:
	health -= amount
	health = max(health, 0)

	# Visual feedback
	modulate = Color(1.5, 0.5, 0.5, 1.0)
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	if health <= 0:
		_die()

func _die() -> void:
	print("Enemy died!")
	queue_free()


# Animation handling based on movement direction
func _update_animation(direction: Vector2, is_dashing: bool = false) -> void:
	if not animated_sprite:
		return

	# Skip if no movement
	if direction.length() < 0.1:
		animated_sprite.stop()
		return

	# Store last direction for reference
	last_direction = direction.normalized()

	# Determine animation name based on direction quadrant
	var anim_prefix = "Dash_" if is_dashing else "Walk_"
	var anim_suffix: String

	# Use the larger component to determine primary direction
	if abs(direction.y) >= abs(direction.x):
		# Vertical movement dominant
		if direction.y > 0:
			anim_suffix = "Down"
		else:
			anim_suffix = "Up"
	else:
		# Horizontal movement dominant
		if direction.x > 0:
			anim_suffix = "Right"
		else:
			anim_suffix = "Left"

	var anim_name = anim_prefix + anim_suffix

	# Only change animation if different
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)
	elif not animated_sprite.is_playing():
		animated_sprite.play(anim_name)
