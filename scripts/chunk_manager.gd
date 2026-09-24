class_name ChunkManager
extends Node3D

const CHUNK_SCENE: PackedScene = preload("res://scenes/chunks/base_chunk.tscn")
const CHUNK_LENGTH: float = 25.0
const ACTIVE_CHUNK_COUNT: int = 5
const GOAL_Z: float = 100.0

var player: CharacterBody3D
var active_chunks: Array[Node3D] = []
var next_chunk_z: float = -25.0

func setup(p_player: CharacterBody3D) -> void:
	player = p_player
	_spawn_initial_chunks()
	_build_finish_line()

func _spawn_initial_chunks() -> void:
	for i in range(ACTIVE_CHUNK_COUNT):
		var chunk := CHUNK_SCENE.instantiate() as Node3D
		chunk.position = Vector3(0.0, 0.0, next_chunk_z)
		# Place shop in chunk 2 (Z = 25m to 50m)
		var has_shop: bool = (i == 2)
		if chunk.has_method(&"setup"):
			chunk.setup(i, has_shop)
		add_child(chunk)
		active_chunks.append(chunk)
		next_chunk_z += CHUNK_LENGTH

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	
	# In endless mode or if player goes past 100m, recycles chunks seamlessly
	var player_z: float = player.global_position.z
	if active_chunks.size() >= ACTIVE_CHUNK_COUNT:
		var oldest_chunk: Node3D = active_chunks[0]
		if player_z - oldest_chunk.position.z > CHUNK_LENGTH * 1.6 and player_z < 90.0:
			# Shift oldest chunk forward
			oldest_chunk.position.z = next_chunk_z
			next_chunk_z += CHUNK_LENGTH
			active_chunks.remove_at(0)
			active_chunks.append(oldest_chunk)

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
