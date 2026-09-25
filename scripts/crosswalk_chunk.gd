class_name CrosswalkChunk
extends BaseChunk

@export var tier: int = 1 # 1: 1-lane, 2: 2-lane, 3: 4-lane

const CROSS_CAR_SCENE: PackedScene = preload("res://scenes/environment/cross_car.tscn")
const TRAFFIC_LIGHT_SCENE: PackedScene = preload("res://scenes/environment/traffic_light.tscn")

var traffic_light: TrafficLight = null
var exit_traffic_light: TrafficLight = null
var entry_zone: Area3D = null
var exit_zone: Area3D = null
var cross_z_start: float = 10.0
var cross_z_end: float = 15.0
var cross_lanes: Array[Dictionary] = [] # [{z: float, dir: float, timer: float, interval: float, speed: float}]
var active_cross_cars: Array[CrossCar] = []

var _mat_zebra: StandardMaterial3D
var _mat_stop_line: StandardMaterial3D
var _mat_ped_stop_line: StandardMaterial3D
var _mat_cross_asphalt: StandardMaterial3D

func _init() -> void:
	super._init()
	_init_crosswalk_materials()

func _init_crosswalk_materials() -> void:
	if _mat_zebra != null:
		return
	
	_mat_zebra = StandardMaterial3D.new()
	_mat_zebra.albedo_color = Color(0.96, 0.96, 0.98)
	_mat_zebra.roughness = 0.5
	
	_mat_stop_line = StandardMaterial3D.new()
	_mat_stop_line.albedo_color = Color(0.95, 0.95, 0.95)
	
	_mat_ped_stop_line = StandardMaterial3D.new()
	_mat_ped_stop_line.albedo_color = Color(0.95, 0.85, 0.15) # Safety yellow for pedestrian waiting line
	_mat_ped_stop_line.roughness = 0.6
	
	_mat_cross_asphalt = StandardMaterial3D.new()
	_mat_cross_asphalt.albedo_color = Color(0.18, 0.19, 0.22)
	_mat_cross_asphalt.roughness = 0.85

func setup_crosswalk(p_chunk_index: int, p_tier: int = 1) -> void:
	chunk_index = p_chunk_index
	tier = clampi(p_tier, 1, 3)
	_configure_tier()
	_build_crosswalk_chunk()

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

func _build_crosswalk_chunk() -> void:
	_build_segmented_ground()
	_build_crosswalk_zebra()
	_build_pedestrian_stop_lines()
	_build_traffic_light()
	_build_detection_zones()
	_build_corner_buildings()
	_spawn_initial_waiting_cars()

func _spawn_initial_waiting_cars() -> void:
	# Spawn cars waiting at the stop lines while traffic light is green
	for lane in cross_lanes:
		_spawn_cross_car(lane, true)

func _build_segmented_ground() -> void:
	# 1. Entry Sidewalk (Z: 0.0 to cross_z_start)
	var entry_len: float = cross_z_start
	var sw_entry := MeshInstance3D.new()
	var sw_entry_mesh := BoxMesh.new()
	sw_entry_mesh.size = Vector3(5.0, 0.4, entry_len)
	sw_entry.mesh = sw_entry_mesh
	sw_entry.position = Vector3(0.0, -0.2, entry_len / 2.0)
	sw_entry.material_override = _mat_sidewalk
	add_child(sw_entry)
	
	# 2. Exit Sidewalk (Z: cross_z_end to 25.0)
	var exit_len: float = CHUNK_LENGTH - cross_z_end
	var sw_exit := MeshInstance3D.new()
	var sw_exit_mesh := BoxMesh.new()
	sw_exit_mesh.size = Vector3(5.0, 0.4, exit_len)
	sw_exit.mesh = sw_exit_mesh
	sw_exit.position = Vector3(0.0, -0.2, cross_z_end + exit_len / 2.0)
	sw_exit.material_override = _mat_sidewalk
	add_child(sw_exit)
	
	# 3. Cross Street (Asphalt cutting sideways through X = -35.0 to +35.0)
	var cross_width: float = cross_z_end - cross_z_start
	var cross_center_z: float = cross_z_start + cross_width / 2.0
	var cross_road := MeshInstance3D.new()
	var cross_road_mesh := BoxMesh.new()
	cross_road_mesh.size = Vector3(70.0, 0.38, cross_width)
	cross_road.mesh = cross_road_mesh
	cross_road.position = Vector3(0.0, -0.21, cross_center_z)
	cross_road.material_override = _mat_cross_asphalt
	add_child(cross_road)
	
	# Longitudinal side road (X: -3.9) before and after intersection
	for seg in [[0.0, cross_z_start], [cross_z_end, CHUNK_LENGTH]]:
		var seg_len: float = seg[1] - seg[0]
		if seg_len > 0.5:
			var rd := MeshInstance3D.new()
			var rd_m := BoxMesh.new()
			rd_m.size = Vector3(2.6, 0.35, seg_len)
			rd.mesh = rd_m
			rd.position = Vector3(-3.9, -0.225, seg[0] + seg_len / 2.0)
			rd.material_override = _mat_asphalt
			add_child(rd)

