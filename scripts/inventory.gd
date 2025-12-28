extends Node
class_name Inventory

const MAX_SLOTS: int = 3

var slots: Array[Item] = []
var selected_slot: int = 0

signal inventory_changed()
signal slot_selected(slot_index: int)
signal item_used(item: Item)


func _init() -> void:
	# Initialize empty slots
	slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		slots[i] = null


func _ready() -> void:
	pass


func add_item(item: Item) -> bool:
	# If stackable, try to add to existing stack first
	if item.stackable:
		for i in range(MAX_SLOTS):
			if slots[i] != null and slots[i].item_type == item.item_type:
				slots[i].quantity += item.quantity
				inventory_changed.emit()
				return true
	
	# Find empty slot
	for i in range(MAX_SLOTS):
		if slots[i] == null:
			slots[i] = item
			inventory_changed.emit()
			return true
	
	return false  # No space


func remove_item(slot_index: int) -> Item:
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return null
	
	var item = slots[slot_index]
	slots[slot_index] = null
	inventory_changed.emit()
	return item


func get_item(slot_index: int) -> Item:
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return null
	return slots[slot_index]


func get_selected_item() -> Item:
	return get_item(selected_slot)


func select_slot(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < MAX_SLOTS:
		selected_slot = slot_index
		slot_selected.emit(selected_slot)


func has_space() -> bool:
	for slot in slots:
		if slot == null:
			return true
	return false


func swap_item(slot_index: int, new_item: Item) -> Item:
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return new_item
	
	var old_item = slots[slot_index]
	slots[slot_index] = new_item
	inventory_changed.emit()
	return old_item


func get_yarn_amount() -> float:
	for slot in slots:
		if slot != null and slot.item_type == Item.ItemType.YARN:
			return float(slot.quantity)
	return 0.0


func consume_yarn(amount: float) -> bool:
	for i in range(MAX_SLOTS):
		if slots[i] != null and slots[i].item_type == Item.ItemType.YARN:
			slots[i].quantity -= int(amount)
			if slots[i].quantity <= 0:
				slots[i] = null
			inventory_changed.emit()
			return true
	return false


func add_yarn(amount: float) -> void:
	for i in range(MAX_SLOTS):
		if slots[i] != null and slots[i].item_type == Item.ItemType.YARN:
			slots[i].quantity += int(amount)
			inventory_changed.emit()
			return
	
	# No existing yarn, try to add new
	add_item(Item.create_yarn(amount))
