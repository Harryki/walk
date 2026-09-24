class_name BaseChunk
extends Node3D

const CHUNK_LENGTH: float = 25.0

# Aesthetic Colors matching Crossy Road theme
const COLOR_SIDEWALK_1: Color = Color(0.85, 0.85, 0.88)
const COLOR_SIDEWALK_2: Color = Color(0.78, 0.78, 0.82)
const COLOR_CURB: Color = Color(0.65, 0.65, 0.68)
const COLOR_ASPHALT: Color = Color(0.22, 0.23, 0.26)
const COLOR_ROAD_LINE: Color = Color(0.95, 0.85, 0.2)
const COLOR_GRASS: Color = Color(0.35, 0.75, 0.3)

const BUILDING_PALETTES: Array[Color] = [
	Color(0.9, 0.4, 0.35),
	Color(0.35, 0.65, 0.85),
	Color(0.95, 0.75, 0.3),
	Color(0.4, 0.75, 0.6),
	Color(0.75, 0.5, 0.75),
	Color(0.85, 0.85, 0.9)
]

const ROOF_PALETTES: Array[Color] = [
	Color(0.25, 0.25, 0.3),
	Color(0.65, 0.25, 0.2),
	Color(0.2, 0.4, 0.3),
	Color(0.3, 0.35, 0.5)
]

# Reusable shared materials to minimize draw calls and shader state changes
static var _mat_sidewalk: StandardMaterial3D
static var _mat_tile_line: StandardMaterial3D
static var _mat_curb: StandardMaterial3D
static var _mat_asphalt: StandardMaterial3D
static var _mat_road_line: StandardMaterial3D
static var _mat_grass: StandardMaterial3D
static var _mat_trunk: StandardMaterial3D
static var _mat_foliage: StandardMaterial3D
static var _mat_window: StandardMaterial3D

var chunk_index: int = 0
var has_shop: bool = false
var enterable_building_instance: Node3D = null

func _init() -> void:
	_init_shared_materials()

static func _init_shared_materials() -> void:
	if _mat_sidewalk != null:
		return
	
	_mat_sidewalk = StandardMaterial3D.new()
	_mat_sidewalk.albedo_color = COLOR_SIDEWALK_1
	_mat_sidewalk.roughness = 0.9
	
	_mat_tile_line = StandardMaterial3D.new()
	_mat_tile_line.albedo_color = COLOR_SIDEWALK_2
	
	_mat_curb = StandardMaterial3D.new()
	_mat_curb.albedo_color = COLOR_CURB
	
	_mat_asphalt = StandardMaterial3D.new()
	_mat_asphalt.albedo_color = COLOR_ASPHALT
	_mat_asphalt.roughness = 0.8
	
	_mat_road_line = StandardMaterial3D.new()
	_mat_road_line.albedo_color = COLOR_ROAD_LINE
	_mat_road_line.roughness = 0.5
	
	_mat_grass = StandardMaterial3D.new()
	_mat_grass.albedo_color = COLOR_GRASS
	
	_mat_trunk = StandardMaterial3D.new()
	_mat_trunk.albedo_color = Color(0.4, 0.25, 0.15)
	
	_mat_foliage = StandardMaterial3D.new()
	_mat_foliage.albedo_color = Color(0.25, 0.7, 0.3)
	
	_mat_window = StandardMaterial3D.new()
	_mat_window.albedo_color = Color(0.9, 0.95, 1.0)
	_mat_window.emission_enabled = true
	_mat_window.emission = Color(0.4, 0.6, 0.9)
	_mat_window.emission_energy_multiplier = 0.5

func setup(p_chunk_index: int, p_has_shop: bool = false) -> void:
	chunk_index = p_chunk_index
	has_shop = p_has_shop
	_build_chunk()

func _build_chunk() -> void:
	_build_ground()
	_build_tile_lines_multimesh()
	_build_road_lines_multimesh()
	_build_buildings()

func _build_ground() -> void:
	var half_len: float = CHUNK_LENGTH / 2.0
	
	# Sidewalk (X: -2.5 ~ 2.5)
	var sw_mesh := BoxMesh.new()
	sw_mesh.size = Vector3(5.0, 0.4, CHUNK_LENGTH)
	var sw_inst := MeshInstance3D.new()
	sw_inst.mesh = sw_mesh
	sw_inst.position = Vector3(0.0, -0.2, half_len)
	sw_inst.material_override = _mat_sidewalk
	add_child(sw_inst)
	
	# Curbs at X = -2.55 and X = 2.55
	for curb_x in [-2.55, 2.55]:
		var curb_mesh := BoxMesh.new()
		curb_mesh.size = Vector3(0.15, 0.46, CHUNK_LENGTH)
		var curb_inst := MeshInstance3D.new()
		curb_inst.mesh = curb_mesh
		curb_inst.position = Vector3(curb_x, -0.17, half_len)
		curb_inst.material_override = _mat_curb
		add_child(curb_inst)
	
	# Asphalt road (X: -5.2 ~ -2.6, center: -3.9, width: 2.6)
	var rd_mesh := BoxMesh.new()
	rd_mesh.size = Vector3(2.6, 0.35, CHUNK_LENGTH)
	var rd_inst := MeshInstance3D.new()
	rd_inst.mesh = rd_mesh
	rd_inst.position = Vector3(-3.9, -0.225, half_len)
	rd_inst.material_override = _mat_asphalt
	add_child(rd_inst)
	
	# Outer grass barrier at X = -6.2
	var og_mesh := BoxMesh.new()
	og_mesh.size = Vector3(2.0, 0.4, CHUNK_LENGTH)
	var og_inst := MeshInstance3D.new()
	og_inst.mesh = og_mesh
	og_inst.position = Vector3(-6.2, -0.2, half_len)
	og_inst.material_override = _mat_grass
	add_child(og_inst)
	
	# Grass strip under buildings at X = 4.6
	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(4.0, 0.4, CHUNK_LENGTH)
	var bg_inst := MeshInstance3D.new()
	bg_inst.mesh = bg_mesh
	bg_inst.position = Vector3(4.6, -0.2, half_len)
	bg_inst.material_override = _mat_grass
	add_child(bg_inst)
	
	# Static collision wall behind sidewalk (X = 3.8)
	var wall := StaticBody3D.new()
	var wall_col := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(2.0, 10.0, CHUNK_LENGTH)
	wall_col.shape = wall_box
	wall.position = Vector3(3.8, 5.0, half_len)
	wall.add_child(wall_col)
	add_child(wall)