func _build_crosswalk_zebra() -> void:
	# White zebra stripes across player lanes (X: -2.0 to 2.0)
	var stripe_interval: float = 1.4
	var curr_z: float = cross_z_start + 0.6
	
	while curr_z < cross_z_end - 0.4:
		# 5 stripes per row corresponding to lanes
		for lane_x in [-2.0, -1.0, 0.0, 1.0, 2.0]:
			var stripe := MeshInstance3D.new()
			var stripe_mesh := BoxMesh.new()
			stripe_mesh.size = Vector3(0.55, 0.03, 0.75)
			stripe.mesh = stripe_mesh
			stripe.position = Vector3(lane_x, -0.005, curr_z)
			stripe.material_override = _mat_zebra
			add_child(stripe)
		curr_z += stripe_interval
	
	# Thick Stop Lines for cars on the cross street (X = -3.2 and X = 3.2)
	var cross_width: float = cross_z_end - cross_z_start
	var cross_center_z: float = cross_z_start + cross_width / 2.0
	for stop_x in [-3.2, 3.2]:
		var stop_line := MeshInstance3D.new()
		var stop_mesh := BoxMesh.new()
		stop_mesh.size = Vector3(0.4, 0.04, cross_width)
		stop_line.mesh = stop_mesh
		stop_line.position = Vector3(stop_x, -0.005, cross_center_z)
		stop_line.material_override = _mat_stop_line
		add_child(stop_line)

func _build_pedestrian_stop_lines() -> void:
	# Entry pedestrian stop line (Z: cross_z_start - 0.25)
	var entry_line := MeshInstance3D.new()
	var line_mesh_entry := BoxMesh.new()
	line_mesh_entry.size = Vector3(5.0, 0.03, 0.35)
	entry_line.mesh = line_mesh_entry
	entry_line.position = Vector3(0.0, -0.004, cross_z_start - 0.25)
	entry_line.material_override = _mat_ped_stop_line
	add_child(entry_line)
	
	# Exit pedestrian stop line (Z: cross_z_end + 0.25)
	var exit_line := MeshInstance3D.new()
	var line_mesh_exit := BoxMesh.new()
	line_mesh_exit.size = Vector3(5.0, 0.03, 0.35)
	exit_line.mesh = line_mesh_exit
	exit_line.position = Vector3(0.0, -0.004, cross_z_end + 0.25)
	exit_line.material_override = _mat_ped_stop_line
	add_child(exit_line)

