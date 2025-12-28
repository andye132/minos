extends CharacterBody2D
class_name Player

# Movement
@export var move_speed: float = 200.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0

# Dash
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.8

# State
var is_dashing: bool = false
var can_dash: bool = true
var dash_direction: Vector2 = Vector2.ZERO
var look_direction: Vector2 = Vector2.RIGHT

# Yarn
@export var starting_yarn: float = 500.0  # Starting yarn units
var yarn_in_inventory: float = 500.0  # How much yarn we can still lay down

# References
@onready var flashlight: PointLight2D = $Flashlight
@onready var ambient_light: PointLight2D = $AmbientLight
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer
@onready var pickup_area: Area2D = $PickupArea
@onready var inventory: Inventory = $Inventory

# Yarn trail - set externally from Main scene
var yarn_trail: YarnTrail

# Textures
var cone_texture: GradientTexture2D
var radial_texture: GradientTexture2D

# Nearby items for pickup
var nearby_items: Array[WorldItem] = []

signal yarn_amount_changed(amount: float)


func _ready() -> void:
	_create_light_textures()
	
	# Setup inventory with starting yarn
	var yarn_item = Item.create_yarn(starting_yarn)
	inventory.add_item(yarn_item)
	inventory.select_slot(0)  # Yarn in slot 1 by default
	
	yarn_in_inventory = starting_yarn
	
	# Connect signals
	dash_timer.timeout.connect(_on_dash_finished)
	dash_cooldown_timer.timeout.connect(_on_dash_cooldown_finished)
	pickup_area.area_entered.connect(_on_pickup_area_entered)
	pickup_area.area_exited.connect(_on_pickup_area_exited)


func _create_light_textures() -> void:
	# Cone texture for flashlight
	cone_texture = GradientTexture2D.new()
	cone_texture.width = 512
	cone_texture.height = 512
	cone_texture.fill = GradientTexture2D.FILL_RADIAL
	cone_texture.fill_from = Vector2(0.0, 0.5)
	cone_texture.fill_to = Vector2(1.0, 0.5)
	
	var cone_gradient = Gradient.new()
	cone_gradient.set_offset(0, 0.0)
	cone_gradient.set_color(0, Color(1, 1, 1, 1))
	cone_gradient.add_point(0.4, Color(1, 1, 1, 0.6))
	cone_gradient.set_offset(1, 1.0)
	cone_gradient.set_color(1, Color(1, 1, 1, 0))
	cone_texture.gradient = cone_gradient
	flashlight.texture = cone_texture
	
	# Radial texture for ambient light
	radial_texture = GradientTexture2D.new()
	radial_texture.width = 256
	radial_texture.height = 256
	radial_texture.fill = GradientTexture2D.FILL_RADIAL
	radial_texture.fill_from = Vector2(0.5, 0.5)
	radial_texture.fill_to = Vector2(0.5, 0.0)
	
	var radial_gradient = Gradient.new()
	radial_gradient.set_offset(0, 0.0)
	radial_gradient.set_color(0, Color(1, 1, 1, 1))
	radial_gradient.set_offset(1, 1.0)
	radial_gradient.set_color(1, Color(1, 1, 1, 0))
	radial_texture.gradient = radial_gradient
	ambient_light.texture = radial_texture


func _physics_process(delta: float) -> void:
	if is_dashing:
		_process_dash()
	else:
		_process_movement(delta)
	
	move_and_slide()
	_update_flashlight_rotation()
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
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	if Input.is_action_just_pressed("dash") and can_dash:
		_start_dash(input_dir if input_dir != Vector2.ZERO else look_direction)


func _handle_input() -> void:
	# Slot selection
	if Input.is_action_just_pressed("slot_1"):
		inventory.select_slot(0)
	elif Input.is_action_just_pressed("slot_2"):
		inventory.select_slot(1)
	elif Input.is_action_just_pressed("slot_3"):
		inventory.select_slot(2)
	
	# Pickup
	if Input.is_action_just_pressed("interact"):
		_try_pickup()


func _try_pickup() -> void:
	if nearby_items.size() == 0:
		return
	
	var item_to_pickup = nearby_items[0]
	var item = item_to_pickup.get_item()
	
	# Special handling for yarn - always add to existing yarn
	if item.item_type == Item.ItemType.YARN:
		inventory.add_yarn(item.quantity)
		yarn_in_inventory = inventory.get_yarn_amount()
		yarn_trail.extend_max_length(item.quantity)
		yarn_amount_changed.emit(yarn_in_inventory)
		item_to_pickup.queue_free()
		nearby_items.remove_at(0)
		return
	
	# For other items
	if inventory.has_space():
		var picked_item = item_to_pickup.pickup()
		inventory.add_item(picked_item)
		nearby_items.remove_at(0)
	else:
		# Swap with currently held item
		var picked_item = item_to_pickup.pickup()
		var dropped_item = inventory.swap_item(inventory.selected_slot, picked_item)
		nearby_items.remove_at(0)
		
		# Spawn dropped item in world
		if dropped_item != null:
			_spawn_dropped_item(dropped_item)


func _spawn_dropped_item(item: Item) -> void:
	# This would spawn a WorldItem at player's position
	# For now, items are just lost when swapped
	# TODO: Implement proper item dropping
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


func _update_flashlight_rotation() -> void:
	flashlight.rotation = look_direction.angle()


func _update_yarn() -> void:
	if not yarn_trail:
		return
	
	# Get yarn amount from inventory
	yarn_in_inventory = inventory.get_yarn_amount()
	
	# Add point to yarn trail, consuming yarn as we go
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
