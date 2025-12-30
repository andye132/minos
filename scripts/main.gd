extends Node2D

const FogOfWarScript = preload("res://scripts/fog_of_war.gd")
const BoonManagerScript = preload("res://scripts/boon_manager.gd")
const PlayerHUDScene = preload("res://scenes/player_hud.tscn")

@onready var player: Player = $Player
@onready var yarn_trail: YarnTrail = $YarnTrail
@onready var minimap: Minimap = $CanvasLayer/Minimap
@onready var inventory_ui: InventoryUI = $CanvasLayer/InventoryUI
@onready var maze: MazeGen = $Mazetiles
@onready var canvas_layer: CanvasLayer = $CanvasLayer

var fog_of_war: Node2D
var boon_manager: BoonManager
var player_hud: PlayerHUD


func _ready() -> void:
	# Connect yarn trail to player
	player.set_yarn_trail(yarn_trail)

	# Calculate maze bounds from the maze generator
	# Maze uses 160x160 tiles scaled by 0.8x (check main.tscn Mazetiles scale)
	var tile_size = 160.0 * 0.8  # 128 pixels per tile
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

	# Setup boon system
	_setup_boon_system()

	# Connect inventory UI
	inventory_ui.connect_to_inventory(player.get_inventory())

	# Connect yarn amount display
	player.yarn_amount_changed.connect(_on_yarn_amount_changed)

	# Initial yarn display
	inventory_ui.update_yarn_display(player.yarn_in_inventory)


func _on_yarn_amount_changed(amount: float) -> void:
	inventory_ui.update_yarn_display(amount)


func _setup_boon_system() -> void:
	# Create boon manager
	boon_manager = BoonManagerScript.new()
	boon_manager.name = "BoonManager"
	add_child(boon_manager)

	# Setup with maze and player spawn position
	boon_manager.setup(maze, player.global_position)

	# Create player HUD (includes health, stats, and boons)
	player_hud = PlayerHUDScene.instantiate()
	add_child(player_hud)
	player_hud.setup(player)

	print("Boon system initialized - ", boon_manager.get_remaining_boon_count(), " boons spawned")
