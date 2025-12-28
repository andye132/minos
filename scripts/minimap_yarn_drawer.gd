extends Node2D
class_name MinimapYarnDrawer

var minimap: Minimap

var yarn_color: Color = Color(1.0, 0.7, 0.2, 1.0)
var yarn_color_broken: Color = Color(0.4, 0.3, 0.2, 0.5)
var yarn_width: float = 8.0  # Thicker for visibility
var glow_radius: float = 40.0  # Bigger glow
var glow_color: Color = Color(1.0, 0.8, 0.3, 0.6)  # Brighter


func _ready() -> void:
	minimap = get_parent().get_parent() as Minimap


func _draw() -> void:
	if not minimap:
		return
	
	for player in minimap.players:
		if is_instance_valid(player):
			var yarn_trail = player.get_yarn_trail()
			if yarn_trail:
				var points = yarn_trail.get_points()
				var is_continuous = yarn_trail.is_continuous
				
				if points.size() >= 2:
					var color = yarn_color if is_continuous else yarn_color_broken
					
					# Draw glow if continuous
					if is_continuous:
						for point in points:
							draw_circle(point, glow_radius, glow_color)
					
					draw_polyline(PackedVector2Array(points), color, yarn_width, true)
