extends Node2D
class_name Puppeteer

const PuppeteerFogOfWarScript = preload("res://scripts/puppeteer_fog_of_war.gd")

@onready var enemy_scene := preload("res://scenes/enemy.tscn")
@onready var spawn_button := $CanvasLayer/PlayUI/SpawnEnemy
@onready var camera := $Camera2D

@onready var start_button = $CanvasLayer/LobbyUI/StartButton
@onready var lobby_ui = $CanvasLayer/LobbyUI
@onready var play_ui = $CanvasLayer/PlayUI

var game_started := false

var nav_region: NavigationRegion2D
var maze_ref: MazeGen
var fog_of_war: PuppeteerFogOfWar

# Tile size settings (should match maze)
var base_tile_size: float = 160.0
var world_scale: float = 0.8

signal start_game_signal


func _ready():
	# Get references after node is in tree
	nav_region = get_parent().get_node_or_null("NavigationRegion2D")
	if nav_region:
		maze_ref = nav_region.get_node_or_null("Mazetiles") as MazeGen
	
	# Disable game logic until start
	if nav_region:
		nav_region.set_process(false)
		nav_region.visible = false
	if maze_ref:
		maze_ref.set_process(false)
		maze_ref.visible = false

	# Show lobby UI
	lobby_ui.visible = true
	play_ui.visible = false

	# Connect start button
	start_button.pressed.connect(_on_start_button_pressed)

	
func start_game():
	if nav_region:
		nav_region.set_process(true)
		nav_region.visible = true
	if maze_ref:
		maze_ref.set_process(true)
		maze_ref.visible = true
		maze_ref.start_game()

	# Connect the button drag/drop signal
	spawn_button.connect("spawn_requested", Callable(self, "_on_spawn_requested"))

	# Setup camera to show full maze
	_setup_camera()

	# Setup fog of war for puppeteer view
	_setup_fog_of_war()

func _on_spawn_requested(pos: Vector2):
	spawn_enemy(pos)

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		# Left-click → set target for all enemies
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var pos = get_global_mouse_position()
			for e in get_children():
				if e is CharacterBody2D and e.has_method("set_target"):
					e.set_target(pos)

func spawn_enemy(pos: Vector2):
	if not nav_region:
		return

	var enemy = enemy_scene.instantiate()
	enemy.global_position = pos
	enemy.navigation_region_path = nav_region.get_path()
	add_child(enemy)

	# Register enemy as vision provider for fog of war
	if fog_of_war:
		fog_of_war.add_vision_provider(enemy)

	# Clean up vision when enemy is removed
	enemy.tree_exiting.connect(func(): _on_enemy_removed(enemy))


func _on_enemy_removed(enemy: Node2D) -> void:
	if fog_of_war and is_instance_valid(fog_of_war):
		fog_of_war.remove_vision_provider(enemy)


func _setup_camera() -> void:
	if not camera or not maze_ref:
		return

	# Calculate maze dimensions in world coordinates
	var world_tile_size = base_tile_size * world_scale  # 128 pixels per tile
	var maze_width = maze_ref.x_dim * world_tile_size
	var maze_height = maze_ref.y_dim * world_tile_size

	# Center camera on maze
	camera.position = Vector2(maze_width / 2, maze_height / 2)

	# Calculate zoom to fit entire maze on screen with some padding
	var viewport_size = get_viewport_rect().size
	var padding = 1.1  # 10% padding
	var zoom_x = viewport_size.x / (maze_width * padding)
	var zoom_y = viewport_size.y / (maze_height * padding)
	var zoom_val = min(zoom_x, zoom_y)

	camera.zoom = Vector2(zoom_val, zoom_val)


func _setup_fog_of_war() -> void:
	if not nav_region:
		print("Puppeteer fog of war: WARNING - nav_region is null, can't add fog!")
		return

	fog_of_war = PuppeteerFogOfWarScript.new()
	fog_of_war.name = "PuppeteerFogOfWar"

	if maze_ref:
		fog_of_war.setup(maze_ref)
		print("Puppeteer fog of war: maze_ref set, dimensions: ", maze_ref.x_dim, "x", maze_ref.y_dim)
	else:
		print("Puppeteer fog of war: WARNING - maze_ref is null!")

	# Add fog as sibling to Mazetiles (inside NavigationRegion2D) so it renders on top
	nav_region.add_child(fog_of_war)
	print("Puppeteer fog of war added to NavigationRegion2D")


func _on_start_button_pressed() -> void:
	emit_signal("start_game_signal")
	lobby_ui.visible = false
	play_ui.visible = true
	start_game()
