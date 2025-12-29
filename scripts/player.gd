extends CharacterBody2D
class_name Player

# Movement
@export var move_speed: float = 200.0
@export var acceleration: float = 1000.0
@export var friction: float = 1200.0

# Dash
@export var dash_speed: float = 300.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.8

# Health
@export var max_hp: int = 100
var current_hp: int = 100

# State
var is_dashing: bool = false
var can_dash: bool = true
var dash_direction: Vector2 = Vector2.ZERO
var look_direction: Vector2 = Vector2.RIGHT
var current_flashlight_angle: float = 0.0

# Yarn
@export var starting_yarn: float = 500.0
var yarn_in_inventory: float = 500.0

# Combat
var sword_swing: SwordSwing

# References
@onready var flashlight: PointLight2D = $Flashlight
@onready var ambient_light: PointLight2D = $AmbientLight
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer
@onready var pickup_area: Area2D = $PickupArea
@onready var inventory: Inventory = $Inventory
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Yarn trail - set externally from Main scene
var yarn_trail: YarnTrail

# Nearby items for pickup
var nearby_items: Array[WorldItem] = []

signal yarn_amount_changed(amount: float)
signal hp_changed(current: int, maximum: int)
signal player_died()


func _enter_tree() -> void:
	if name.is_valid_int():
		var id = name.to_int()
		set_multiplayer_authority(id)
		print("Peer ", multiplayer.get_unique_id(), " claiming authority for node ", id)
	if !is_multiplayer_authority():
		return


func _ready() -> void:
	_setup_lights()

	if is_multiplayer_authority():
		$Camera2D.make_current()
	else:
		$Camera2D.enabled = false

	# Setup inventory with starting yarn
	var yarn_item = Item.create_yarn(starting_yarn)
	inventory.add_item(yarn_item)
	inventory.select_slot(0)

	yarn_in_inventory = starting_yarn

	# Initialize HP
	current_hp = max_hp

	# Setup sword swing component
	sword_swing = SwordSwing.new()
	sword_swing.name = "SwordSwing"
	add_child(sword_swing)
	sword_swing.swing_hit.connect(_on_sword_hit)

	# Connect signals
	dash_timer.timeout.connect(_on_dash_finished)
	dash_cooldown_timer.timeout.connect(_on_dash_cooldown_finished)
	pickup_area.area_entered.connect(_on_pickup_area_entered)
	pickup_area.area_exited.connect(_on_pickup_area_exited)


func _setup_lights() -> void:
	# Disable lights - fog of war handles visibility
	flashlight.enabled = false
	ambient_light.enabled = false


func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		return

	if is_dashing:
		_process_dash()
	else:
		_process_movement(delta)

	move_and_slide()
	_update_yarn()
	_handle_input()


func _process_movement(delta: float) -> void:
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")
	input_dir = input_dir.normalized()

	if input_dir != Vector2.ZERO:
		look_direction = input_dir

	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * move_speed, acceleration * delta)
		_update_walk_animation(input_dir)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		if animated_sprite:
			animated_sprite.stop()

	if Input.is_action_just_pressed("dash") and can_dash:
		_start_dash(input_dir if input_dir != Vector2.ZERO else look_direction)


func _update_walk_animation(direction: Vector2) -> void:
	if not animated_sprite:
		return

	var anim_name: String
	# Prioritize vertical movement for diagonal input
	if abs(direction.y) >= abs(direction.x):
		if direction.y > 0:
			anim_name = "Walk_Down"
		else:
			anim_name = "Walk_Up"
	else:
		if direction.x > 0:
			anim_name = "Walk_Right"
		else:
			anim_name = "Walk_Left"

	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)
	elif not animated_sprite.is_playing():
		animated_sprite.play(anim_name)


func _handle_input() -> void:
	if Input.is_action_just_pressed("slot_1"):
		inventory.select_slot(0)
	elif Input.is_action_just_pressed("slot_2"):
		inventory.select_slot(1)
	elif Input.is_action_just_pressed("slot_3"):
		inventory.select_slot(2)

	if Input.is_action_just_pressed("interact"):
		_try_pickup()

	# Sword swing with mouse
	_handle_combat_input()


