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
var base_max_hp: int = 100  # Store original for boon calculations

# Boons
var active_boons: Array[Boon] = []
var speed_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var dash_cooldown_multiplier: float = 1.0

# Lantern (inventory item based)
var lantern_active: bool = false
var lantern_radius: float = 150.0
var lantern_light: PointLight2D = null

signal boon_acquired(boon: Boon)

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
	base_max_hp = max_hp
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
		var effective_speed = move_speed * speed_multiplier
		velocity = velocity.move_toward(input_dir * effective_speed, acceleration * delta)
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
		_update_lantern_state()
	elif Input.is_action_just_pressed("slot_2"):
		inventory.select_slot(1)
		_update_lantern_state()
	elif Input.is_action_just_pressed("slot_3"):
		inventory.select_slot(2)
		_update_lantern_state()

	if Input.is_action_just_pressed("interact"):
		_try_pickup()
		_update_lantern_state()

	# Sword swing with mouse
	_handle_combat_input()


func _update_lantern_state() -> void:
	var selected_item = inventory.get_selected_item()
	var should_be_active = selected_item != null and selected_item.item_type == Item.ItemType.LANTERN

	if should_be_active and not lantern_active:
		# Activate lantern
		lantern_active = true
		lantern_radius = selected_item.lantern_radius
		_setup_lantern_light()
		print("Lantern activated! Radius: ", lantern_radius)
	elif not should_be_active and lantern_active:
		# Deactivate lantern
		lantern_active = false
		if lantern_light:
			lantern_light.enabled = false
		print("Lantern deactivated")


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
	var effective_cooldown = dash_cooldown * dash_cooldown_multiplier
	dash_cooldown_timer.start(effective_cooldown)


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
	elif area is BoonPickup:
		# Auto-pickup boons immediately
		var boon = area.pickup(self)
		# apply_boon is called via the signal in BoonManager


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
	# Called when sword hits something - apply damage multiplier from boons
	var effective_damage = int(damage_amount * damage_multiplier)
	if target.has_method("take_damage"):
		target.take_damage(effective_damage)
	print("Hit ", target.name, " for ", effective_damage, " damage!")


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
	queue_free()


func get_hp() -> int:
	return current_hp


func get_max_hp() -> int:
	return max_hp


# ===== BOONS =====

func apply_boon(boon: Boon) -> void:
	active_boons.append(boon)

	match boon.boon_type:
		Boon.BoonType.SPEED_BOOST:
			speed_multiplier *= boon.value
			print("Boon: Speed boost! Multiplier: ", speed_multiplier)

		Boon.BoonType.DAMAGE_BOOST:
			damage_multiplier *= boon.value
			print("Boon: Damage boost! Multiplier: ", damage_multiplier)

		Boon.BoonType.HP_BOOST:
			var hp_increase = int(boon.value)
			max_hp += hp_increase
			current_hp += hp_increase  # Also heal by the amount
			hp_changed.emit(current_hp, max_hp)
			print("Boon: HP boost! Max HP: ", max_hp)

		Boon.BoonType.DASH_COOLDOWN:
			dash_cooldown_multiplier *= boon.value
			print("Boon: Dash cooldown reduced! Multiplier: ", dash_cooldown_multiplier)

	boon_acquired.emit(boon)


func _setup_lantern_light() -> void:
	if lantern_light:
		lantern_light.queue_free()

	lantern_light = PointLight2D.new()
	lantern_light.name = "LanternLight"
	lantern_light.enabled = true
	lantern_light.color = Color(1.0, 0.9, 0.7)
	lantern_light.energy = 0.8

	# Create gradient texture for the lantern
	var gradient = Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(0, 0, 0, 0))

	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)

	lantern_light.texture = texture
	# Scale texture to match desired radius
	lantern_light.texture_scale = lantern_radius / 64.0

	add_child(lantern_light)


func get_active_boons() -> Array[Boon]:
	return active_boons


func has_boon_of_type(type: Boon.BoonType) -> bool:
	for boon in active_boons:
		if boon.boon_type == type:
			return true
	return false


func get_lantern_radius() -> float:
	return lantern_radius if lantern_active else 0.0


func is_lantern_active() -> bool:
	return lantern_active
	
