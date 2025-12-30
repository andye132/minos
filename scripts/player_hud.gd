extends CanvasLayer
class_name PlayerHUD

# Texture paths for boon sprites
const SPEED_TEXTURE = preload("res://Images/ItemsAndBoons/SpeedBuff.png")
const DAMAGE_TEXTURE = preload("res://Images/ItemsAndBoons/AttackBuff.png")
const HP_TEXTURE = preload("res://Images/ItemsAndBoons/HealthBuff.png")
const DASH_TEXTURE = preload("res://Images/ItemsAndBoons/DashBuff.png")

var player: Player

# UI references
@onready var health_bar: ProgressBar = $StatsPanel/VBoxContainer/HealthBar
@onready var health_label: Label = $StatsPanel/VBoxContainer/HealthBar/HealthLabel
@onready var strength_label: Label = $StatsPanel/VBoxContainer/StrengthLabel
@onready var speed_label: Label = $StatsPanel/VBoxContainer/SpeedLabel
@onready var boons_container: HBoxContainer = $BoonsPanel/BoonsContainer

# Boon tracking - counts per type
var boon_counts: Dictionary = {}
var boon_icons: Dictionary = {}


func _ready() -> void:
	# Initialize boon counts
	for type in Boon.BoonType.values():
		boon_counts[type] = 0


func setup(p: Player) -> void:
	player = p
	if player:
		player.boon_acquired.connect(_on_boon_acquired)
		player.hp_changed.connect(_on_hp_changed)

		# Initial update
		_update_health_display()
		_update_stats_display()


func _process(_delta: float) -> void:
	if player:
		_update_stats_display()


func _on_hp_changed(_current: int, _maximum: int) -> void:
	_update_health_display()


func _update_health_display() -> void:
	if not player:
		return

	health_bar.max_value = player.max_hp
	health_bar.value = player.current_hp
	health_label.text = str(player.current_hp) + " / " + str(player.max_hp)


func _update_stats_display() -> void:
	if not player:
		return

	# Calculate effective stats
	var effective_damage = player.damage_multiplier
	var effective_speed = player.speed_multiplier

	strength_label.text = "STR: x" + str(snapped(effective_damage, 0.1))
	speed_label.text = "SPD: x" + str(snapped(effective_speed, 0.1))


func _on_boon_acquired(boon: Boon) -> void:
	boon_counts[boon.boon_type] += 1
	_update_boon_display(boon.boon_type)


func _update_boon_display(boon_type: Boon.BoonType) -> void:
	var count = boon_counts[boon_type]

	if boon_icons.has(boon_type):
		# Update existing icon count
		var icon_container = boon_icons[boon_type]
		var count_label = icon_container.get_node("CountLabel") as Label
		count_label.text = "x" + str(count)
	else:
		# Create new icon
		_create_boon_icon(boon_type, count)


func _create_boon_icon(boon_type: Boon.BoonType, count: int) -> void:
	var icon_container = VBoxContainer.new()
	icon_container.add_theme_constant_override("separation", 2)
	icon_container.alignment = BoxContainer.ALIGNMENT_CENTER

	# Create textured icon
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	# Set texture based on boon type
	match boon_type:
		Boon.BoonType.SPEED_BOOST:
			icon.texture = SPEED_TEXTURE
		Boon.BoonType.DAMAGE_BOOST:
			icon.texture = DAMAGE_TEXTURE
		Boon.BoonType.HP_BOOST:
			icon.texture = HP_TEXTURE
		Boon.BoonType.DASH_COOLDOWN:
			icon.texture = DASH_TEXTURE

	# Create count label
	var count_label = Label.new()
	count_label.name = "CountLabel"
	count_label.text = "x" + str(count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 12)

	icon_container.add_child(icon)
	icon_container.add_child(count_label)

	boons_container.add_child(icon_container)
	boon_icons[boon_type] = icon_container


func clear_boons() -> void:
	for child in boons_container.get_children():
		child.queue_free()
	boon_icons.clear()
	for type in Boon.BoonType.values():
		boon_counts[type] = 0