func _try_pickup() -> void:
	if nearby_items.size() == 0:
		return

	var item_to_pickup = nearby_items[0]
	var item = item_to_pickup.get_item()

	if item.item_type == Item.ItemType.YARN:
		inventory.add_yarn(item.quantity)
		yarn_in_inventory = inventory.get_yarn_amount()
		yarn_trail.extend_max_length(item.quantity)
		yarn_amount_changed.emit(yarn_in_inventory)
		item_to_pickup.queue_free()
		nearby_items.remove_at(0)
		return

	if inventory.has_space():
		var picked_item = item_to_pickup.pickup()
		inventory.add_item(picked_item)
		nearby_items.remove_at(0)
	else:
		var picked_item = item_to_pickup.pickup()
		var dropped_item = inventory.swap_item(inventory.selected_slot, picked_item)
		nearby_items.remove_at(0)

		if dropped_item != null:
			_spawn_dropped_item(dropped_item)


func _spawn_dropped_item(item: Item) -> void:
	pass


func _start_dash(direction: Vector2) -> void:
	is_dashing = true
	can_dash = false
	dash_direction = direction.normalized()
	velocity = dash_direction * dash_speed
	dash_timer.start(dash_duration)
	modulate = Color(1.5, 1.5, 1.5, 1.0)


func _process_dash() -> void:
	velocity = dash_direction * dash_speed


func _on_dash_finished() -> void:
	is_dashing = false
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	dash_cooldown_timer.start(dash_cooldown)


func _on_dash_cooldown_finished() -> void:
	can_dash = true


func _update_yarn() -> void:
	if not yarn_trail:
		return

	yarn_in_inventory = inventory.get_yarn_amount()

	var yarn_used = yarn_trail.add_point(global_position, yarn_in_inventory)

	if yarn_used > 0:
		inventory.consume_yarn(yarn_used)
		yarn_in_inventory = inventory.get_yarn_amount()
		yarn_amount_changed.emit(yarn_in_inventory)


func _on_pickup_area_entered(area: Area2D) -> void:
	if area is WorldItem:
		nearby_items.append(area)
		area._on_body_entered(self)


func _on_pickup_area_exited(area: Area2D) -> void:
	if area is WorldItem:
		nearby_items.erase(area)
		area._on_body_exited(self)


func get_inventory() -> Inventory:
	return inventory


func get_yarn_trail() -> YarnTrail:
	return yarn_trail


func set_yarn_trail(trail: YarnTrail) -> void:
	yarn_trail = trail


# ===== COMBAT =====

func _handle_combat_input() -> void:
	var selected_item = inventory.get_selected_item()
	if selected_item == null or selected_item.item_type != Item.ItemType.SWORD:
		return

	# Update sword stats based on equipped weapon
	sword_swing.set_weapon_stats(selected_item.damage, selected_item.attack_range)

	# Mouse button pressed - start tracking
	if Input.is_action_just_pressed("attack"):
		var mouse_pos = get_global_mouse_position()
		sword_swing.start_tracking(mouse_pos)

	# Mouse button held - update tracking
	if Input.is_action_pressed("attack"):
		var mouse_pos = get_global_mouse_position()
		sword_swing.update_tracking(mouse_pos)

	# Mouse button released - finish swing
	if Input.is_action_just_released("attack"):
		var mouse_pos = get_global_mouse_position()
		sword_swing.finish_tracking(mouse_pos)


func _on_sword_hit(target: Node2D, damage_amount: int) -> void:
	# Called when sword hits something
	if target.has_method("take_damage"):
		target.take_damage(damage_amount)
	print("Hit ", target.name, " for ", damage_amount, " damage!")


func take_damage(amount: int) -> void:
	current_hp -= amount
	current_hp = max(current_hp, 0)
	hp_changed.emit(current_hp, max_hp)

	# Visual feedback
	modulate = Color(1.5, 0.5, 0.5, 1.0)
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	if current_hp <= 0:
		_die()


func heal(amount: int) -> void:
	current_hp += amount
	current_hp = min(current_hp, max_hp)
	hp_changed.emit(current_hp, max_hp)


func _die() -> void:
	player_died.emit()
	# For now, just print - you can add death logic later
	print("Player died!")


func get_hp() -> int:
	return current_hp


func get_max_hp() -> int:
	return max_hp
