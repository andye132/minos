extends VBoxContainer
class_name ActiveBoonsUI

# Texture paths for boon sprites
const SPEED_TEXTURE = preload("res://Images/ItemsAndBoons/SpeedBuff.png")
const DAMAGE_TEXTURE = preload("res://Images/ItemsAndBoons/AttackBuff.png")
const HP_TEXTURE = preload("res://Images/ItemsAndBoons/HealthBuff.png")
const DASH_TEXTURE = preload("res://Images/ItemsAndBoons/DashBuff.png")

# Reference to the player (set externally)
var player: Player

# Icons for each boon type
var boon_icons: Dictionary = {}


func _ready() -> void:
	# Position will be set by scene/parent
	pass


func setup(p: Player) -> void:
	player = p
	if player:
		player.boon_acquired.connect(_on_boon_acquired)


func _on_boon_acquired(boon: Boon) -> void:
	_add_boon_icon(boon)


func _add_boon_icon(boon: Boon) -> void:
	var icon_container = HBoxContainer.new()
	icon_container.add_theme_constant_override("separation", 8)

	# Create textured icon
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	# Set texture based on boon type
	match boon.boon_type:
		Boon.BoonType.SPEED_BOOST:
			icon.texture = SPEED_TEXTURE
		Boon.BoonType.DAMAGE_BOOST:
			icon.texture = DAMAGE_TEXTURE
		Boon.BoonType.HP_BOOST:
			icon.texture = HP_TEXTURE
		Boon.BoonType.DASH_COOLDOWN:
			icon.texture = DASH_TEXTURE

	# Create label
	var label = Label.new()
	label.text = boon.boon_name
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", boon.icon_color)

	icon_container.add_child(icon)
	icon_container.add_child(label)

	add_child(icon_container)

	# Store reference
	if not boon_icons.has(boon.boon_type):
		boon_icons[boon.boon_type] = []
	boon_icons[boon.boon_type].append(icon_container)


func clear_all() -> void:
	for child in get_children():
		child.queue_free()
	boon_icons.clear()
