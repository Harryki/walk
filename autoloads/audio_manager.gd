extends Node

## Manages global audio buses, background ambience, and SFX routing.

const AMBIENCE_STREAM: AudioStream = preload("res://assets/audio/ambience/street_ambience.mp3")

var ambience_player: AudioStreamPlayer = null
var ambience_tween: Tween

const BUS_MASTER := &"Master"
const BUS_AMBIENCE := &"Ambience"
const BUS_PLAYER_SFX := &"PlayerSFX"
const BUS_SFX := &"SFX"

# Pool of generic SFX players
const SFX_POOL_SIZE := 8
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

# Pool of 3D spatial SFX players
const SPATIAL_POOL_SIZE := 8
var _spatial_pool: Array[AudioStreamPlayer3D] = []
var _spatial_index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Verify audio buses exist
	_ensure_buses_configured()
	
	# Initialize reusable SFX player pools
	_init_sfx_pools()
	
	# Setup background street ambience player
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "StreetAmbiencePlayer"
	ambience_player.bus = BUS_AMBIENCE
	ambience_player.stream = AMBIENCE_STREAM
	add_child(ambience_player)
	
	# Start ambient sound
	ambience_player.play()
	
	# Connect to interior transition events for smooth ambient ducking
	GameManager.interior_entering.connect(_on_interior_entering)
	GameManager.interior_exited.connect(_on_interior_exited)
	GameManager.game_lost.connect(_on_game_ended)
	GameManager.game_won.connect(_on_game_ended)

func _init_sfx_pools() -> void:
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "PooledSFX_%d" % i
		p.bus = BUS_SFX
		add_child(p)
		_sfx_pool.append(p)
	
	for i in range(SPATIAL_POOL_SIZE):
		var sp := AudioStreamPlayer3D.new()
		sp.name = "PooledSpatialSFX_%d" % i
		sp.bus = BUS_SFX
		sp.unit_size = 5.0
		sp.max_distance = 40.0
		add_child(sp)
		_spatial_pool.append(sp)

## Plays 2D / non-positional sound effect through specified bus
func play_sfx(stream: AudioStream, bus_name: StringName = BUS_SFX, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not stream or _sfx_pool.is_empty():
		return
	var player := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	player.stream = stream
	player.bus = bus_name
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()

## Plays 3D positional sound effect at given world coordinate through specified bus
func play_spatial_sfx(stream: AudioStream, global_pos: Vector3, bus_name: StringName = BUS_SFX, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not stream or _spatial_pool.is_empty():
		return
	var player := _spatial_pool[_spatial_index]
	_spatial_index = (_spatial_index + 1) % _spatial_pool.size()
	player.global_position = global_pos
	player.stream = stream
	player.bus = bus_name
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()

func _ensure_buses_configured() -> void:
	# Check if default buses are registered; if not present in runtime layout, add them dynamically
	for bus_name in [BUS_AMBIENCE, BUS_PLAYER_SFX, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)

func _on_interior_entering(_shop: Node3D) -> void:
	# Smoothly duck outside street ambience when entering indoor shop
	if not ambience_player:
		return
	if ambience_tween and ambience_tween.is_valid():
		ambience_tween.kill()
	ambience_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ambience_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	ambience_tween.tween_property(ambience_player, "volume_db", -18.0, 0.8)

func _on_interior_exited() -> void:
	# Restore street ambience to full volume when returning to outside sidewalk
	if not ambience_player:
		return
	if ambience_tween and ambience_tween.is_valid():
		ambience_tween.kill()
	ambience_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ambience_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	ambience_tween.tween_property(ambience_player, "volume_db", 0.0, 0.8)

func _on_game_ended(_arg1, _arg2 = null, _arg3 = null) -> void:
	# Gently fade ambience slightly on game over / victory
	if not ambience_player:
		return
	if ambience_tween and ambience_tween.is_valid():
		ambience_tween.kill()
	ambience_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ambience_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	ambience_tween.tween_property(ambience_player, "volume_db", -8.0, 1.2)

## Bus Volume Control Helpers (linear 0.0 ~ 1.0)
func set_bus_volume_linear(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		if linear <= 0.001:
			AudioServer.set_bus_mute(idx, true)
		else:
			AudioServer.set_bus_mute(idx, false)
			AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.001, 1.0)))

func get_bus_volume_linear(bus_name: StringName) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		if AudioServer.is_bus_mute(idx):
			return 0.0
		return db_to_linear(AudioServer.get_bus_volume_db(idx))
	return 1.0

func set_bus_mute(bus_name: StringName, mute: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, mute)
