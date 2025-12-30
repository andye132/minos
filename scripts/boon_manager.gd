extends Node2D
class_name BoonManager

# Spawn configuration - adjust these values as needed
@export_group("Spawn Settings")
@export var min_boons: int = 50
@export var max_boons: int = 80
@export var min_distance_from_player_spawn: float = 20.0  # Don't spawn too close to start

@export_group("Boon Chances (weights)")
@export var speed_boost_weight: float = 1.0
@export var damage_boost_weight: float = 1.0
@export var hp_boost_weight: float = 1.0
@export var dash_cooldown_weight: float = 0.5

@export_group("Tile Settings")
@export var base_tile_size: float = 160.0
@export var world_scale: float = 0.8

# Scene reference
const BoonPickupScene = preload("res://scenes/boon_pickup.tscn")

# References
var maze_ref: MazeGen
var player_spawn_pos: Vector2 = Vector2.ZERO

# Tracking
var spawned_boons: Array[BoonPickup] = []
var valid_spawn_positions: Array[Vector2] = []


func setup(maze: MazeGen, player_start: Vector2 = Vector2.ZERO) -> void:
	maze_ref = maze
	player_spawn_pos = player_start
	_calculate_valid_positions()
	_spawn_boons()


func _calculate_valid_positions() -> void:
	if not maze_ref:
		push_error("BoonManager: No maze reference!")
		return

	valid_spawn_positions.clear()
	var world_tile_size = base_tile_size * world_scale

	# Convert all floor locations to world positions
	for floor_tile in maze_ref.all_floor_locs:
		var world_pos = Vector2(
			floor_tile.x * world_tile_size + world_tile_size / 2,
			floor_tile.y * world_tile_size + world_tile_size / 2
		)

		# Filter out positions too close to player spawn
		if player_spawn_pos != Vector2.ZERO:
			if world_pos.distance_to(player_spawn_pos) < min_distance_from_player_spawn:
				continue

		valid_spawn_positions.append(world_pos)

	print("BoonManager: Found ", valid_spawn_positions.size(), " valid spawn positions")


func _spawn_boons() -> void:
	if valid_spawn_positions.is_empty():
		push_warning("BoonManager: No valid spawn positions!")
		return

	# Determine how many boons to spawn
	var boon_count = randi_range(min_boons, max_boons)
	boon_count = min(boon_count, valid_spawn_positions.size())

	# Shuffle positions for random selection
	var positions_copy = valid_spawn_positions.duplicate()
	positions_copy.shuffle()

	for i in range(boon_count):
		var pos = positions_copy[i]
		var boon_type = _get_random_boon_type()
		_spawn_boon_at(pos, boon_type)

	print("BoonManager: Spawned ", boon_count, " boons")


func _get_random_boon_type() -> Boon.BoonType:
	# Weighted random selection
	var total_weight = speed_boost_weight + damage_boost_weight + hp_boost_weight + dash_cooldown_weight
	var roll = randf() * total_weight

	var cumulative = 0.0
	cumulative += speed_boost_weight
	if roll < cumulative:
		return Boon.BoonType.SPEED_BOOST

	cumulative += damage_boost_weight
	if roll < cumulative:
		return Boon.BoonType.DAMAGE_BOOST

	cumulative += hp_boost_weight
	if roll < cumulative:
		return Boon.BoonType.HP_BOOST

	return Boon.BoonType.DASH_COOLDOWN


func _spawn_boon_at(pos: Vector2, type: Boon.BoonType) -> BoonPickup:
	var boon_instance = BoonPickupScene.instantiate() as BoonPickup
	boon_instance.boon_type = type
	boon_instance.position = pos
	add_child(boon_instance)
	spawned_boons.append(boon_instance)

	# Connect collection signal
	boon_instance.boon_collected.connect(_on_boon_collected)

	return boon_instance


func _on_boon_collected(boon: Boon, _collector: Player) -> void:
	# Boon is already applied by BoonPickup.pickup()
	# This callback is for tracking/logging purposes
	pass


# Manual spawn function for testing or scripted events
func spawn_specific_boon(pos: Vector2, type: Boon.BoonType) -> BoonPickup:
	return _spawn_boon_at(pos, type)


# Clear all boons
func clear_all_boons() -> void:
	for boon in spawned_boons:
		if is_instance_valid(boon):
			boon.queue_free()
	spawned_boons.clear()


# Get count of remaining boons
func get_remaining_boon_count() -> int:
	var count = 0
	for boon in spawned_boons:
		if is_instance_valid(boon):
			count += 1
	return count
