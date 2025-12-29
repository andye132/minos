extends Node2D

@onready var enemy_scene := preload("res://scenes/enemy.tscn")
@onready var nav_region := get_parent().get_node("NavigationRegion2D")
@onready var spawn_button := $CanvasLayer/VBoxContainer/SpawnEnemy  # adjust path to your button

func _ready():
	# Connect the button drag/drop signal
	spawn_button.connect("spawn_requested", Callable(self, "_on_spawn_requested"))

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
	var enemy = enemy_scene.instantiate()
	enemy.global_position = pos
	enemy.navigation_region_path = nav_region.get_path()
	add_child(enemy)
