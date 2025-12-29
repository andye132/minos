extends Node2D

const FogOfWarScript = preload("res://scripts/fog_of_war.gd")

@onready var player: Player = $Player
@onready var yarn_trail: YarnTrail = $YarnTrail
@onready var minimap: Minimap = $CanvasLayer/Minimap
@onready var inventory_ui: InventoryUI = $CanvasLayer/InventoryUI
@onready var maze: MazeGen = $Mazetiles

var fog_of_war: Node2D


func _ready() -> void:
	# Connect yarn trail to player
	player.set_yarn_trail(yarn_trail)

	# Calculate maze bounds from the maze generator
	# Maze uses 16x16 tiles scaled by 5x (check main.tscn Mazetiles scale)
	var tile_size = 16.0 * 5.0  # 80 pixels per tile
	var maze_width = maze.x_dim * tile_size
	var maze_height = maze.y_dim * tile_size
	var maze_bounds = Vector2(maze_width, maze_height)

	# Connect player to minimap with correct maze bounds
	minimap.add_player(player)
	minimap.set_maze_bounds(maze_bounds)
	minimap.set_maze_reference(maze)
	minimap.set_yarn_trail(yarn_trail)

	# Setup fog of war
	fog_of_war = FogOfWarScript.new()
	fog_of_war.name = "FogOfWar"
	add_child(fog_of_war)
	fog_of_war.player = player
	fog_of_war.yarn_trail = yarn_trail
	fog_of_war.setup(maze_width, maze_height)

	# Connect fog of war to minimap
	minimap.set_fog_of_war(fog_of_war)

	# Connect inventory UI
	inventory_ui.connect_to_inventory(player.get_inventory())

	# Connect yarn amount display
	player.yarn_amount_changed.connect(_on_yarn_amount_changed)

	# Initial yarn display
	inventory_ui.update_yarn_display(player.yarn_in_inventory)


func _on_yarn_amount_changed(amount: float) -> void:
	inventory_ui.update_yarn_display(amount)
