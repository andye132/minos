extends CharacterBody2D
class_name Player

# Movement
@export var move_speed: float = 200.0
@export var acceleration: float = 1000.0
@export var friction: float = 1200.0

# Dash
@export var dash_speed: float = 300.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.8

# State
var is_dashing: bool = false
var can_dash: bool = true
var dash_direction: Vector2 = Vector2.ZERO
var look_direction: Vector2 = Vector2.RIGHT
var current_flashlight_angle: float = 0.0  # For smooth rotation

# Yarn
@export var starting_yarn: float = 5000.0  # Starting yarn units
var yarn_in_inventory: float = 5000.0  # How much yarn we can still lay down

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
var radial_texture: GradientTexture2D

# Nearby items for pickup
var nearby_items: Array[WorldItem] = []

signal yarn_amount_changed(amount: float)

#multiplayer sync
func _enter_tree() -> void:
	# When this node appears on a client, it checks its own name.
	# If its name is "914757339", it sets its authority to 914757339.
	if name.is_valid_int():
		var id = name.to_int()
		set_multiplayer_authority(id)
		print("Peer ", multiplayer.get_unique_id(), " claiming authority for node ", id)
	if !is_multiplayer_authority(): 
		return

func _ready() -> void:
	_create_light_textures()
	
	if is_multiplayer_authority():
		$Camera2D.make_current()
	else:
		$Camera2D.enabled = false
	
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
	# Disable lights - fog of war handles visibility
	flashlight.enabled = false
	ambient_light.enabled = false


func _create_cone_image(width: int, height: int, half_angle_deg: float) -> Image:
	# Create a smooth cone with bright center
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)

	var center = Vector2(width / 2.0, height / 2.0)
	var half_angle_rad = deg_to_rad(half_angle_deg)
	var max_dist = width / 2.0
	var center_radius = max_dist * 0.12

	for y in range(height):
		for x in range(width):
			var pos = Vector2(x, y) - center
			var dist = pos.length()
			var angle = abs(atan2(pos.y, pos.x))

			var alpha = 0.0

			# Bright center circle
			if dist < center_radius:
				var center_falloff = dist / center_radius
				alpha = 1.0 - (center_falloff * 0.1)  # Slight falloff from very center
			# Cone area with smooth edges
			elif angle <= half_angle_rad and pos.x >= 0:
				# Distance falloff - smooth curve
				var dist_factor = 1.0 - ((dist - center_radius) / (max_dist - center_radius))
				dist_factor = clampf(dist_factor, 0.0, 1.0)
				dist_factor = smoothstep(0.0, 1.0, dist_factor)

				# Angle falloff - very smooth at edges
				var angle_normalized = angle / half_angle_rad
				var angle_factor = 1.0 - smoothstep(0.5, 1.0, angle_normalized)

				alpha = dist_factor * angle_factor
			# Transition zone between center and cone
			elif dist < center_radius * 2.0 and pos.x >= -center_radius:
				var transition = 1.0 - ((dist - center_radius) / center_radius)
				alpha = clampf(transition * 0.5, 0.0, 0.5)

			image.set_pixel(x, y, Color(1, 1, 1, alpha))

	return image


func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _physics_process(delta: float) -> void:
	
	if !is_multiplayer_authority(): 
		return
		
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
	# Follow mouse cursor
	var mouse_pos = get_global_mouse_position()
	var direction_to_mouse = (mouse_pos - global_position).normalized()
	var target_angle = direction_to_mouse.angle()

	# Smooth interpolation for fluid movement
	current_flashlight_angle = lerp_angle(current_flashlight_angle, target_angle, 0.15)
	flashlight.rotation = current_flashlight_angle


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
