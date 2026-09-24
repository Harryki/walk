extends Node3D

const TRACK_START_Z: float = -15.0
const TRACK_END_Z: float = 120.0
const GOAL_Z: float = 100.0

# Colors for Crossy Road aesthetic
const COLOR_SIDEWALK_1: Color = Color(0.85, 0.85, 0.88)
const COLOR_SIDEWALK_2: Color = Color(0.78, 0.78, 0.82)
const COLOR_CURB: Color = Color(0.65, 0.65, 0.68)
const COLOR_ASPHALT: Color = Color(0.22, 0.23, 0.26)
const COLOR_ROAD_LINE: Color = Color(0.95, 0.85, 0.2)
const COLOR_GRASS: Color = Color(0.35, 0.75, 0.3)

const BUILDING_PALETTES: Array[Color] = [
	Color(0.9, 0.4, 0.35), # Coral
	Color(0.35, 0.65, 0.85), # Soft blue
	Color(0.95, 0.75, 0.3), # Warm yellow
	Color(0.4, 0.75, 0.6), # Mint
	Color(0.75, 0.5, 0.75), # Lilac
	Color(0.85, 0.85, 0.9)  # White/Cream
]

const ROOF_PALETTES: Array[Color] = [
	Color(0.25, 0.25, 0.3),
	Color(0.65, 0.25, 0.2),
	Color(0.2, 0.4, 0.3),
	Color(0.3, 0.35, 0.5)
]

func _ready() -> void:
	generate_track()

func generate_track() -> void:
	_build_sidewalk()
	_build_road()
	_build_buildings_and_scenery()
	_build_finish_line()

func _build_sidewalk() -> void:
	# Sidewalk base for X in [-2.5, 2.5] (width 5.0)
	var sidewalk_mesh := BoxMesh.new()
	sidewalk_mesh.size = Vector3(5.0, 0.4, TRACK_END_Z - TRACK_START_Z)
	
	var sidewalk_inst := MeshInstance3D.new()
	sidewalk_inst.mesh = sidewalk_mesh
	sidewalk_inst.position = Vector3(0.0, -0.2, (TRACK_START_Z + TRACK_END_Z) / 2.0)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_SIDEWALK_1
	mat.roughness = 0.9
	sidewalk_inst.material_override = mat
	add_child(sidewalk_inst)
	
	# Sidewalk lane dividers / tile lines along Z for visual depth
	var tile_interval: float = 2.0
	var z := TRACK_START_Z
	while z < TRACK_END_Z:
		var line_mesh := BoxMesh.new()
		line_mesh.size = Vector3(5.0, 0.41, 0.08)
		var line_inst := MeshInstance3D.new()
		line_inst.mesh = line_mesh
		line_inst.position = Vector3(0.0, -0.19, z)
		var line_mat := StandardMaterial3D.new()
		line_mat.albedo_color = COLOR_SIDEWALK_2
		line_inst.material_override = line_mat
		add_child(line_inst)
		z += tile_interval
	
	# Curbs on left (X = -2.55) and right (X = 2.55)
	for curb_x in [-2.55, 2.55]:
		var curb_mesh := BoxMesh.new()
		curb_mesh.size = Vector3(0.15, 0.46, TRACK_END_Z - TRACK_START_Z)
		var curb_inst := MeshInstance3D.new()
		curb_inst.mesh = curb_mesh
		curb_inst.position = Vector3(curb_x, -0.17, (TRACK_START_Z + TRACK_END_Z) / 2.0)
		var curb_mat := StandardMaterial3D.new()
		curb_mat.albedo_color = COLOR_CURB
		curb_inst.material_override = curb_mat
		add_child(curb_inst)

