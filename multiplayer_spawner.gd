extends MultiplayerSpawner

@export var network_player: PackedScene

func _ready() -> void:
	if multiplayer.is_server():
		NetworkHandler.request_player_spawn.connect(spawn_player)

func spawn_player(id: int) -> void:
	if has_node(str(id)): 
		return
	
	var player = network_player.instantiate()
	player.name = str(id)
	
	get_node(spawn_path).call_deferred("add_child", player)
	
