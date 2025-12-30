extends Node2D

const FogOfWarScript = preload("res://scripts/fog_of_war.gd")
const BoonManagerScript = preload("res://scripts/boon_manager.gd")
const ActiveBoonsUIScene = preload("res://scenes/active_boons_ui.tscn")

@onready var player: Player = $Player
@onready var yarn_trail: YarnTrail = $YarnTrail
@onready var puppeteer = $Puppeteer
@onready var puppeteer_camera: Camera2D = $Puppeteer/Camera2D
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D

var player_camera: Camera2D
var player_fog: Node2D
var is_player_view: bool = true
var boon_manager: BoonManager
var active_boons_ui: ActiveBoonsUI

# Tile size settings
var base_tile_size: float = 160.0
var world_scale: float = 0.8


func _ready() -> void:
	# Get player's camera
	player_camera = player.get_node_or_null("Camera2D")

	# Connect yarn trail to player
	player.set_yarn_trail(yarn_trail)

	# Setup player's fog of war
	_setup_player_fog()

	# Setup boon system
	_setup_boon_system()

	# Set initial view to player
	_switch_to_player_view()

	print("Arena loaded - Press TAB to switch views")


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

	print("Switched to PUPPETEER view")


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

	# Create boons UI
	var ui_layer = $UI
	if ui_layer:
		active_boons_ui = ActiveBoonsUIScene.instantiate()
		ui_layer.add_child(active_boons_ui)
		active_boons_ui.setup(player)

	print("Boon system initialized")
