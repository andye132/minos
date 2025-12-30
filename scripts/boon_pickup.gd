extends Area2D
class_name BoonPickup

# Texture paths for boon sprites
const SPEED_TEXTURE = preload("res://Images/ItemsAndBoons/SpeedBuff.png")
const DAMAGE_TEXTURE = preload("res://Images/ItemsAndBoons/AttackBuff.png")
const HP_TEXTURE = preload("res://Images/ItemsAndBoons/HealthBuff.png")
const DASH_TEXTURE = preload("res://Images/ItemsAndBoons/DashBuff.png")

@export var boon_type: Boon.BoonType = Boon.BoonType.SPEED_BOOST
@export var sprite_scale: float = 0.5  # Adjust this to resize sprites

var boon_data: Boon

@onready var sprite: Sprite2D = $Sprite
@onready var light: PointLight2D = $Light
@onready var label: Label = $Label

signal boon_collected(boon: Boon, collector: Player)


func _ready() -> void:
	_setup_boon()
	add_to_group("boon_pickups")


func _setup_boon() -> void:
	match boon_type:
		Boon.BoonType.SPEED_BOOST:
			boon_data = Boon.create_speed_boost()
			sprite.texture = SPEED_TEXTURE
			light.color = Color(0.3, 0.9, 1.0)
			light.energy = 0.4
			label.text = "Swift Feet"

		Boon.BoonType.DAMAGE_BOOST:
			boon_data = Boon.create_damage_boost()
			sprite.texture = DAMAGE_TEXTURE
			light.color = Color(1.0, 0.4, 0.4)
			light.energy = 0.4
			label.text = "Warrior's Might"

		Boon.BoonType.HP_BOOST:
			boon_data = Boon.create_hp_boost()
			sprite.texture = HP_TEXTURE
			light.color = Color(0.4, 1.0, 0.4)
			light.energy = 0.4
			label.text = "Vitality"

		Boon.BoonType.DASH_COOLDOWN:
			boon_data = Boon.create_dash_cooldown()
			sprite.texture = DASH_TEXTURE
			light.color = Color(1.0, 1.0, 0.5)
			light.energy = 0.4
			label.text = "Quick Step"

	sprite.scale = Vector2(sprite_scale, sprite_scale)
	label.visible = false


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		label.visible = false


func pickup(collector: Player) -> Boon:
	# Apply boon directly to collector
	collector.apply_boon(boon_data)
	boon_collected.emit(boon_data, collector)
	var returned_boon = boon_data
	queue_free()
	return returned_boon


func get_boon() -> Boon:
	return boon_data