func _build_road() -> void:
	# Asphalt road on near/foreground side: X in [-5.2, -2.6] (center X = -3.9, width 2.6)
	var road_mesh := BoxMesh.new()
	road_mesh.size = Vector3(2.6, 0.35, TRACK_END_Z - TRACK_START_Z)
	var road_inst := MeshInstance3D.new()
	road_inst.mesh = road_mesh
	road_inst.position = Vector3(-3.9, -0.225, (TRACK_START_Z + TRACK_END_Z) / 2.0)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_ASPHALT
	mat.roughness = 0.8
	road_inst.material_override = mat
	add_child(road_inst)
	
	# Dashed yellow line down the middle of asphalt road (X = -3.9)
	var dash_length: float = 2.0
	var dash_gap: float = 2.0
	var z := TRACK_START_Z
	while z < TRACK_END_Z:
		var dash_mesh := BoxMesh.new()
		dash_mesh.size = Vector3(0.15, 0.36, dash_length)
		var dash_inst := MeshInstance3D.new()
		dash_inst.mesh = dash_mesh
		dash_inst.position = Vector3(-3.9, -0.215, z + dash_length / 2.0)
		
		var dash_mat := StandardMaterial3D.new()
		dash_mat.albedo_color = COLOR_ROAD_LINE
		dash_mat.roughness = 0.5
		dash_inst.material_override = dash_mat
		add_child(dash_inst)
		z += dash_length + dash_gap
	
	# Outer grass barrier at X = -6.2
	var outer_mesh := BoxMesh.new()
	outer_mesh.size = Vector3(2.0, 0.4, TRACK_END_Z - TRACK_START_Z)
	var outer_inst := MeshInstance3D.new()
	outer_inst.mesh = outer_mesh
	outer_inst.position = Vector3(-6.2, -0.2, (TRACK_START_Z + TRACK_END_Z) / 2.0)
	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = COLOR_GRASS
	outer_inst.material_override = grass_mat
	add_child(outer_inst)

func _build_buildings_and_scenery() -> void:
	# Grass strip under buildings at far/background side: X in [2.6, 5.5] (center X = 4.6)
	var grass_strip := BoxMesh.new()
	grass_strip.size = Vector3(4.0, 0.4, TRACK_END_Z - TRACK_START_Z)
	var grass_inst := MeshInstance3D.new()
	grass_inst.mesh = grass_strip
	grass_inst.position = Vector3(4.6, -0.2, (TRACK_START_Z + TRACK_END_Z) / 2.0)
	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = COLOR_GRASS
	grass_inst.material_override = grass_mat
	add_child(grass_inst)
	
	# Static collision wall behind sidewalk
	var wall_body := StaticBody3D.new()
	var wall_col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(2.0, 10.0, TRACK_END_Z - TRACK_START_Z)
	wall_col.shape = box_shape
	wall_body.position = Vector3(3.8, 5.0, (TRACK_START_Z + TRACK_END_Z) / 2.0)
	wall_body.add_child(wall_col)
	add_child(wall_body)
	
	# Procedural voxel buildings along background side (X = 3.8)
	var z: float = TRACK_START_Z + 2.0
	while z < TRACK_END_Z - 5.0:
		var building_depth := randf_range(3.5, 6.0)
		var building_height := randf_range(3.5, 7.0)
		var building_color: Color = BUILDING_PALETTES.pick_random()
		var roof_color: Color = ROOF_PALETTES.pick_random()
		
		# Building main body
		var b_mesh := BoxMesh.new()
		b_mesh.size = Vector3(2.2, building_height, building_depth - 0.4)
		var b_inst := MeshInstance3D.new()
		b_inst.mesh = b_mesh
		b_inst.position = Vector3(3.8, building_height / 2.0, z + building_depth / 2.0)
		
		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = building_color
		b_mat.roughness = 0.8
		b_inst.material_override = b_mat
		add_child(b_inst)
		
		# Roof rim
		var roof_mesh := BoxMesh.new()
		roof_mesh.size = Vector3(2.4, 0.4, building_depth)
		var roof_inst := MeshInstance3D.new()
		roof_inst.mesh = roof_mesh
		roof_inst.position = Vector3(3.8, building_height + 0.2, z + building_depth / 2.0)
		var r_mat := StandardMaterial3D.new()
		r_mat.albedo_color = roof_color
		roof_inst.material_override = r_mat
		add_child(roof_inst)
		
		# Voxel windows on building face facing -X towards sidewalk/camera
		var window_mat := StandardMaterial3D.new()
		window_mat.albedo_color = Color(0.9, 0.95, 1.0)
		window_mat.emission_enabled = true
		window_mat.emission = Color(0.4, 0.6, 0.9)
		window_mat.emission_energy_multiplier = 0.5
		
		var floor_count: int = int(building_height / 1.5)
		for fl in range(1, floor_count + 1):
			var win_mesh := BoxMesh.new()
			win_mesh.size = Vector3(0.05, 0.5, 0.6)
			var win_inst := MeshInstance3D.new()
			win_inst.mesh = win_mesh
			win_inst.position = Vector3(2.68, fl * 1.3, z + building_depth / 2.0)
			win_inst.material_override = window_mat
			add_child(win_inst)
		
		# Street tree between buildings
		if randf() > 0.4:
			_build_voxel_tree(Vector3(2.8, 0.0, z + building_depth + 0.8))
		
		z += building_depth + randf_range(1.0, 2.5)

