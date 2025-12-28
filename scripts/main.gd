extends Node2D

@onready var player: Player = $Player
@onready var yarn_trail: YarnTrail = $YarnTrail
@onready var minimap: Minimap = $CanvasLayer/Minimap
@onready var inventory_ui: InventoryUI = $CanvasLayer/InventoryUI


func _ready() -> void:
	# Connect yarn trail to player
	player.set_yarn_trail(yarn_trail)
	
	# Connect player to minimap
	minimap.add_player(player)
	minimap.maze_bounds = Vector2(800, 600)
	
	# Connect inventory UI
	inventory_ui.connect_to_inventory(player.get_inventory())
	
	# Connect yarn amount display
	player.yarn_amount_changed.connect(_on_yarn_amount_changed)
	
	# Initial yarn display
	inventory_ui.update_yarn_display(player.yarn_in_inventory)


func _on_yarn_amount_changed(amount: float) -> void:
	inventory_ui.update_yarn_display(amount)
