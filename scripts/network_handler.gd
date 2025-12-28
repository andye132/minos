extends Node

# This is the custom signal your Spawner will listen for
signal request_player_spawn(id: int)

const IP_ADDRESS := "127.0.0.1"
const PORT := 8910
const MAX_PLAYERS := 32

var peer: ENetMultiplayerPeer

func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		push_error("Failed to start server: %s" % err)
		return

	multiplayer.multiplayer_peer = peer
	
	# Connect the event for whenever a NEW peer joins
	multiplayer.peer_connected.connect(_on_peer_connected)
	
	print("Server started on port ", PORT)
	
	request_player_spawn.emit(1)

func start_client() -> void:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(IP_ADDRESS, PORT)
	if err != OK:
		push_error("Failed to start client: %s" % err)
		return

	multiplayer.multiplayer_peer = peer
	print("Client connecting to ", IP_ADDRESS)

func _on_peer_connected(id: int) -> void:
	# Tell the spawner to create a character for the joining peer
	request_player_spawn.emit(id)