func _build_voxel_tree(pos: Vector3) -> void:
	var tree_node := Node3D.new()
	tree_node.position = pos
	
	# Trunk
	var trunk_mesh := BoxMesh.new()
	trunk_mesh.size = Vector3(0.3, 0.9, 0.3)
	var trunk_inst := MeshInstance3D.new()
	trunk_inst.mesh = trunk_mesh
	trunk_inst.position = Vector3(0.0, 0.45, 0.0)
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.4, 0.25, 0.15)
	trunk_inst.material_override = trunk_mat
	tree_node.add_child(trunk_inst)
	
	# Foliage 1
	var fol1_mesh := BoxMesh.new()
	fol1_mesh.size = Vector3(0.9, 0.7, 0.9)
	var fol1_inst := MeshInstance3D.new()
	fol1_inst.mesh = fol1_mesh
	fol1_inst.position = Vector3(0.0, 1.1, 0.0)
	var fol_mat := StandardMaterial3D.new()
	fol_mat.albedo_color = Color(0.2, 0.65, 0.25)
	fol1_inst.material_override = fol_mat
	tree_node.add_child(fol1_inst)
	
	# Foliage 2
	var fol2_mesh := BoxMesh.new()
	fol2_mesh.size = Vector3(0.6, 0.5, 0.6)
	var fol2_inst := MeshInstance3D.new()
	fol2_inst.mesh = fol2_mesh
	fol2_inst.position = Vector3(0.0, 1.6, 0.0)
	var fol_mat2 := StandardMaterial3D.new()
	fol_mat2.albedo_color = Color(0.3, 0.75, 0.3)
	fol2_inst.material_override = fol_mat2
	tree_node.add_child(fol2_inst)
	
	add_child(tree_node)

func _build_finish_line() -> void:
	# Checkered finish line on ground at Z = 100
	var checker_mat_black := StandardMaterial3D.new()
	checker_mat_black.albedo_color = Color(0.1, 0.1, 0.1)
	
	var checker_mat_white := StandardMaterial3D.new()
	checker_mat_white.albedo_color = Color(0.95, 0.95, 0.95)
	
	for x_idx in range(10):
		var tile_x := -2.25 + x_idx * 0.5
		for z_idx in range(2):
			var tile_z := GOAL_Z + z_idx * 0.5
			var tile_mesh := BoxMesh.new()
			tile_mesh.size = Vector3(0.5, 0.42, 0.5)
			var tile_inst := MeshInstance3D.new()
			tile_inst.mesh = tile_mesh
			tile_inst.position = Vector3(tile_x, -0.18, tile_z)
			tile_inst.material_override = checker_mat_black if (x_idx + z_idx) % 2 == 0 else checker_mat_white
			add_child(tile_inst)
	
	# Finish Arch Pillars
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.9, 0.75, 0.1)
	pillar_mat.metallic = 0.3
	
	var left_pillar := MeshInstance3D.new()
	var pillar_mesh := BoxMesh.new()
	pillar_mesh.size = Vector3(0.5, 4.0, 0.5)
	left_pillar.mesh = pillar_mesh
	left_pillar.position = Vector3(-2.8, 2.0, GOAL_Z)
	left_pillar.material_override = pillar_mat
	add_child(left_pillar)
	
	var right_pillar := MeshInstance3D.new()
	right_pillar.mesh = pillar_mesh
	right_pillar.position = Vector3(2.8, 2.0, GOAL_Z)
	right_pillar.material_override = pillar_mat
	add_child(right_pillar)
	
	# Top Crossbar Banner
	var crossbar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(6.1, 0.8, 0.5)
	crossbar.mesh = bar_mesh
	crossbar.position = Vector3(0.0, 4.0, GOAL_Z)
	var banner_mat := StandardMaterial3D.new()
	banner_mat.albedo_color = Color(0.9, 0.2, 0.2)
	crossbar.material_override = banner_mat
	add_child(crossbar)
