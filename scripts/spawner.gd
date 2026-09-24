extends Node3D

@export var pedestrian_scene: PackedScene
@export var coin_scene: PackedScene
@export var car_scene: PackedScene

var player: Node3D

const LANES: Array[float] = [2.0, 1.0, 0.0, -1.0, -2.0]
const SPAWN_AHEAD_DISTANCE: float = 25.0
const DESPAWN_BEHIND_DISTANCE: float = 5.0
const MAX_SPAWN_Z: float = 90.0

var pedestrian_timer: float = 0.0
const PEDESTRIAN_INTERVAL: float = 1.5

var coin_timer: float = 0.0
const COIN_INTERVAL: float = 2.0

var car_timer: float = 0.0
const CAR_INTERVAL: float = 2.5

# Recently used lanes for pedestrian spawn so coins don't overlap
var last_pedestrian_lanes: Array[int] = []

func _ready() -> void:
	# Initial delay so player starts cleanly
	pedestrian_timer = 0.8
	coin_timer = 1.2
	car_timer = 1.0

func setup(p_player: Node3D) -> void:
	player = p_player

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING or not player:
		return
	
	var player_z: float = player.global_position.z
	
	if player_z < MAX_SPAWN_Z:
		pedestrian_timer -= delta
		if pedestrian_timer <= 0.0:
			pedestrian_timer = PEDESTRIAN_INTERVAL
			_spawn_pedestrians(player_z)
		
		coin_timer -= delta
		if coin_timer <= 0.0:
			coin_timer = COIN_INTERVAL
			_spawn_coin(player_z)
	
	# Background cars keep spawning along track
	car_timer -= delta
	if car_timer <= 0.0:
		car_timer = randf_range(2.0, 3.5)
		_spawn_car(player_z)
	
	_despawn_offscreen(player_z)

func _spawn_pedestrians(player_z: float) -> void:
	if not pedestrian_scene:
		return
	
	var spawn_z := player_z + SPAWN_AHEAD_DISTANCE
	if spawn_z > 98.0:
		return
	
	# Pick 1 or 2 distinct random lanes out of 5
	var count := randi_range(1, 2)
	var available_lanes := [0, 1, 2, 3, 4] # indices in LANES
	available_lanes.shuffle()
	
	last_pedestrian_lanes.clear()
	for i in range(count):
		var lane_idx: int = available_lanes[i]
		last_pedestrian_lanes.append(lane_idx)
		var lane_x: float = LANES[lane_idx]
		
		var ped: Node3D = pedestrian_scene.instantiate()
		ped.position = Vector3(lane_x, 0.0, spawn_z)
		get_parent().add_child(ped)

func _spawn_coin(player_z: float) -> void:
	if not coin_scene:
		return
	
	var spawn_z := player_z + SPAWN_AHEAD_DISTANCE + randf_range(-1.0, 1.0)
	if spawn_z > 98.0:
		return
	
	# Choose lane not occupied by recent pedestrians
	var candidate_lanes: Array[int] = []
	for i in range(5):
		if not last_pedestrian_lanes.has(i):
			candidate_lanes.append(i)
	
	if candidate_lanes.is_empty():
		return
	
	var lane_idx: int = candidate_lanes.pick_random()
	var lane_x: float = LANES[lane_idx]
	
	var coin: Node3D = coin_scene.instantiate()
	coin.position = Vector3(lane_x, 0.4, spawn_z)
	get_parent().add_child(coin)

func _spawn_car(player_z: float) -> void:
	if not car_scene:
		return
	
	# Road lanes at X = -3.2 and X = -4.2
	var road_lanes: Array[float] = [-3.2, -4.2]
	var lane_x: float = road_lanes.pick_random()
	var move_dir: float = -1.0 if lane_x < -3.7 else 1.0
	
	var spawn_z: float = player_z + (35.0 if move_dir < 0.0 else -15.0)
	var car: Node3D = car_scene.instantiate()
	car.position = Vector3(lane_x, 0.25, spawn_z)
	if car.has_method("set"):
		car.set("direction", move_dir)
		car.set("speed", randf_range(6.0, 10.0))
	get_parent().add_child(car)

func _despawn_offscreen(player_z: float) -> void:
	var cutoff_z := player_z - DESPAWN_BEHIND_DISTANCE
	var parent := get_parent()
	
	for child in parent.get_children():
		if child.is_in_group("pedestrians") or child.is_in_group("coins") or child.is_in_group("cars"):
			if child.global_position.z < cutoff_z or child.global_position.z > player_z + 45.0:
				child.queue_free()
