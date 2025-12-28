extends Area2D
class_name WorldItem

@export var item_type: Item.ItemType = Item.ItemType.SWORD
@export var yarn_amount: float = 50.0  # Only used for yarn pickups

var item_data: Item

@onready var sprite: Polygon2D = $Sprite
@onready var light: PointLight2D = $Light
@onready var label: Label = $Label


func _ready() -> void:
	_setup_item()
	body_entered.connect(_on_body_entered)


func _setup_item() -> void:
	match item_type:
		Item.ItemType.YARN:
			item_data = Item.create_yarn(yarn_amount)
			sprite.color = Color(1.0, 0.7, 0.2)
			sprite.polygon = _create_ball_shape()
			light.color = Color(1.0, 0.8, 0.3)
			light.energy = 0.3
			label.text = "Yarn +" + str(int(yarn_amount)) + "m"
		
		Item.ItemType.SWORD:
			item_data = Item.create_sword()
			sprite.color = Color(0.7, 0.7, 0.85)
			sprite.polygon = _create_sword_shape()
			light.color = Color(0.7, 0.8, 1.0)
			light.energy = 0.2
			label.text = "Sword"
		
		Item.ItemType.TORCH:
			item_data = Item.create_torch()
			sprite.color = Color(1.0, 0.5, 0.1)
			sprite.polygon = _create_torch_shape()
			light.color = Color(1.0, 0.6, 0.2)
			light.energy = 0.5
			label.text = "Torch"
		
		_:
			item_data = Item.new()
			label.text = "???"
	
	label.visible = false


func _create_ball_shape() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-8, 0), Vector2(-6, -6), Vector2(0, -8), Vector2(6, -6),
		Vector2(8, 0), Vector2(6, 6), Vector2(0, 8), Vector2(-6, 6)
	])


func _create_sword_shape() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-2, 12), Vector2(-2, -8), Vector2(-6, -8), Vector2(0, -16),
		Vector2(6, -8), Vector2(2, -8), Vector2(2, 12), Vector2(4, 14),
		Vector2(4, 16), Vector2(-4, 16), Vector2(-4, 14)
	])


func _create_torch_shape() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-3, 12), Vector2(-3, 0), Vector2(-6, -2), Vector2(-4, -8),
		Vector2(0, -12), Vector2(4, -8), Vector2(6, -2), Vector2(3, 0),
		Vector2(3, 12)
	])


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
