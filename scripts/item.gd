extends Resource
class_name Item

enum ItemType { YARN, SWORD, TORCH, KEY, LANTERN, NONE }

@export var item_type: ItemType = ItemType.NONE
@export var item_name: String = "Unknown"
@export var description: String = ""
@export var icon_color: Color = Color.WHITE
@export var icon_texture: Texture2D = null  # Optional texture for inventory UI
@export var stackable: bool = false
@export var quantity: int = 1
@export var damage: int = 0
@export var attack_range: float = 60.0  # Swing radius in pixels
@export var lantern_radius: float = 150.0  # Light radius for lantern


func _init(type: ItemType = ItemType.NONE, name: String = "Unknown", desc: String = "", color: Color = Color.WHITE) -> void:
	item_type = type
	item_name = name
	description = desc
	icon_color = color


static func create_yarn(amount: float = 250.0) -> Item:
	var item = Item.new()
	item.item_type = ItemType.YARN
	item.item_name = "Yarn"
	item.description = "Glowing yarn to light your path"
	item.icon_color = Color(1.0, 0.7, 0.2)
	item.stackable = true
	item.quantity = int(amount)
	return item


static func create_sword() -> Item:
	var item = Item.new()
	item.item_type = ItemType.SWORD
	item.item_name = "Sword"
	item.description = "A sharp blade"
	item.icon_color = Color(0.7, 0.7, 0.8)
	item.damage = 25
	item.attack_range = 70.0
	return item


static func create_torch() -> Item:
	var item = Item.new()
	item.item_type = ItemType.TORCH
	item.item_name = "Torch"
	item.description = "Provides extra light"
	item.icon_color = Color(1.0, 0.5, 0.1)
	return item


static func create_lantern(radius: float = 150.0) -> Item:
	var item = Item.new()
	item.item_type = ItemType.LANTERN
	item.item_name = "Lantern"
	item.description = "Hold to light the way"
	item.icon_color = Color(1.0, 0.8, 0.4)
	item.lantern_radius = radius
	return item