## MultiMesh for sidewalk divider lines: 1 draw call instead of individual nodes
func _build_tile_lines_multimesh() -> void:
	var interval: float = 2.0
	var count: int = int(CHUNK_LENGTH / interval)
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(5.0, 0.41, 0.08)
	mm.mesh = line_mesh
	mm.instance_count = count
	
	for i in range(count):
		var z: float = (i + 0.5) * interval
		var t := Transform3D(Basis.IDENTITY, Vector3(0.0, -0.19, z))
		mm.set_instance_transform(i, t)
	
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat_tile_line
	add_child(mmi)

## MultiMesh for yellow dashed road markers: 1 draw call
func _build_road_lines_multimesh() -> void:
	var dash_len: float = 2.0
	var gap: float = 2.0
	var step: float = dash_len + gap
	var count: int = int(CHUNK_LENGTH / step)
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.15, 0.36, dash_len)
	mm.mesh = dash_mesh
	mm.instance_count = count
	
	for i in range(count):
		var z: float = i * step + dash_len / 2.0
		var t := Transform3D(Basis.IDENTITY, Vector3(-3.9, -0.215, z))
		mm.set_instance_transform(i, t)
	
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat_road_line
	add_child(mmi)

func _build_buildings() -> void:
	var z: float = 1.5
	var shop_spawned: bool = false
	
	while z < CHUNK_LENGTH - 4.0:
		var depth := randf_range(3.8, 5.5)
		if z + depth > CHUNK_LENGTH:
			depth = CHUNK_LENGTH - z - 0.5
		
		# If this chunk is designated as a shop chunk, place shop building in the middle
		if has_shop and not shop_spawned and z >= 6.0:
			_build_shop_building_slot(Vector3(3.8, 0.0, z + depth / 2.0))
			shop_spawned = true
		else:
			_build_single_building(z, depth)
		
		# Street tree
		if randf() > 0.4 and (z + depth + 1.2 < CHUNK_LENGTH):
			_build_voxel_tree(Vector3(2.8, 0.0, z + depth + 0.6))
		
		z += depth + randf_range(0.8, 1.8)

func _build_single_building(z_start: float, depth: float) -> void:
	var height := randf_range(3.5, 6.5)
	var col: Color = BUILDING_PALETTES.pick_random()
	var roof_col: Color = ROOF_PALETTES.pick_random()
	
	# Body
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(2.2, height, depth - 0.4)
	var b_inst := MeshInstance3D.new()
	b_inst.mesh = b_mesh
	b_inst.position = Vector3(3.8, height / 2.0, z_start + depth / 2.0)
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = col
	b_mat.roughness = 0.8
	b_inst.material_override = b_mat
	add_child(b_inst)
	
	# Roof
	var r_mesh := BoxMesh.new()
	r_mesh.size = Vector3(2.4, 0.4, depth)
	var r_inst := MeshInstance3D.new()
	r_inst.mesh = r_mesh
	r_inst.position = Vector3(3.8, height + 0.2, z_start + depth / 2.0)
	var r_mat := StandardMaterial3D.new()
	r_mat.albedo_color = roof_col
	r_inst.material_override = r_mat
	add_child(r_inst)
	
	# Windows facing sidewalk
	var floors: int = int(height / 1.5)
	for fl in range(1, floors + 1):
		var w_mesh := BoxMesh.new()
		w_mesh.size = Vector3(0.05, 0.5, 0.6)
		var w_inst := MeshInstance3D.new()
		w_inst.mesh = w_mesh
		w_inst.position = Vector3(2.68, fl * 1.3, z_start + depth / 2.0)
		w_inst.material_override = _mat_window
		add_child(w_inst)

func _build_shop_building_slot(pos: Vector3) -> void:
	# Instantiate enterable shop building
	var shop_scene: PackedScene = load("res://scenes/buildings/shop_building.tscn")
	if shop_scene:
		var shop := shop_scene.instantiate() as Node3D
		shop.position = pos
		add_child(shop)
		enterable_building_instance = shop
	else:
		_build_single_building(pos.z - 2.5, 5.0)

func _build_voxel_tree(pos: Vector3) -> void:
	var tree := Node3D.new()
	tree.position = pos
	
	var trunk := MeshInstance3D.new()
	var trunk_mesh := BoxMesh.new()
	trunk_mesh.size = Vector3(0.3, 0.9, 0.3)
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(0.0, 0.45, 0.0)
	trunk.material_override = _mat_trunk
	tree.add_child(trunk)
	
	var fol := MeshInstance3D.new()
	var fol_mesh := BoxMesh.new()
	fol_mesh.size = Vector3(0.85, 0.9, 0.85)
	fol.mesh = fol_mesh
	fol.position = Vector3(0.0, 1.25, 0.0)
	fol.material_override = _mat_foliage
	tree.add_child(fol)
	
	add_child(tree)
