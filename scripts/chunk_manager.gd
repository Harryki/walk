class_name ChunkManager
extends Node3D

const CHUNK_SCENE: PackedScene = preload("res://scenes/chunks/base_chunk.tscn")
const CROSSWALK_CHUNK_SCENE: PackedScene = preload("res://scenes/chunks/crosswalk_chunk.tscn")

const CHUNK_LENGTH: float = 25.0
const ACTIVE_CHUNK_COUNT: int = 5

var player: CharacterBody3D
var active_chunks: Array[Node3D] = []
var next_chunk_z: float = -25.0
var current_chunk_idx: int = 0
var chunks_since_last_crosswalk: int = 0

func setup(p_player: CharacterBody3D) -> void:
	player = p_player
	_spawn_initial_chunks()

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
		
		# Infinite progression tiers
		var tier: int = 1
		if pos_z >= 300.0:
			tier = 3 if randf() < 0.65 else 2
		elif pos_z >= 120.0:
			tier = 2
		else:
			tier = 1
		
		cw.setup_crosswalk(p_index, tier)
		return cw
	else:
		var base := CHUNK_SCENE.instantiate() as BaseChunk
		base.position = Vector3(0.0, 0.0, pos_z)
		# Place shop building asset as street scenery periodically
		var has_shop: bool = (p_index == 2) or (p_index > 5 and p_index % 8 == 0)
		base.setup(p_index, has_shop)
		return base

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	
	var player_z: float = player.global_position.z
	if active_chunks.size() >= ACTIVE_CHUNK_COUNT:
		var oldest_chunk: Node3D = active_chunks[0]
		if player_z - oldest_chunk.position.z > CHUNK_LENGTH * 1.5:
			# Remove oldest chunk and spawn fresh one forward infinitely
			active_chunks.remove_at(0)
			oldest_chunk.queue_free()
			
			var new_chunk := _create_chunk(current_chunk_idx, next_chunk_z)
			add_child(new_chunk)
			active_chunks.append(new_chunk)
			next_chunk_z += CHUNK_LENGTH
			current_chunk_idx += 1
