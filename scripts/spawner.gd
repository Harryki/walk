class_name Spawner
extends Node3D

@export var pedestrian_scene: PackedScene
@export var coin_scene: PackedScene
@export var car_scene: PackedScene
@export var npc_spawn_table: SpawnTable
@export var item_spawn_table: SpawnTable

var player: Player

const LANES: Array[float] = [2.0, 1.0, 0.0, -1.0, -2.0]
const SPAWN_AHEAD_DISTANCE: float = 25.0
const DESPAWN_BEHIND_DISTANCE: float = 6.0

var pedestrian_timer: float = 0.8
var coin_timer: float = 1.0
const ITEM_INTERVAL_MIN: float = 1.6
const ITEM_INTERVAL_MAX: float = 2.4
var last_item_spawn_z: float = -50.0
const MIN_ITEM_DISTANCE: float = 8.0

var car_timer: float = 1.0

# Recently used lanes for pedestrian spawn so coins don't overlap
var last_pedestrian_lanes: Array[int] = []

# Dedicated active entity tracking to avoid full scene tree traversals
var _active_entities: Array[Node3D] = []

func setup(p_player: Player) -> void:
	player = p_player

func _get_pedestrian_interval(player_z: float) -> float:
	# Scaled interval: 1.6s at 0m down to 0.85s at 600m+
	var t := clampf(player_z / 600.0, 0.0, 1.0)
	return lerpf(1.6, 0.85, t)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING or not is_instance_valid(player):
		return
	
	var player_z: float = player.global_position.z
	
	pedestrian_timer -= delta
	if pedestrian_timer <= 0.0:
		pedestrian_timer = _get_pedestrian_interval(player_z)
		_spawn_pedestrians(player_z)
	
	coin_timer -= delta
	if coin_timer <= 0.0:
		coin_timer = randf_range(ITEM_INTERVAL_MIN, ITEM_INTERVAL_MAX)
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
	
	# Difficulty-scaled count: early game 1~2, later game 2~3 (always at least 2 safe lanes out of 5)
	var count := 1
	if player_z >= 300.0:
		count = 3 if randf() < 0.35 else 2
	elif player_z >= 120.0:
		count = 2 if randf() < 0.7 else 1
	else:
		count = randi_range(1, 2)
	
	var available_lanes: Array[int] = [0, 1, 2, 3, 4]
	available_lanes.shuffle()
	
	last_pedestrian_lanes.clear()
	for i in range(count):
		var lane_idx: int = available_lanes[i]
		last_pedestrian_lanes.append(lane_idx)
		var lane_x: float = LANES[lane_idx]
		
		var chosen_scene := pedestrian_scene
		var chosen_data: NPCData = null
		if npc_spawn_table:
			var res := npc_spawn_table.pick_random(player_z)
			if res is NPCData and res.scene:
				chosen_scene = res.scene
				chosen_data = res
		
		if not chosen_scene:
			continue
			
		var ped := chosen_scene.instantiate() as Node3D
		ped.position = Vector3(lane_x, 0.0, spawn_z)
		if chosen_data and ped.has_method(&"apply_data"):
			ped.apply_data(chosen_data)
		add_child(ped)
		_active_entities.append(ped)

func _spawn_coin(player_z: float) -> void:
	var spawn_z := player_z + SPAWN_AHEAD_DISTANCE + randf_range(-1.0, 1.0)
	if absf(spawn_z - last_item_spawn_z) < MIN_ITEM_DISTANCE:
		return
	
	# Prefer empty lanes not currently occupied by pedestrians ahead
	var candidate_lanes: Array[int] = []
	for i in range(5):
		if not last_pedestrian_lanes.has(i):
			candidate_lanes.append(i)
	
	if candidate_lanes.is_empty():
		return
	
	var lane_idx: int = candidate_lanes.pick_random()
	var lane_x: float = LANES[lane_idx]
	
	var default_scene := coin_scene
	var chosen_scene := default_scene
	var chosen_data: ItemData = null
	if item_spawn_table:
		var res := item_spawn_table.pick_random(player_z)
		if res is ItemData and res.scene:
			chosen_scene = res.scene
			chosen_data = res
	
	if not chosen_scene:
		return
		
	var item := chosen_scene.instantiate() as Node3D
	item.position = Vector3(lane_x, 0.4, spawn_z)
	if chosen_data and item.has_method(&"apply_data"):
		item.apply_data(chosen_data)
	add_child(item)
	_active_entities.append(item)
	last_item_spawn_z = spawn_z

func _spawn_car(player_z: float) -> void:
	if not car_scene:
		return
	
	var forward: bool = randf() > 0.5
	var spawn_z: float = player_z + (SPAWN_AHEAD_DISTANCE + 10.0 if forward else -DESPAWN_BEHIND_DISTANCE - 5.0)
	var speed: float = randf_range(8.0, 14.0)
	var car_dir: float = 1.0 if forward else -1.0
	
	var car = car_scene.instantiate()
	car.position = Vector3(-3.9, 0.0, spawn_z)
	if car.has_method(&"setup_ambient"):
		car.setup_ambient(speed, car_dir)
	elif car.has_method(&"setup"):
		car.setup(speed, car_dir)
	add_child(car)
	_active_entities.append(car)

func _despawn_offscreen(player_z: float) -> void:
	var cutoff_behind := player_z - DESPAWN_BEHIND_DISTANCE
	var cutoff_ahead := player_z + SPAWN_AHEAD_DISTANCE + 25.0
	
	var valid_entities: Array[Node3D] = []
	for entity in _active_entities:
		if not is_instance_valid(entity):
			continue
		var z := entity.global_position.z
		if z < cutoff_behind or z > cutoff_ahead:
			entity.queue_free()
		else:
			valid_entities.append(entity)
	_active_entities = valid_entities