func _build_traffic_light() -> void:
	traffic_light = TRAFFIC_LIGHT_SCENE.instantiate() as TrafficLight
	# Place primary traffic light pole at corner entry of crosswalk
	traffic_light.position = Vector3(-2.8, 0.0, cross_z_start - 0.4)
	add_child(traffic_light)
	
	# Place opposing traffic light pole on opposite sidewalk facing oncoming pedestrians
	exit_traffic_light = TRAFFIC_LIGHT_SCENE.instantiate() as TrafficLight
	exit_traffic_light.position = Vector3(2.8, 0.0, cross_z_end + 0.4)
	exit_traffic_light.rotation.y = PI
	add_child(exit_traffic_light)
	
	# Synchronize state changes to exit light
	traffic_light.state_changed.connect(func(new_state: int):
		if is_instance_valid(exit_traffic_light):
			exit_traffic_light._set_state(new_state as TrafficLight.LightState)
	)

func _build_detection_zones() -> void:
	# 1. Entry Stop Zone (Player advancing in +Z towards crosswalk)
	entry_zone = Area3D.new()
	entry_zone.name = "EntryStopZone"
	entry_zone.position = Vector3(0.0, 0.5, cross_z_start - 0.6)
	var entry_shape := CollisionShape3D.new()
	var box1 := BoxShape3D.new()
	box1.size = Vector3(5.5, 2.5, 1.2)
	entry_shape.shape = box1
	entry_zone.add_child(entry_shape)
	entry_zone.monitoring = true
	entry_zone.monitorable = false
	add_child(entry_zone)
	
	# 2. Exit Stop Zone (Pedestrians advancing in -Z towards crosswalk)
	exit_zone = Area3D.new()
	exit_zone.name = "ExitStopZone"
	exit_zone.position = Vector3(0.0, 0.5, cross_z_end + 0.6)
	var exit_shape := CollisionShape3D.new()
	var box2 := BoxShape3D.new()
	box2.size = Vector3(5.5, 2.5, 1.2)
	exit_shape.shape = box2
	exit_zone.add_child(exit_shape)
	exit_zone.monitoring = true
	exit_zone.monitorable = false
	add_child(exit_zone)

func _build_corner_buildings() -> void:
	# Place corner buildings before intersection (Z: 0 to cross_z_start - 0.8)
	if cross_z_start > 3.0:
		_create_corner_building(Vector3(4.6, 0.0, cross_z_start / 2.0), cross_z_start - 1.0)
	
	# Place corner buildings after intersection (Z: cross_z_end + 0.8 to 25.0)
	var exit_len: float = CHUNK_LENGTH - cross_z_end
	if exit_len > 3.0:
		_create_corner_building(Vector3(4.6, 0.0, cross_z_end + exit_len / 2.0), exit_len - 1.0)

func _create_corner_building(pos: Vector3, max_z_len: float) -> void:
	var b_mesh := BoxMesh.new()
	var b_h: float = randf_range(6.0, 10.0)
	var b_z: float = minf(max_z_len, 5.0)
	b_mesh.size = Vector3(3.6, b_h, b_z)
	
	var b_inst := MeshInstance3D.new()
	b_inst.mesh = b_mesh
	b_inst.position = Vector3(pos.x, b_h / 2.0, pos.z)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BUILDING_PALETTES.pick_random()
	mat.roughness = 0.8
	b_inst.material_override = mat
	add_child(b_inst)

func _physics_process(delta: float) -> void:
	if not traffic_light:
		return
	
	var is_red: bool = traffic_light.is_red()
	
	# Update existing cars to obey current traffic signal
	var valid_cars: Array[CrossCar] = []
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
	
	# 2. Exit zone check: ONLY for Pedestrians walking towards crosswalk (-Z direction)
	# If pedestrians have already stepped into the crosswalk or crossed it (rel_z <= cross_z_end + 0.15), DO NOT STOP!
	if exit_zone:
		for area in exit_zone.get_overlapping_areas():
			if area is Pedestrian:
				var rel_ped_z := area.global_position.z - global_position.z
				# Only stop if pedestrian is strictly BEFORE the crosswalk entry line
				if rel_ped_z > cross_z_end + 0.15 and rel_ped_z <= cross_z_end + 1.2:
					area.start_waiting(traffic_light)

func _spawn_cross_car(lane: Dictionary, at_stop_line: bool = false) -> CrossCar:
	var car := CROSS_CAR_SCENE.instantiate() as CrossCar
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
