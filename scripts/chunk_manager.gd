class_name ChunkManager
extends Node3D

const CHUNK_SCENE: PackedScene = preload("res://scenes/chunks/base_chunk.tscn")
const CROSSWALK_CHUNK_SCENE: PackedScene = preload("res://scenes/chunks/crosswalk_chunk.tscn")

const CHUNK_LENGTH: float = 25.0
const ACTIVE_CHUNK_COUNT: int = 5
const GOAL_Z: float = 300.0

var player: CharacterBody3D
var active_chunks: Array[Node3D] = []
var next_chunk_z: float = -25.0
var current_chunk_idx: int = 0
var chunks_since_last_crosswalk: int = 0

func setup(p_player: CharacterBody3D) -> void:
	player = p_player
	_spawn_initial_chunks()
	_build_finish_line()

func _spawn_initial_chunks() -> void:
	for i in range(ACTIVE_CHUNK_COUNT):
		var chunk := _create_chunk(current_chunk_idx, next_chunk_z)
		add_child(chunk)
		active_chunks.append(chunk)
		next_chunk_z += CHUNK_LENGTH
		current_chunk_idx += 1

func _create_chunk(p_index: int, pos_z: float) -> Node3D:
	var is_crosswalk := false
	
	# Determine if this chunk is a crosswalk
	if p_index == 3:
		# First crosswalk (Tier 1) at Z = 50m ~ 75m
		is_crosswalk = true
		chunks_since_last_crosswalk = 0
	elif p_index > 3 and chunks_since_last_crosswalk >= 2:
		is_crosswalk = true
		chunks_since_last_crosswalk = 0
	else:
		chunks_since_last_crosswalk += 1
	
	if is_crosswalk:
		var cw := CROSSWALK_CHUNK_SCENE.instantiate() as CrosswalkChunk
		cw.position = Vector3(0.0, 0.0, pos_z)
		
		# Determine tier based on distance
		var tier: int = 1
		if pos_z >= 220.0:
			tier = 3 # 4-lane highway
		elif pos_z >= 110.0:
			tier = 2 # 2-lane street
		else:
			tier = 1 # 1-lane one-way
		
		cw.setup_crosswalk(p_index, tier)
		return cw
	else:
		var base := CHUNK_SCENE.instantiate() as BaseChunk
		base.position = Vector3(0.0, 0.0, pos_z)
		var has_shop: bool = (p_index == 2) # Place shop building in chunk 2 (Z = 25m to 50m)
		base.setup(p_index, has_shop)
		return base

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	
	var player_z: float = player.global_position.z
	if active_chunks.size() >= ACTIVE_CHUNK_COUNT:
		var oldest_chunk: Node3D = active_chunks[0]
		if player_z - oldest_chunk.position.z > CHUNK_LENGTH * 1.5:
			# Remove oldest chunk and spawn fresh one forward
			active_chunks.remove_at(0)
			oldest_chunk.queue_free()
			
			if next_chunk_z < GOAL_Z + CHUNK_LENGTH * 2.0:
				var new_chunk := _create_chunk(current_chunk_idx, next_chunk_z)
				add_child(new_chunk)
				active_chunks.append(new_chunk)
				next_chunk_z += CHUNK_LENGTH
				current_chunk_idx += 1

func _build_finish_line() -> void:
	# Checkered finish line on ground at Z = GOAL_Z
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
	banner_mat.albedo_color = Color(0.85, 0.2, 0.2)
	crossbar.material_override = banner_mat
	add_child(crossbar)
	
	# Finish Label
	var label := Label3D.new()
	label.text = "🏁 FINISH 🏁"
	label.position = Vector3(0.0, 4.0, GOAL_Z - 0.26)
	label.font_size = 48
	label.outline_size = 8
	label.modulate = Color(1.0, 0.95, 0.2)
	add_child(label)
