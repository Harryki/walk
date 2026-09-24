class_name Main
extends Node3D

@onready var player: Player = $Player
@onready var camera: Camera3D = $Camera3D
@onready var spawner: Spawner = $Spawner
@onready var chunk_manager: ChunkManager = $ChunkManager if has_node("ChunkManager") else null

# Camera offset for Crossy Road isometric view
var camera_offset: Vector3

func _ready() -> void:
	if camera:
		InteriorManager.register_camera(camera)
		if player:
			camera_offset = camera.global_position - player.global_position
	
	var trans_mask: ColorRect = get_node_or_null("TransitionCanvas/TransitionMask")
	if trans_mask:
		InteriorManager.register_transition_mask(trans_mask)
	
	var interior = get_node_or_null("ShopInterior")
	if interior:
		InteriorManager.register_shop_interior(interior)
	
	if chunk_manager and player:
		chunk_manager.setup(player)
	
	if spawner and player:
		spawner.setup(player)
	
	GameManager.start_game()

func _physics_process(delta: float) -> void:
	if not camera or not player:
		return
	
	# Only follow player when running in normal play (not during interior transition)
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	# Frame-rate independent smooth tracking
	var target_pos := Vector3(
		camera_offset.x + player.global_position.x * 0.3,
		camera_offset.y,
		player.global_position.z + camera_offset.z
	)
	var weight: float = 1.0 - exp(-8.0 * delta)
	camera.global_position = camera.global_position.lerp(target_pos, weight)
