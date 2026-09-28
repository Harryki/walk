class_name CrosswalkChunk
extends BaseChunk

@export var tier: int = 1 # 1: 1-lane, 2: 2-lane, 3: 4-lane

const CROSS_CAR_SCENE: PackedScene = preload("res://scenes/environment/car.tscn")
const TRAFFIC_LIGHT_SCENE: PackedScene = preload("res://scenes/environment/traffic_light.tscn")

var traffic_light: TrafficLight = null
var exit_traffic_light: TrafficLight = null
var entry_zone: Area3D = null
var exit_zone: Area3D = null
var cross_z_start: float = 10.0
var cross_z_end: float = 15.0
var cross_lanes: Array[Dictionary] = [] # [{z: float, dir: float, timer: float, interval: float, speed: float}]
var active_cross_cars: Array[Car] = []

func _ready() -> void:
	_ensure_references()
	if cross_lanes.is_empty():
		_configure_tier()
		_spawn_initial_waiting_cars()

func _ensure_references() -> void:
	if traffic_light == null:
		traffic_light = get_node_or_null("TrafficLight") as TrafficLight
	if exit_traffic_light == null:
		exit_traffic_light = get_node_or_null("ExitTrafficLight") as TrafficLight
	if entry_zone == null:
		entry_zone = get_node_or_null("EntryStopZone") as Area3D
	if exit_zone == null:
		exit_zone = get_node_or_null("ExitStopZone") as Area3D
	
	if traffic_light and exit_traffic_light:
		if not traffic_light.state_changed.is_connected(_on_traffic_light_state_changed):
			traffic_light.state_changed.connect(_on_traffic_light_state_changed)

func _on_traffic_light_state_changed(new_state: int) -> void:
	if is_instance_valid(exit_traffic_light):
		exit_traffic_light._set_state(new_state as TrafficLight.LightState)

func setup_crosswalk(p_chunk_index: int, p_tier: int = 1) -> void:
	chunk_index = p_chunk_index
	tier = clampi(p_tier, 1, 3)
	_ensure_references()
	_configure_tier()
	_apply_tier_to_scene()
	_spawn_initial_waiting_cars()

func _configure_tier() -> void:
	cross_lanes.clear()
	match tier:
		1: # 1-lane one-way street (5m wide, moving -X to +X)
			cross_z_start = 10.0
			cross_z_end = 15.0
			cross_lanes.append({
				"z": 12.5,
				"dir": 1.0,
				"timer": 0.3,
				"min_interval": 1.0,
				"max_interval": 1.6,
				"speed": 20.0
			})
		2: # 2-lane two-way street (9m wide: lane 1 +X, lane 2 -X)
			cross_z_start = 8.0
			cross_z_end = 17.0
			cross_lanes.append({
				"z": 10.25,
				"dir": 1.0,
				"timer": 0.2,
				"min_interval": 0.9,
				"max_interval": 1.5,
				"speed": 23.0
			})
			cross_lanes.append({
				"z": 14.75,
				"dir": -1.0,
				"timer": 0.7,
				"min_interval": 0.9,
				"max_interval": 1.5,
				"speed": 23.0
			})
		3: # 4-lane highway boulevard (15m wide: 2 lanes +X, 2 lanes -X)
			cross_z_start = 5.0
			cross_z_end = 20.0
			cross_lanes.append({
				"z": 6.8,
				"dir": 1.0,
				"timer": 0.2,
				"min_interval": 0.8,
				"max_interval": 1.3,
				"speed": 26.0
			})
			cross_lanes.append({
				"z": 10.2,
				"dir": 1.0,
				"timer": 0.6,
				"min_interval": 0.8,
				"max_interval": 1.3,
				"speed": 26.0
			})
			cross_lanes.append({
				"z": 14.8,
				"dir": -1.0,
				"timer": 0.4,
				"min_interval": 0.8,
				"max_interval": 1.3,
				"speed": 26.0
			})
			cross_lanes.append({
				"z": 18.2,
				"dir": -1.0,
				"timer": 0.8,
				"min_interval": 0.8,
				"max_interval": 1.3,
				"speed": 26.0
			})

