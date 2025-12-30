extends Resource
class_name Boon

enum BoonType {
	SPEED_BOOST,
	DAMAGE_BOOST,
	HP_BOOST,
	DASH_COOLDOWN
}

@export var boon_type: BoonType = BoonType.SPEED_BOOST
@export var boon_name: String = "Unknown Boon"
@export var description: String = ""
@export var icon_color: Color = Color.WHITE
@export var duration: float = -1.0  # -1 = permanent
@export var value: float = 0.0  # Effect magnitude (speed multiplier, damage bonus, etc.)


func _init(type: BoonType = BoonType.SPEED_BOOST) -> void:
	boon_type = type
	_setup_defaults()


func _setup_defaults() -> void:
	match boon_type:
		BoonType.SPEED_BOOST:
			boon_name = "Fastfoot"
			description = "Move faster"
			icon_color = Color(0.2, 0.8, 1.0)
			value = 1.3  # 30% speed boost
		BoonType.DAMAGE_BOOST:
			boon_name = "Steroids"
			description = "Deal more damage"
			icon_color = Color(1.0, 0.3, 0.3)
			value = 1.5  # 50% damage boost
		BoonType.HP_BOOST:
			boon_name = "Vitality"
			description = "Increased max HP"
			icon_color = Color(0.3, 1.0, 0.3)
			value = 25.0  # +25 max HP
		BoonType.DASH_COOLDOWN:
			boon_name = "Lunges"
			description = "Dash more often"
			icon_color = Color(1.0, 1.0, 0.3)
			value = 0.5  # 50% cooldown reduction


static func create_speed_boost() -> Boon:
	var boon = Boon.new(BoonType.SPEED_BOOST)
	return boon


static func create_damage_boost() -> Boon:
	var boon = Boon.new(BoonType.DAMAGE_BOOST)
	return boon


static func create_hp_boost() -> Boon:
	var boon = Boon.new(BoonType.HP_BOOST)
	return boon


static func create_dash_cooldown() -> Boon:
	var boon = Boon.new(BoonType.DASH_COOLDOWN)
	return boon
