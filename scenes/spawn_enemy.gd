extends Button

signal spawn_requested(position: Vector2)

var dragging := false
var drag_sprite: Sprite2D = null

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			start_drag()
		else:
			end_drag()

	if dragging and event is InputEventMouseMotion:
		_update_drag_preview_position()

func start_drag():
	if dragging:
		return
	dragging = true

	# Create a drag preview sprite in the world
	drag_sprite = Sprite2D.new()
	drag_sprite.texture = preload("res://grass.png")
	get_tree().current_scene.add_child(drag_sprite)

	_update_drag_preview_position()

func _update_drag_preview_position():
	# Use Camera2D if possible for zoom-safe coordinates
	var camera := get_viewport().get_camera_2d()
	var world_mouse_pos := camera.get_global_mouse_position() if camera else get_global_mouse_position()

	if drag_sprite:
		drag_sprite.global_position = world_mouse_pos

func end_drag():
	if not dragging:
		return
	dragging = false

	var camera := get_viewport().get_camera_2d()
	var spawn_pos := camera.get_global_mouse_position() if camera else get_global_mouse_position()

	emit_signal("spawn_requested", spawn_pos)

	if drag_sprite:
		drag_sprite.queue_free()
		drag_sprite = null
