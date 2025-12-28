extends Control
class_name InventoryUI

const SLOT_SIZE: Vector2 = Vector2(64, 64)
const SLOT_MARGIN: float = 8.0
const MARGIN: Vector2 = Vector2(20, 20)

var inventory: Inventory
var slot_panels: Array[Panel] = []
var slot_icons: Array[Polygon2D] = []
var slot_labels: Array[Label] = []
var selection_indicator: Panel

@onready var container: HBoxContainer = $Container
@onready var yarn_label: Label = $YarnLabel


func _ready() -> void:
	_create_slots()
	_position_ui()


func _create_slots() -> void:
	for i in range(Inventory.MAX_SLOTS):
		var slot = Panel.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.name = "Slot" + str(i + 1)
		
		# Slot number label
		var num_label = Label.new()
		num_label.text = str(i + 1)
		num_label.position = Vector2(4, 2)
		num_label.add_theme_font_size_override("font_size", 12)
		slot.add_child(num_label)
		
		# Item icon (polygon)
		var icon = Polygon2D.new()
		icon.position = SLOT_SIZE / 2
		icon.visible = false
		slot.add_child(icon)
		slot_icons.append(icon)
		
		# Quantity label
		var qty_label = Label.new()
		qty_label.position = Vector2(4, SLOT_SIZE.y - 20)
		qty_label.add_theme_font_size_override("font_size", 11)
		qty_label.visible = false
		slot.add_child(qty_label)
		slot_labels.append(qty_label)
		
		container.add_child(slot)
		slot_panels.append(slot)
	
	# Selection indicator
	selection_indicator = Panel.new()
	selection_indicator.custom_minimum_size = SLOT_SIZE + Vector2(8, 8)
	selection_indicator.modulate = Color(1.0, 0.8, 0.2, 0.8)
	add_child(selection_indicator)


func _position_ui() -> void:
	# Position in bottom-right
	var screen_size = get_viewport_rect().size
	var total_width = (SLOT_SIZE.x + SLOT_MARGIN) * Inventory.MAX_SLOTS
	position = Vector2(
		screen_size.x - total_width - MARGIN.x,
		screen_size.y - SLOT_SIZE.y - MARGIN.y - 30
	)
	
	yarn_label.position = Vector2(0, SLOT_SIZE.y + 8)


func _process(_delta: float) -> void:
	_position_ui()
	_update_selection_indicator()


func connect_to_inventory(inv: Inventory) -> void:
	inventory = inv
	inventory.inventory_changed.connect(_on_inventory_changed)
	inventory.slot_selected.connect(_on_slot_selected)
	_on_inventory_changed()
	_on_slot_selected(inventory.selected_slot)


func _on_inventory_changed() -> void:
	if not inventory:
		return
	
	for i in range(Inventory.MAX_SLOTS):
		var item = inventory.get_item(i)
		
		if item == null:
			slot_icons[i].visible = false
			slot_labels[i].visible = false
		else:
			slot_icons[i].visible = true
			slot_icons[i].color = item.icon_color
			slot_icons[i].polygon = _get_icon_shape(item.item_type)
			
			if item.stackable and item.quantity > 1:
				slot_labels[i].visible = true
				slot_labels[i].text = str(item.quantity)
			else:
				slot_labels[i].visible = false


func _on_slot_selected(slot_index: int) -> void:
	_update_selection_indicator()


func _update_selection_indicator() -> void:
	if not inventory or slot_panels.size() == 0:
		return
	
	var selected = inventory.selected_slot
	if selected >= 0 and selected < slot_panels.size():
		var slot_pos = slot_panels[selected].position
		selection_indicator.position = container.position + slot_pos - Vector2(4, 4)
		selection_indicator.visible = true


func update_yarn_display(amount: float) -> void:
	yarn_label.text = "Yarn: " + str(int(amount)) + "m"


func _get_icon_shape(item_type: Item.ItemType) -> PackedVector2Array:
	match item_type:
		Item.ItemType.YARN:
			return PackedVector2Array([
				Vector2(-12, 0), Vector2(-8, -8), Vector2(0, -12), Vector2(8, -8),
				Vector2(12, 0), Vector2(8, 8), Vector2(0, 12), Vector2(-8, 8)
			])
		Item.ItemType.SWORD:
			return PackedVector2Array([
				Vector2(-3, 18), Vector2(-3, -10), Vector2(-8, -10), Vector2(0, -22),
				Vector2(8, -10), Vector2(3, -10), Vector2(3, 18), Vector2(5, 20),
				Vector2(5, 22), Vector2(-5, 22), Vector2(-5, 20)
			])
		Item.ItemType.TORCH:
			return PackedVector2Array([
				Vector2(-4, 16), Vector2(-4, 2), Vector2(-8, 0), Vector2(-5, -10),
				Vector2(0, -16), Vector2(5, -10), Vector2(8, 0), Vector2(4, 2),
				Vector2(4, 16)
			])
		_:
			return PackedVector2Array([
				Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)
			])
