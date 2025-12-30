extends Node2D
class_name BoonManager

# Spawn configuration - adjust these values as needed
@export_group("Spawn Settings")
@export var min_spawns: int = 50
@export var max_spawns: int = 80
@export var min_distance_from_player_spawn: float = 20.0  # Don't spawn too close to start

@export_group("Boon Chances (weights)")
@export var speed_boost_weight: float = 1.0
@export var damage_boost_weight: float = 1.0
@export var hp_boost_weight: float = 1.0
@export var dash_cooldown_weight: float = 0.6

@export_group("Item Chances (weights)")
@export var sword_weight: float = 1
@export var lantern_weight: float = 1
@export var torch_weight: float = 1
@export var yarn_weight: float = 1.0

@export_group("Yarn Settings")
@export var yarn_amount_min: float = 100.0
@export var yarn_amount_max: float = 500.0

@export_group("Lantern Settings")
@export var lantern_radius_min: float = 100.0
@export var lantern_radius_max: float = 200.0

@export_group("Tile Settings")
@export var base_tile_size: float = 160.0
@export var world_scale: float = 0.8

# Scene references
const BoonPickupScene = preload("res://scenes/boon_pickup.tscn")
const WorldItemScene = preload("res://scenes/world_item.tscn")

# Spawn type enum
enum SpawnType { BOON_SPEED, BOON_DAMAGE, BOON_HP, BOON_DASH, ITEM_SWORD, ITEM_LANTERN, ITEM_TORCH, ITEM_YARN }

# References
var maze_ref: MazeGen
var player_spawn_pos: Vector2 = Vector2.ZERO

# Tracking
var spawned_boons: Array[BoonPickup] = []
var spawned_items: Array[WorldItem] = []
var valid_spawn_positions: Array[Vector2] = []


func setup(maze: MazeGen, player_start: Vector2 = Vector2.ZERO) -> void:
	maze_ref = maze
	player_spawn_pos = player_start
	_calculate_valid_positions()
	_spawn_all()


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


func _spawn_all() -> void:
	if valid_spawn_positions.is_empty():
		push_warning("BoonManager: No valid spawn positions!")
		return

	# Determine how many things to spawn
	var spawn_count = randi_range(min_spawns, max_spawns)
	spawn_count = min(spawn_count, valid_spawn_positions.size())

	# Shuffle positions for random selection
	var positions_copy = valid_spawn_positions.duplicate()
	positions_copy.shuffle()

	var boon_count = 0
	var item_count = 0

	for i in range(spawn_count):
		var pos = positions_copy[i]
		var spawn_type = _get_random_spawn_type()

		match spawn_type:
			SpawnType.BOON_SPEED:
				_spawn_boon_at(pos, Boon.BoonType.SPEED_BOOST)
				boon_count += 1
			SpawnType.BOON_DAMAGE:
				_spawn_boon_at(pos, Boon.BoonType.DAMAGE_BOOST)
				boon_count += 1
			SpawnType.BOON_HP:
				_spawn_boon_at(pos, Boon.BoonType.HP_BOOST)
				boon_count += 1
			SpawnType.BOON_DASH:
				_spawn_boon_at(pos, Boon.BoonType.DASH_COOLDOWN)
				boon_count += 1
			SpawnType.ITEM_SWORD:
				_spawn_item_at(pos, Item.ItemType.SWORD)
				item_count += 1
			SpawnType.ITEM_LANTERN:
				_spawn_item_at(pos, Item.ItemType.LANTERN)
				item_count += 1
			SpawnType.ITEM_TORCH:
				_spawn_item_at(pos, Item.ItemType.TORCH)
				item_count += 1
			SpawnType.ITEM_YARN:
				_spawn_item_at(pos, Item.ItemType.YARN)
				item_count += 1

	print("BoonManager: Spawned ", boon_count, " boons and ", item_count, " items")


func _get_random_spawn_type() -> SpawnType:
	# Calculate total weight of all spawns
	var total_weight = (
		speed_boost_weight + damage_boost_weight + hp_boost_weight + dash_cooldown_weight +
		sword_weight + lantern_weight + torch_weight + yarn_weight
	)
	var roll = randf() * total_weight

	var cumulative = 0.0

	# Boons
	cumulative += speed_boost_weight
	if roll < cumulative:
		return SpawnType.BOON_SPEED

	cumulative += damage_boost_weight
	if roll < cumulative:
		return SpawnType.BOON_DAMAGE

	cumulative += hp_boost_weight
	if roll < cumulative:
		return SpawnType.BOON_HP

	cumulative += dash_cooldown_weight
	if roll < cumulative:
		return SpawnType.BOON_DASH

	# Items
	cumulative += sword_weight
	if roll < cumulative:
		return SpawnType.ITEM_SWORD

	cumulative += lantern_weight
	if roll < cumulative:
		return SpawnType.ITEM_LANTERN

	cumulative += torch_weight
	if roll < cumulative:
		return SpawnType.ITEM_TORCH

	return SpawnType.ITEM_YARN


func _spawn_boon_at(pos: Vector2, type: Boon.BoonType) -> BoonPickup:
	var boon_instance = BoonPickupScene.instantiate() as BoonPickup
	boon_instance.boon_type = type
	boon_instance.position = pos
	add_child(boon_instance)
	spawned_boons.append(boon_instance)

	# Connect collection signal
	boon_instance.boon_collected.connect(_on_boon_collected)

	return boon_instance


func _spawn_item_at(pos: Vector2, type: Item.ItemType) -> WorldItem:
	var item_instance = WorldItemScene.instantiate() as WorldItem
	item_instance.item_type = type

	# Set specific properties based on type
	if type == Item.ItemType.YARN:
		item_instance.yarn_amount = randf_range(yarn_amount_min, yarn_amount_max)
	elif type == Item.ItemType.LANTERN:
		item_instance.lantern_radius = randf_range(lantern_radius_min, lantern_radius_max)

	item_instance.position = pos
	add_child(item_instance)
	spawned_items.append(item_instance)

	return item_instance


func _on_boon_collected(_boon: Boon, _collector: Player) -> void:
	# Boon is already applied by BoonPickup.pickup()
	# This callback is for tracking/logging purposes
	pass


# Manual spawn functions for testing or scripted events
func spawn_specific_boon(pos: Vector2, type: Boon.BoonType) -> BoonPickup:
	return _spawn_boon_at(pos, type)


func spawn_specific_item(pos: Vector2, type: Item.ItemType) -> WorldItem:
	return _spawn_item_at(pos, type)


# Clear all spawns
func clear_all() -> void:
	for boon in spawned_boons:
		if is_instance_valid(boon):
			boon.queue_free()
	spawned_boons.clear()

	for item in spawned_items:
		if is_instance_valid(item):
			item.queue_free()
	spawned_items.clear()


# Get counts
func get_remaining_boon_count() -> int:
	var count = 0
	for boon in spawned_boons:
		if is_instance_valid(boon):
			count += 1
	return count


func get_remaining_item_count() -> int:
	var count = 0
	for item in spawned_items:
		if is_instance_valid(item):
			count += 1
	return count
