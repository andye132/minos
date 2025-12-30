extends MultiplayerSpawner

@export var network_player: PackedScene
@export var network_puppeteer: PackedScene

# Keep track of all players
var players: Array = []

func _ready() -> void:
	if multiplayer.is_server():
		NetworkHandler.request_player_spawn.connect(spawn_player)
		NetworkHandler.request_puppeteer_spawn.connect(spawn_puppeteer)
		

# Spawn a regular puppet
func spawn_player(id: int) -> void:
	if has_node(str(id)):
		return
	
	var player = network_player.instantiate()
	player.name = str(id)
	get_node(spawn_path).call_deferred("add_child", player)

	# Add to local player tracking array
	players.append(player)

# Spawn the puppeteer
func spawn_puppeteer(id: int) -> void:
	if has_node(str(id)):
		return
	
	var player = network_puppeteer.instantiate()
	player.name = str(id)
	get_node(spawn_path).call_deferred("add_child", player)
	player.start_game_signal.connect(_on_start_game)  # Host triggers this

	players.append(player)

# Called by host to start the game
func _on_start_game():
	# Generate a seed if needed for maze sync
	var seed = randi()

	# Call RPC manually on each player instance
	for p in players:
		if is_instance_valid(p):
			p.rpc("rpc_start_game")
