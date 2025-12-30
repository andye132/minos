extends Node2D

const FogOfWarScript = preload("res://scripts/fog_of_war.gd")
const BoonManagerScript = preload("res://scripts/boon_manager.gd")
const PlayerHUDScene = preload("res://scenes/player_hud.tscn")

@onready var player: Player = $Player
@onready var yarn_trail: YarnTrail = $YarnTrail
@onready var puppeteer = $Puppeteer
@onready var puppeteer_camera: Camera2D = $Puppeteer/Camera2D
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D
@onready var minimap: Minimap = $CanvasLayer/Minimap
@onready var inventory_ui: InventoryUI = $CanvasLayer/InventoryUI
@onready var canvas_layer: CanvasLayer = $CanvasLayer

var player_camera: Camera2D
var player_fog: Node2D
var is_player_view: bool = true
var boon_manager: BoonManager
var player_hud: PlayerHUD

# Tile size settings
var base_tile_size: float = 160.0
var world_scale: float = 0.8


func _ready() -> void:
	# Get player's camera
	player_camera = player.get_node_or_null("Camera2D")

	# Connect yarn trail to player
	player.set_yarn_trail(yarn_trail)

	# Setup minimap
	_setup_minimap()

	# Setup player's fog of war
	_setup_player_fog()

	# Setup boon system
	_setup_boon_system()

	# Connect inventory UI
	if inventory_ui:
		inventory_ui.connect_to_inventory(player.get_inventory())
		inventory_ui.update_yarn_display(player.yarn_in_inventory)

	# Connect yarn amount display
	player.yarn_amount_changed.connect(_on_yarn_amount_changed)

	# Set initial view to player
	_switch_to_player_view()

	print("Arena loaded - Press TAB to switch views")


func _on_yarn_amount_changed(amount: float) -> void:
	if inventory_ui:
		inventory_ui.update_yarn_display(amount)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_focus_next"):  # TAB key
		_toggle_view()


func _toggle_view() -> void:
	is_player_view = !is_player_view
	if is_player_view:
		_switch_to_player_view()
	else:
		_switch_to_puppeteer_view()


func _switch_to_player_view() -> void:
	if player_camera:
		player_camera.enabled = true
		player_camera.make_current()
	puppeteer_camera.enabled = false

	# Show player fog, hide puppeteer fog
	if player_fog:
		player_fog.visible = true
	if puppeteer.fog_of_war:
		puppeteer.fog_of_war.visible = false

	# Show player UI
	if canvas_layer:
		canvas_layer.visible = true
	if player_hud:
		player_hud.visible = true

	print("Switched to PLAYER view")


func _switch_to_puppeteer_view() -> void:
	if player_camera:
		player_camera.enabled = false
	puppeteer_camera.enabled = true
	puppeteer_camera.make_current()

	# Center puppeteer camera on maze
	var maze_ref = nav_region.get_node_or_null("Mazetiles") as MazeGen
	if maze_ref:
		var world_tile_size = base_tile_size * world_scale
		var maze_width = maze_ref.x_dim * world_tile_size
		var maze_height = maze_ref.y_dim * world_tile_size
		puppeteer_camera.position = Vector2(maze_width / 2, maze_height / 2)

		# Zoom to fit
		var viewport_size = get_viewport_rect().size
		var zoom_x = viewport_size.x / (maze_width * 1.1)
		var zoom_y = viewport_size.y / (maze_height * 1.1)
		puppeteer_camera.zoom = Vector2(min(zoom_x, zoom_y), min(zoom_x, zoom_y))

	# Hide player fog, show puppeteer fog
	if player_fog:
		player_fog.visible = false
	if puppeteer.fog_of_war:
		puppeteer.fog_of_war.visible = true

	# Hide player UI in puppeteer view
	if canvas_layer:
		canvas_layer.visible = false
	if player_hud:
		player_hud.visible = false

	print("Switched to PUPPETEER view")


func _setup_minimap() -> void:
	if not minimap:
		return

	var maze_ref = nav_region.get_node_or_null("Mazetiles") as MazeGen
	if maze_ref:
		var world_tile_size = base_tile_size * world_scale
		var maze_width = maze_ref.x_dim * world_tile_size
		var maze_height = maze_ref.y_dim * world_tile_size
		var maze_bounds = Vector2(maze_width, maze_height)

		minimap.add_player(player)
		minimap.set_maze_bounds(maze_bounds)
		minimap.set_maze_reference(maze_ref)
		minimap.set_yarn_trail(yarn_trail)


func _setup_player_fog() -> void:
	player_fog = FogOfWarScript.new()
	player_fog.name = "PlayerFogOfWar"
	player_fog.player = player
	player_fog.yarn_trail = yarn_trail

	var maze_ref = nav_region.get_node_or_null("Mazetiles") as MazeGen
	if maze_ref:
		var world_tile_size = base_tile_size * world_scale
		var maze_width = maze_ref.x_dim * world_tile_size
		var maze_height = maze_ref.y_dim * world_tile_size
		player_fog.setup(maze_width, maze_height)

	add_child(player_fog)

	# Connect fog to minimap
	if minimap:
		minimap.set_fog_of_war(player_fog)


func _setup_boon_system() -> void:
	var maze_ref = nav_region.get_node_or_null("Mazetiles") as MazeGen
	if not maze_ref:
		push_warning("Arena: No maze found for boon spawning")
		return

	# Create boon manager
	boon_manager = BoonManagerScript.new()
	boon_manager.name = "BoonManager"
	add_child(boon_manager)

	# Setup with maze and player spawn position
	boon_manager.setup(maze_ref, player.global_position)

	# Create player HUD (includes health, stats, and boons)
	player_hud = PlayerHUDScene.instantiate()
	add_child(player_hud)
	player_hud.setup(player)

	print("Boon system initialized")