func _apply_tier_to_scene() -> void:
	if tier == 1:
		return # Tier 1 is already accurately represented by the scene layout
	
	var cross_width: float = cross_z_end - cross_z_start
	var cross_center_z: float = cross_z_start + cross_width / 2.0
	var exit_len: float = CHUNK_LENGTH - cross_z_end
	
	# Adjust CrossRoad
	var cross_road := get_node_or_null("Ground/CrossRoad") as MeshInstance3D
	if cross_road and cross_road.mesh is BoxMesh:
		cross_road.mesh = cross_road.mesh.duplicate()
		(cross_road.mesh as BoxMesh).size.z = cross_width
		cross_road.position.z = cross_center_z
	
	# Adjust Entry & Exit Sidewalks
	var sw_entry := get_node_or_null("Ground/EntrySidewalk") as MeshInstance3D
	if sw_entry and sw_entry.mesh is BoxMesh:
		sw_entry.mesh = sw_entry.mesh.duplicate()
		(sw_entry.mesh as BoxMesh).size.z = cross_z_start
		sw_entry.position.z = cross_z_start / 2.0
		
	var sw_exit := get_node_or_null("Ground/ExitSidewalk") as MeshInstance3D
	if sw_exit and sw_exit.mesh is BoxMesh:
		sw_exit.mesh = sw_exit.mesh.duplicate()
		(sw_exit.mesh as BoxMesh).size.z = exit_len
		sw_exit.position.z = cross_z_end + exit_len / 2.0
	
	# Adjust Curbs
	for curb_name in ["EntryCurbLeft", "EntryCurbRight"]:
		var curb := get_node_or_null("Ground/" + curb_name) as MeshInstance3D
		if curb and curb.mesh is BoxMesh:
			curb.mesh = curb.mesh.duplicate()
			(curb.mesh as BoxMesh).size.z = cross_z_start
			curb.position.z = cross_z_start / 2.0
			
	for curb_name in ["ExitCurbLeft", "ExitCurbRight"]:
		var curb := get_node_or_null("Ground/" + curb_name) as MeshInstance3D
		if curb and curb.mesh is BoxMesh:
			curb.mesh = curb.mesh.duplicate()
			(curb.mesh as BoxMesh).size.z = exit_len
			curb.position.z = cross_z_end + exit_len / 2.0
	
	# Adjust Zebra Stripes (Horizontal stripes along X, spaced along Z)
	var stripes_node := get_node_or_null("ZebraStripes")
	if stripes_node:
		for child in stripes_node.get_children():
			child.queue_free()
		
		var step: float = 0.9
		var curr_z: float = cross_z_start + 0.7
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(4.2, 0.02, 0.45)
		
		var mat_zebra := StandardMaterial3D.new()
		mat_zebra.albedo_color = Color(0.96, 0.96, 0.98)
		mat_zebra.roughness = 0.5
		
		while curr_z <= cross_z_end - 0.5:
			var stripe := MeshInstance3D.new()
			stripe.mesh = stripe_mesh
			stripe.material_override = mat_zebra
			stripe.position = Vector3(0.0, -0.04, curr_z)
			stripes_node.add_child(stripe)
			curr_z += step
	
	# Adjust Stop Lines
	var stop_left := get_node_or_null("StopLines/CarStopLineLeft") as MeshInstance3D
	if stop_left and stop_left.mesh is BoxMesh:
		stop_left.mesh = stop_left.mesh.duplicate()
		(stop_left.mesh as BoxMesh).size.z = cross_width
		stop_left.position.z = cross_center_z
		
	var stop_right := get_node_or_null("StopLines/CarStopLineRight") as MeshInstance3D
	if stop_right and stop_right.mesh is BoxMesh:
		stop_right.mesh = stop_right.mesh.duplicate()
		(stop_right.mesh as BoxMesh).size.z = cross_width
		stop_right.position.z = cross_center_z
		
	var ped_entry := get_node_or_null("StopLines/PedestrianStopLineEntry") as MeshInstance3D
	if ped_entry:
		ped_entry.position.z = cross_z_start - 0.2
		
	var ped_exit := get_node_or_null("StopLines/PedestrianStopLineExit") as MeshInstance3D
	if ped_exit:
		ped_exit.position.z = cross_z_end + 0.2
	
	# Adjust Traffic Lights
	if traffic_light:
		traffic_light.position.z = cross_z_start - 0.4
	if exit_traffic_light:
		exit_traffic_light.position.z = cross_z_end + 0.4
		
	# Adjust Stop Zones
	if entry_zone:
		entry_zone.position.z = cross_z_start - 0.6
	if exit_zone:
		exit_zone.position.z = cross_z_end + 0.6

