extends Area2D
class_name WorldItem

# Texture paths for item sprites
const SWORD_TEXTURE = preload("res://Images/ItemsAndBoons/SwordItem.png")
const LANTERN_TEXTURE = preload("res://Images/ItemsAndBoons/LanternItem.png")

@export var item_type: Item.ItemType = Item.ItemType.SWORD
@export var yarn_amount: float = 50.0  # Only used for yarn pickups
@export var lantern_radius: float = 150.0  # Only used for lantern
@export var sprite_scale: float = 0.5  # Adjust this to resize sprites

var item_data: Item

@onready var sprite: Sprite2D = $Sprite
@onready var light: PointLight2D = $Light
@onready var label: Label = $Label


func _ready() -> void:
	_setup_item()
	body_entered.connect(_on_body_entered)


func _setup_item() -> void:
	match item_type:
		Item.ItemType.YARN:
			item_data = Item.create_yarn(yarn_amount)
			# Yarn still uses polygon shape (ball of yarn)
			_setup_yarn_sprite()
			light.color = Color(1.0, 0.8, 0.3)
			light.energy = 0.3
			label.text = "Yarn +" + str(int(yarn_amount)) + "m"

		Item.ItemType.SWORD:
			item_data = Item.create_sword()
			sprite.texture = SWORD_TEXTURE
			sprite.scale = Vector2(sprite_scale, sprite_scale)
			light.color = Color(0.7, 0.8, 1.0)
			light.energy = 0.2
			label.text = "Sword"

		Item.ItemType.TORCH:
			item_data = Item.create_torch()
			# Torch still uses polygon shape
			_setup_torch_sprite()
			light.color = Color(1.0, 0.6, 0.2)
			light.energy = 0.5
			label.text = "Torch"

		Item.ItemType.LANTERN:
			item_data = Item.create_lantern(lantern_radius)
			sprite.texture = LANTERN_TEXTURE
			sprite.scale = Vector2(sprite_scale, sprite_scale)
			light.color = Color(1.0, 0.85, 0.5)
			light.energy = 0.6
			label.text = "Lantern"

		_:
			item_data = Item.new()
			label.text = "???"

	label.visible = false


func _setup_yarn_sprite() -> void:
	# Create a simple colored circle for yarn using a generated texture
	# Since yarn doesn't have a sprite, we'll use a placeholder
	sprite.texture = null
	sprite.scale = Vector2.ONE
	# Create a fallback - we'll draw it in a different way
	# For now yarn will just show as the light glow


func _setup_torch_sprite() -> void:
	# Torch doesn't have a sprite either, so similar handling
	sprite.texture = null
	sprite.scale = Vector2.ONE


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		label.visible = false


func pickup() -> Item:
	var returned_item = item_data
	queue_free()
	return returned_item


func get_item() -> Item:
	return item_data
