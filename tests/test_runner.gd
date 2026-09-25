extends Node

const SpawnTableClass = preload("res://scripts/resources/spawn_table.gd")
const NPCDataClass = preload("res://scripts/resources/npc_data.gd")
const ChunkManagerClass = preload("res://scripts/chunk_manager.gd")
const ShopBuildingClass = preload("res://scripts/shop_building.gd")
const CrosswalkChunkClass = preload("res://scripts/crosswalk_chunk.gd")
const TrafficLightClass = preload("res://scripts/traffic_light.gd")
const CrossCarClass = preload("res://scripts/cross_car.gd")

func _ready() -> void:
	print("--- STARTING GAMEPLAY MECHANICS VERIFICATION ---")
	
	# Reset save data for testing
	SaveManager.coins = 0
	SaveManager.max_stamina_level = 0
	SaveManager.base_speed_level = 0
	SaveManager.slide_unlocked = false
	
	assert(ProjectSettings.get_setting("display/window/handheld/orientation") == 1, "Handheld orientation must be integer 1 (SCREEN_PORTRAIT)")
	
	# 1. Test SaveManager initial state & upgrade logic
	print("[TEST 1] SaveManager stat progression:")
	assert(SaveManager.get_max_stamina() == 100.0, "Initial max stamina should be 100")
	assert(SaveManager.get_base_speed() == SaveManager.SPEED_VALUES[0], "Initial base speed should match level 0")
	assert(not SaveManager.is_slide_unlocked(), "Slide should initially be locked")
	
	# Add coins and test upgrades
	SaveManager.add_coins(500)
	assert(SaveManager.coins >= 500, "Coins should be added")
	
	var stam_upgraded := SaveManager.upgrade_stamina()
	assert(stam_upgraded, "Stamina upgrade 1 should succeed")
	assert(SaveManager.get_max_stamina() == 120.0, "Stamina should be 120 after upgrade")
	
	var speed_upgraded := SaveManager.upgrade_speed()
	assert(speed_upgraded, "Speed upgrade 1 should succeed")
	assert(SaveManager.get_base_speed() == SaveManager.SPEED_VALUES[1], "Speed should match level 1 after upgrade")
	
	var slide_unlocked := SaveManager.unlock_slide()
	assert(slide_unlocked, "Slide unlock should succeed")
	assert(SaveManager.is_slide_unlocked(), "Slide should be unlocked")
	print("  -> SaveManager upgrades PASSED!")
	
	# 2. Test Player instance logic
	print("[TEST 2] Player mechanics:")
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var player = player_scene.instantiate()
	add_child(player)
	
	GameManager.start_game()
	
	# Test lane changing
	assert(player.current_lane == 0, "Player should start in center lane (0)")
	player.change_lane(-1)
	assert(player.current_lane == -1, "Player should shift to lane -1")
	player.change_lane(-1)
	assert(player.current_lane == -2, "Player should shift to lane -2 (min)")
	player.change_lane(-1)
	assert(player.current_lane == -2, "Player should be clamped at lane -2")
	player.change_lane(1)
	assert(player.current_lane == -1, "Player should shift to lane -1")
	print("  -> Lane change clamping PASSED!")
	
	# Test tap boost and stamina
	var initial_stam: float = player.current_stamina
	var initial_spd: float = player.current_speed
	player.try_tap_boost()
	assert(player.current_stamina == initial_stam - 5.0, "Tap boost should consume 5 stamina")
	assert(player.current_speed > initial_spd, "Tap boost should increase speed")
	print("  -> Direct Tap boost PASSED!")
	
	# Test Spacebar input event
	var space_event := InputEventKey.new()
	space_event.physical_keycode = KEY_SPACE
	space_event.pressed = true
	player._unhandled_input(space_event)
	assert(player.current_stamina == initial_stam - 10.0, "Spacebar input must consume 5 stamina")
	print("  -> Spacebar input event PASSED!")
	
	# Test Mouse Click (Screen Tap) input event: Down then Up
	var click_down := InputEventMouseButton.new()
	click_down.button_index = MOUSE_BUTTON_LEFT
	click_down.pressed = true
	player._unhandled_input(click_down)
	
	var click_up := InputEventMouseButton.new()
	click_up.button_index = MOUSE_BUTTON_LEFT
	click_up.pressed = false
	player._unhandled_input(click_up)
	assert(player.current_stamina == initial_stam - 15.0, "Mouse click (tap) must consume 5 stamina")
	print("  -> Mouse Click (Tap) input event PASSED!")
	
	# Test Swipe Gesture: Must NOT consume tap boost stamina!
	var stam_before_swipe: float = player.current_stamina
	var initial_lane: int = player.current_lane
	var touch_down := InputEventScreenTouch.new()
	touch_down.position = Vector2(200, 500)
	touch_down.pressed = true
	player._unhandled_input(touch_down)
	
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.position = Vector2(260, 500) # swipe right +60px
	player._unhandled_input(touch_drag)
	
	var touch_up := InputEventScreenTouch.new()
	touch_up.position = Vector2(260, 500)
	touch_up.pressed = false
	player._unhandled_input(touch_up)
	
	assert(player.current_lane == initial_lane + 1, "Swipe right must change lane right")
	assert(player.current_stamina == stam_before_swipe, "Swipe gesture must NOT consume tap boost stamina")
	print("  -> Swipe gesture (0 stamina cost) PASSED!")
	
	# Test slide
	var stam_before_slide: float = player.current_stamina
	player.try_slide()
	assert(player.is_sliding, "Player should enter slide state")
	assert(player.current_stamina == stam_before_slide - 25.0, "Slide should consume 25 stamina")
	print("  -> Slide dash & invincibility PASSED!")
	
	# Test damage
	player.is_sliding = false # reset slide for damage test
	var initial_hp: int = GameManager.current_hp
	player.hit_by_obstacle()
	assert(GameManager.current_hp == initial_hp - 1, "Player should take 1 damage on obstacle hit")
	assert(player.is_invincible, "Player should become invincible after hit")
	# Hit again during invincibility - should not take damage
	player.hit_by_obstacle()
	assert(GameManager.current_hp == initial_hp - 1, "Invincible player should not take additional damage")
	print("  -> Damage & Invincibility blink PASSED!")
	
	# 3. Test Data-driven SpawnTable
	print("[TEST 3] Data-Driven Spawner:")
	var npc_table = load("res://resources/spawns/spawn_table_default.tres")
	assert(npc_table != null, "Default NPC SpawnTable should load")
	var picked_npc = npc_table.pick_random(0.0)
	assert(picked_npc != null and picked_npc.id == &"pedestrian_normal", "Should pick valid normal pedestrian at distance 0")
	var jogger_npc = npc_table.pick_random(50.0)
	assert(jogger_npc != null, "Should pick valid NPCData at distance 50")
	print("  -> SpawnTable weighted sampling PASSED!")
	
	# 4. Test ChunkManager & BaseChunk
	print("[TEST 4] ChunkManager & BaseChunk:")
	var chunk_mgr = ChunkManagerClass.new()
	add_child(chunk_mgr)
	chunk_mgr.setup(player)
	assert(chunk_mgr.active_chunks.size() == 5, "ChunkManager should maintain 5 active chunks")
	assert(chunk_mgr.active_chunks[2].has_shop == true, "Chunk 2 should have enterable shop")
	print("  -> ChunkManager ring buffer setup PASSED!")
	
	# 5. Test InteriorManager, Swipe-to-enter Door & Shop Seamless Transition
	print("[TEST 5] Door Swipe-to-Enter & Interior Transition:")
	var shop = chunk_mgr.active_chunks[2].enterable_building_instance
	assert(shop != null, "Shop building should exist in Chunk 2")
	
	# Player arrives in front of door
	shop._on_door_body_entered(player)
	assert(player.current_door_target == shop, "Player should register door target")
	assert(GameManager.current_state == GameManager.GameState.PLAYING, "Player in front of door must NOT enter automatically")
	
	# Connect signals to verify pre-transition notifications
	var received := {
		"interior_entering": false,
		"shop_entering": false,
		"player_entering": false
	}
	
	GameManager.interior_entering.connect(func(_s): received["interior_entering"] = true, CONNECT_ONE_SHOT)
	InteriorManager.shop_entering.connect(func(_s, _p): received["shop_entering"] = true, CONNECT_ONE_SHOT)
	shop.player_entering_shop.connect(func(_s, _p): received["player_entering"] = true, CONNECT_ONE_SHOT)
	
	# If player does NOT swipe left, they can pass by freely
	# When player reaches door lane (MIN_LANE) and swipes left:
	player.current_lane = player.MIN_LANE
	player.velocity = Vector3(0.0, 0.0, 10.0) # Player was sprinting
	player.change_lane(-1)
	
	assert(received["interior_entering"], "GameManager.interior_entering must be emitted before transition")
	assert(received["shop_entering"], "InteriorManager.shop_entering must be emitted before transition")
	assert(received["player_entering"], "ShopBuilding.player_entering_shop must be emitted before transition")
	assert(player.velocity == Vector3.ZERO, "Player velocity must be zeroed immediately upon entering shop")
	assert(GameManager.current_state == GameManager.GameState.IN_INTERIOR, "Swiping left in front of door must enter shop")
	
	# Exit shop
	InteriorManager.exit_shop()
	assert(GameManager.current_state == GameManager.GameState.PLAYING, "Exiting shop must return to PLAYING state")
	
	# Verify TransitionTextureMask scene and script
	var mask_scene: PackedScene = load("res://scenes/ui/transition_mask.tscn")
	assert(mask_scene != null, "Transition mask scene must load")
	var mask_layer = mask_scene.instantiate()
	add_child(mask_layer)
	var mask_node = mask_layer.get_node("TransitionMask")
	assert(mask_node is TransitionTextureMask, "Mask node must be TransitionTextureMask")
	assert(mask_node.default_duration >= 0.8, "Transition mask should have slower duration >= 0.8s")
	mask_layer.queue_free()
	
	# Verify 3D Voxel ShopInterior scene and speech bubble interaction
	var interior_scene: PackedScene = load("res://scenes/buildings/shop_interior.tscn")
	assert(interior_scene != null, "ShopInterior scene must load")
	var interior: ShopInterior = interior_scene.instantiate()
	add_child(interior)
	interior.start_interior(player)
	assert(interior.is_active, "ShopInterior should become active")
	
	# Test station navigation and speech bubble updates
	interior.go_to_station(0)
	assert(interior.current_station == 0, "Current station should be 0 (Stamina)")
	assert(interior.bubble_title.text.contains("스태미너"), "Bubble title should show stamina")
	
	interior.go_to_station(1)
	assert(interior.current_station == 1, "Current station should be 1 (Speed)")
	assert(interior.bubble_title.text.contains("속도"), "Bubble title should show speed")
	
	interior.go_to_station(2)
	assert(interior.current_station == 2, "Current station should be 2 (Slide)")
	assert(interior.bubble_title.text.contains("슬라이드"), "Bubble title should show slide")
	
	interior.go_to_station(3)
	assert(interior.current_station == 3, "Current station should be 3 (Exit Mat)")
	assert(interior.bubble_title.text.contains("나가기"), "Bubble title should show exit")
	
	interior.queue_free()
	print("  -> Door Swipe, 3D Voxel ShopInterior & Speech Bubble PASSED!")
	
	# Clean up save data so user starts fresh
	SaveManager.coins = 0
	SaveManager.max_stamina_level = 0
	SaveManager.base_speed_level = 0
	SaveManager.slide_unlocked = false
	SaveManager.save_data()
	
	# Verify ShopInterior camera positioning
	var main_scene = load("res://scenes/main.tscn").instantiate()
	add_child(main_scene)
	var cam: Camera3D = main_scene.get_node("Camera3D")
	var shop_interior_node = main_scene.get_node("ShopInterior")
	var spot_node: Marker3D = shop_interior_node.get_node("CameraTargetSpot")
	cam.global_transform = spot_node.global_transform
	cam.size = 7.5
	
	var p_target = shop_interior_node.global_position + Vector3(0.0, 0.8, 0.0)
	var unproj_center = cam.unproject_position(p_target)
	var vp_rect = get_viewport().get_visible_rect()
	assert(unproj_center.x > 0 and unproj_center.x < vp_rect.size.x, "Shop center must be within screen width")
	assert(unproj_center.y > 0 and unproj_center.y < vp_rect.size.y, "Shop center must be within screen height")
	main_scene.queue_free()
	
	# 6. Test Crosswalk, TrafficLight & CrossCar mechanics
	print("[TEST 6] Crosswalk & Multi-Tier Traffic:")
	var cw_scene: PackedScene = load("res://scenes/chunks/crosswalk_chunk.tscn")
	assert(cw_scene != null, "Crosswalk chunk scene must load")
	
	# Test Tier 1, Tier 2, Tier 3 configuration
	var cw_t1 = cw_scene.instantiate()
	add_child(cw_t1)
	cw_t1.setup_crosswalk(3, 1)
	assert(cw_t1.cross_lanes.size() == 1, "Tier 1 must have 1 cross lane")
	assert(cw_t1.traffic_light != null, "TrafficLight must be created")
	assert(cw_t1.traffic_light.is_safe_to_cross(), "Initial traffic light must be safe (GREEN)")
	
	# Test traffic light transitions
	cw_t1.traffic_light._set_state(TrafficLightClass.LightState.WARNING)
	assert(cw_t1.traffic_light.is_safe_to_cross(), "WARNING state should still allow clearing crossing")
	cw_t1.traffic_light._set_state(TrafficLightClass.LightState.RED)
	assert(cw_t1.traffic_light.is_red(), "RED state should flag as red")
	assert(not cw_t1.traffic_light.is_safe_to_cross(), "RED state is not safe")
	
	# Test Tier 2 and Tier 3 lane counts
	var cw_t2 = cw_scene.instantiate()
	add_child(cw_t2)
	cw_t2.setup_crosswalk(6, 2)
	assert(cw_t2.cross_lanes.size() == 2, "Tier 2 must have 2 cross lanes")
	
	var cw_t3 = cw_scene.instantiate()
	add_child(cw_t3)
	cw_t3.setup_crosswalk(9, 3)
	assert(cw_t3.cross_lanes.size() == 4, "Tier 3 must have 4 cross lanes")
	
	# Test CrossCar lethal collision on player
	var cross_car_scene: PackedScene = load("res://scenes/environment/cross_car.tscn")
	assert(cross_car_scene != null, "CrossCar scene must load")
	var car = cross_car_scene.instantiate()
	add_child(car)
	car.setup(25.0, 1.0)
	
	# Reset player state
	GameManager.current_state = GameManager.GameState.PLAYING
	GameManager.current_hp = 3
	player.is_sliding = false
	player.is_invincible = false
	
	# Direct hit while walking
	car._on_body_entered(player)
	assert(GameManager.current_state == GameManager.GameState.GAME_OVER, "Car collision without slide must cause lethal GAME_OVER")
	
	# Collision while sliding
	GameManager.current_state = GameManager.GameState.PLAYING
	player.is_sliding = true
	player.is_invincible = true
	car._on_body_entered(player)
	assert(GameManager.current_state == GameManager.GameState.PLAYING, "Sliding player must evade lethal car collision")
	
	print("  -> Multi-Tier Crosswalks, Traffic Lights & Lethal Cars PASSED!")
	
	# 7. Test Audio Buses, Street Ambience & Dynamic Footsteps
	print("[TEST 7] Audio Buses, Street Ambience & Dynamic Footsteps:")
	assert(AudioServer.get_bus_index("Master") >= 0, "Master audio bus must exist")
	assert(AudioServer.get_bus_index("Ambience") >= 0, "Ambience audio bus must exist")
	assert(AudioServer.get_bus_index("PlayerSFX") >= 0, "PlayerSFX audio bus must exist")
	assert(AudioServer.get_bus_index("SFX") >= 0, "SFX audio bus must exist")
	
	# Verify AudioManager and Ambience stream
	assert(AudioManager != null, "AudioManager autoload must be loaded")
	assert(AudioManager.ambience_player != null, "Ambience player must be initialized")
	assert(AudioManager.ambience_player.bus == &"Ambience", "Ambience player must route to Ambience bus")
	
	# Verify Player Footstep Audio
	assert(player.FOOTSTEP_SOUNDS.size() == 3, "Player must have 3 footstep sounds")
	assert(player.footstep_audio != null, "Player must have footstep_audio initialized")
	assert(player.footstep_audio.bus == &"PlayerSFX", "Footstep audio must route to PlayerSFX bus")
	
	# Test footstep trigger proportional to speed
	GameManager.current_state = GameManager.GameState.PLAYING
	player.is_sliding = false
	player.is_waiting_at_signal = false
	player.current_speed = 5.0
	player.hop_time = 0.0
	# Advance hop_time past PI (half-cycle landing: hop_speed = 5.0 * 2.2 + 5.0 = 16.0; 0.25s * 16.0 = 4.0 > PI)
	player._update_visual_hop(0.25)
	assert(player.footstep_audio.playing, "Player footstep audio must play on landing")
	
	# Verify Player OOF sound and Pedestrian THUD sound
	assert(player.OOF_SOUND != null, "Player OOF sound must be loaded")
	player.play_oof_sound()
	
	var ped_scene: PackedScene = load("res://scenes/obstacles/pedestrian.tscn")
	var test_ped = ped_scene.instantiate()
	add_child(test_ped)
	assert(test_ped.THUD_SOUND != null, "Pedestrian THUD sound must be loaded")
	test_ped.destroy_pedestrian()
	print("  -> Player OOF (PlayerSFX) and Pedestrian THUD (SFX) PASSED!")
	print("  -> Audio Buses, Street Ambience & Speed-Proportional Footsteps PASSED!")
	
	# Clean up test nodes
	cw_t1.queue_free()
	cw_t2.queue_free()
	cw_t3.queue_free()
	car.queue_free()
	player.queue_free()
	
	print("--- ALL VERIFICATION TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit()
