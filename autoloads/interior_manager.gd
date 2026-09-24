extends Node

signal shop_opened(shop: Node3D)
signal shop_closed

var current_shop: Node3D
var current_player: CharacterBody3D
var main_camera: Camera3D
var transition_mask: ColorRect = null
var shop_interior: Node3D = null

var pre_interior_cam_size: float = 10.5
var pre_interior_cam_transform: Transform3D = Transform3D.IDENTITY
var pre_interior_player_pos: Vector3 = Vector3.ZERO

func register_camera(cam: Camera3D) -> void:
	main_camera = cam
	if main_camera:
		pre_interior_cam_size = main_camera.size
		pre_interior_cam_transform = main_camera.global_transform

func register_transition_mask(mask: ColorRect) -> void:
	transition_mask = mask

func register_shop_interior(interior: Node3D) -> void:
	shop_interior = interior

func handle_player_entered_shop(shop: Node3D, player: CharacterBody3D) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	current_shop = shop
	current_player = player
	
	# Compute screen UV position of player/door for Mario iris center
	var center_uv := Vector2(0.5, 0.5)
	if main_camera and is_instance_valid(player):
		var screen_pos: Vector2 = main_camera.unproject_position(player.global_position)
		var vp_rect := player.get_viewport().get_visible_rect()
		center_uv = Vector2(
			clampf(screen_pos.x / vp_rect.size.x, 0.1, 0.9),
			clampf(screen_pos.y / vp_rect.size.y, 0.1, 0.9)
		)
	
	if transition_mask and is_instance_valid(transition_mask) and transition_mask.has_method(&"fade_in"):
		# 1. Close Mario Iris wipe onto player (dramatic 0.85s duration)
		await transition_mask.fade_in(center_uv, 0.85)
		
		# 2. Setup 3D Interior while screen is dark
		_setup_interior_view(shop, player)
		
		# 3. Open Mario Iris wipe revealing shop interior
		await transition_mask.fade_out(Vector2(0.5, 0.5), 0.8)
		shop_opened.emit(shop)
	else:
		_setup_interior_view(shop, player)
		shop_opened.emit(shop)

func _setup_interior_view(shop: Node3D, player: CharacterBody3D) -> void:
	GameManager.current_state = GameManager.GameState.IN_INTERIOR
	GameManager.interior_entered.emit()
	
	if player:
		pre_interior_player_pos = player.global_position
		player.velocity = Vector3.ZERO
	
	if main_camera:
		pre_interior_cam_size = main_camera.size
		pre_interior_cam_transform = main_camera.global_transform
	
	# If dedicated 3D voxel shop interior is available, use it
	if shop_interior and is_instance_valid(shop_interior):
		var camera_spot = shop_interior.get_node_or_null("CameraTargetSpot")
		if main_camera and camera_spot:
			# Directly copy full Transform3D (basis + origin) to eliminate Euler gimbal lock / inversion
			main_camera.global_transform = camera_spot.global_transform
			main_camera.size = 7.5
		
		if shop_interior.has_method(&"start_interior"):
			shop_interior.start_interior(player)
	else:
		# Fallback to shop building spots
		var player_spot = shop.get_node_or_null("PlayerStopSpot")
		if player_spot and player:
			player.global_position = player_spot.global_position
		
		var camera_spot = shop.get_node_or_null("CameraTargetSpot")
		if main_camera and camera_spot:
			main_camera.global_transform = camera_spot.global_transform
			main_camera.size = 7.0

func exit_shop() -> void:
	if GameManager.current_state != GameManager.GameState.IN_INTERIOR:
		return
	
	shop_closed.emit()
	
	if transition_mask and is_instance_valid(transition_mask) and transition_mask.has_method(&"fade_in"):
		# 1. Close Mario Iris wipe (0.8s)
		await transition_mask.fade_in(Vector2(0.5, 0.5), 0.8)
		
		# 2. Restore runner view while dark
		_restore_runner_view()
		
		# 3. Open Mario Iris wipe back to runner game (0.8s)
		await transition_mask.fade_out(Vector2(0.5, 0.5), 0.8)
	else:
		_restore_runner_view()

func _restore_runner_view() -> void:
	if current_shop and current_shop.has_method(&"close_shop"):
		current_shop.close_shop()
	
	if current_player:
		# Return player to lane -2 on sidewalk, slightly forward past door
		var forward_z: float = pre_interior_player_pos.z + 1.5 if pre_interior_player_pos != Vector3.ZERO else current_player.global_position.z
		current_player.global_position = Vector3(
			current_player.LANES[current_player.current_lane + 2],
			0.0,
			forward_z
		)
		current_player.velocity = Vector3(0.0, 0.0, current_player.base_speed)
		if current_player.visual_root:
			current_player.visual_root.rotation.y = 0.0 # Face forward towards running direction
	
	if main_camera:
		main_camera.size = pre_interior_cam_size
		main_camera.global_transform = pre_interior_cam_transform
	
	GameManager.current_state = GameManager.GameState.PLAYING
	GameManager.interior_exited.emit()
	current_shop = null
	current_player = null
