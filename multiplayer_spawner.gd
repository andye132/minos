extends MultiplayerSpawner

@export var network_player: PackedScene

func _ready() -> void:
	if multiplayer.is_server():
		NetworkHandler.request_player_spawn.connect(spawn_player)
		# If you are the host, spawn yourself now
		if multiplayer.get_unique_id() == 1:
			spawn_player(1)

func spawn_player(id: int) -> void:
	if has_node(str(id)): 
		return
	
	var player = network_player.instantiate()
	player.name = str(id)
	
	get_node(spawn_path).add_child(player)
	