func _spawn_initial_waiting_cars() -> void:
	# Clear previous cars if any
	for car in active_cross_cars:
		if is_instance_valid(car):
			car.queue_free()
	active_cross_cars.clear()
	
	# Spawn cars waiting at the stop lines while traffic light is green
	for lane in cross_lanes:
		_spawn_cross_car(lane, true)

func _physics_process(delta: float) -> void:
	if not traffic_light:
		return
	
	var is_red: bool = traffic_light.is_red()
	
	# Update existing cars to obey current traffic signal
	var valid_cars: Array[Car] = []
	for car in active_cross_cars:
		if is_instance_valid(car):
			car.set_signal_stop(!is_red) # During pedestrian green/warning, cars must stop before crosswalk!
			valid_cars.append(car)
	active_cross_cars = valid_cars
	
	# Cross-traffic cars rush when traffic light is RED (Pedestrian Red = Road Green)
	for lane in cross_lanes:
		if is_red:
			lane["timer"] -= delta
			if lane["timer"] <= 0.0:
				_spawn_cross_car(lane, false)
				lane["timer"] = randf_range(lane["min_interval"], lane["max_interval"])
		else:
			# In green/warning, reset timers so cars rush out as soon as light turns red
			lane["timer"] = randf_range(0.2, 0.5)
			
			# Ensure each lane has a car waiting at the stop line
			var has_waiting_car := false
			for car in active_cross_cars:
				if is_instance_valid(car) and absf(car.position.z - lane["z"]) < 0.5:
					has_waiting_car = true
					break
			if not has_waiting_car:
				_spawn_cross_car(lane, true)
	
	# Stop player and pedestrians at both crosswalk entry points when RED
	_process_signal_stops(is_red)

func _process_signal_stops(is_red: bool) -> void:
	if not is_red:
		return
	
	# 1. Entry zone check: ONLY for Player advancing towards crosswalk (+Z direction)
	# If player has already stepped into the crosswalk or crossed it (rel_z >= cross_z_start - 0.15), DO NOT STOP!
	var player_node := get_tree().get_first_node_in_group(&"player") as Player
	if not player_node:
		var p_cand := get_viewport().get_node_or_null("Main/Player")
		if p_cand is Player:
			player_node = p_cand
	
	if player_node:
		var rel_player_z := player_node.global_position.z - global_position.z
		# Only stop if player is strictly BEFORE the crosswalk entry line
		if rel_player_z >= cross_z_start - 1.2 and rel_player_z < cross_z_start - 0.15:
			player_node.start_crosswalk_wait(traffic_light)
	
	# 2. Exit zone check: for Pedestrians walking towards crosswalk (-Z direction)
	# If pedestrian is approaching crosswalk stop line while RED, stop them before entering the road!
	for node in get_tree().get_nodes_in_group(&"pedestrians"):
		var ped := node as Pedestrian
		if not is_instance_valid(ped) or ped.is_dead:
			continue
		var rel_ped_z := ped.global_position.z - global_position.z
		# Only stop if pedestrian is approaching from the exit sidewalk (+Z side of cross_z_end)
		if rel_ped_z > cross_z_end + 0.15 and rel_ped_z <= cross_z_end + 1.2:
			ped.start_waiting(traffic_light)

func _spawn_cross_car(lane: Dictionary, at_stop_line: bool = false) -> Car:
	var car := CROSS_CAR_SCENE.instantiate() as Car
	var dir: float = lane["dir"]
	var stop_x: float = -4.6 if dir > 0.0 else 4.6
	var start_x: float = stop_x if at_stop_line else (-32.0 if dir > 0.0 else 32.0)
	
	car.position = Vector3(start_x, 0.0, lane["z"])
	add_child(car)
	car.setup(lane["speed"], dir, stop_x)
	
	var is_red: bool = traffic_light.is_red() if traffic_light else false
	car.set_signal_stop(!is_red)
	
	if at_stop_line:
		car.is_stopped = true
		car.current_speed = 0.0
	
	active_cross_cars.append(car)
	return car
