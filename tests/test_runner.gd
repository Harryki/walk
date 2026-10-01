extends Node

const SpawnTableClass = preload("res://scripts/resources/spawn_table.gd")
const NPCDataClass = preload("res://scripts/resources/npc_data.gd")
const ChunkManagerClass = preload("res://scripts/chunk_manager.gd")
const ShopBuildingClass = preload("res://scripts/shop_building.gd")
const CrosswalkChunkClass = preload("res://scripts/crosswalk_chunk.gd")
const TrafficLightClass = preload("res://scripts/traffic_light.gd")
const CarClass = preload("res://scripts/car.gd")

func _ready() -> void:
	print("--- STARTING GAMEPLAY MECHANICS VERIFICATION ---")
	
	# Reset save data for testing
	SaveManager.coins = 0
	SaveManager.base_speed_level = 0
	SaveManager.best_distance = 0.0
	SaveManager.best_score = 0
	
	assert(ProjectSettings.get_setting("display/window/handheld/orientation") == 1, "Handheld orientation must be integer 1 (SCREEN_PORTRAIT)")
	
	# 1. Test SaveManager initial state & upgrade logic
	print("[TEST 1] SaveManager stat progression:")
	assert(SaveManager.get_base_speed() == SaveManager.SPEED_VALUES[0], "Initial base speed should match level 0")
	
	# Add coins and test speed upgrades
	SaveManager.add_coins(500)
	assert(SaveManager.coins >= 500, "Coins should be added")
	
	var speed_upgraded := SaveManager.upgrade_speed()
	assert(speed_upgraded, "Speed upgrade 1 should succeed")
	assert(SaveManager.get_base_speed() == SaveManager.SPEED_VALUES[1], "Speed should match level 1 after upgrade")
	print("  -> SaveManager speed upgrade PASSED!")
	
	# 2. Test Player instance logic
	print("[TEST 2] Player mechanics (5:5 Touch & Near Miss):")
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var player: Player = player_scene.instantiate()
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
	
	# Test 5:5 Screen Touch Control (Left half -> Lane Left, Right half -> Lane Right)
	var screen_w: float = get_viewport().get_visible_rect().size.x
	player.current_lane = 0
	
	# Touch Left (< 50% width)
	var touch_left := InputEventScreenTouch.new()
	touch_left.position = Vector2(screen_w * 0.25, 500)
	touch_left.pressed = true
	player._unhandled_input(touch_left)
	assert(player.current_lane == -1, "Left screen touch must shift player left")
	
	# Touch Right (> 50% width)
	player.last_touch_msec = 0
	var touch_right := InputEventScreenTouch.new()
	touch_right.position = Vector2(screen_w * 0.75, 500)
	touch_right.pressed = true
	player._unhandled_input(touch_right)
	assert(player.current_lane == 0, "Right screen touch must shift player right")
	
	# Mouse Click Left (< 50% width)
	player.last_touch_msec = 0
	var click_left := InputEventMouseButton.new()
	click_left.button_index = MOUSE_BUTTON_LEFT
	click_left.position = Vector2(screen_w * 0.2, 500)
	click_left.pressed = true
	player._unhandled_input(click_left)
	assert(player.current_lane == -1, "Left mouse click must shift player left")
	
	# Simulate Godot touch-from-mouse emulation duplicate in same frame: must NOT double jump!
	var emulated_touch := InputEventScreenTouch.new()
	emulated_touch.position = Vector2(screen_w * 0.2, 500)
	emulated_touch.pressed = true
	player._unhandled_input(emulated_touch)
	assert(player.current_lane == -1, "Duplicate emulated touch event must be ignored by debounce")
	
	# Mouse Click Right (> 50% width)
	player.last_touch_msec = 0
	var click_right := InputEventMouseButton.new()
	click_right.button_index = MOUSE_BUTTON_LEFT
	click_right.position = Vector2(screen_w * 0.8, 500)
	click_right.pressed = true
	player._unhandled_input(click_right)
	assert(player.current_lane == 0, "Right mouse click must shift player right")
	print("  -> 5:5 Screen Touch & Click controls & Duplicate Debounce PASSED!")
	
	# Test Near Miss Speed Boost & Hold / Decay
	var initial_spd: float = player.current_speed
	player.trigger_near_miss()
	assert(player.current_speed == initial_spd + player.NEAR_MISS_BOOST, "Near Miss must increase speed by NEAR_MISS_BOOST")
	assert(player.boost_hold_timer == player.BOOST_HOLD_DURATION, "Near Miss must set boost hold timer")
	assert(player.near_miss_combo == 1, "First near miss should set combo to 1")
	
	# Another near miss -> Combo 2 & further speed increase
	player.trigger_near_miss()
	assert(player.current_speed == initial_spd + player.NEAR_MISS_BOOST * 2.0, "Second Near Miss must stack speed")
	assert(player.near_miss_combo == 2, "Combo should increment to 2")
	
	# Speed hold during timer: speed should not decay while hold_timer > 0
	player._physics_process(1.0)
	assert(player.boost_hold_timer == player.BOOST_HOLD_DURATION - 1.0, "Boost timer should tick down")
	assert(player.current_speed == initial_spd + player.NEAR_MISS_BOOST * 2.0, "Speed must NOT decay while hold timer is active")
	
	# After hold timer expires, speed gradually decays towards base_speed
	player._physics_process(1.5) # hold timer reaches 0, decay starts
	assert(player.current_speed < initial_spd + player.NEAR_MISS_BOOST * 2.0, "Speed should decay towards base speed after hold timer expires")
	print("  -> Near Miss speed boost, hold timer & decay PASSED!")
	
	# Test Collision Reset: Direct obstacle hit resets current_speed immediately to base_speed
	player.current_speed = 12.0
	player.boost_hold_timer = 2.0
	player.near_miss_combo = 3
	var hp_before_hit := GameManager.current_hp
	player.hit_by_obstacle()
	assert(player.current_speed == player.base_speed, "Hit by obstacle must IMMEDIATELY reset speed to base_speed")
	assert(player.boost_hold_timer == 0.0, "Obstacle hit must reset boost hold timer")
	assert(player.near_miss_combo == 0, "Obstacle hit must reset near miss combo")
	assert(GameManager.current_hp == hp_before_hit - 1, "Player must take 1 damage")
	assert(player.is_invincible, "Player should become invincible after hit")
	print("  -> Obstacle hit speed reset & damage PASSED!")
	
	# 3. Test Data-driven SpawnTable
	print("[TEST 3] Data-Driven Spawner:")
	var npc_table = load("res://resources/spawns/spawn_table_default.tres")
	assert(npc_table != null, "Default NPC SpawnTable should load")
	var picked_npc = npc_table.pick_random(0.0)
	assert(picked_npc != null and picked_npc.id == &"pedestrian_normal", "Should pick valid normal pedestrian at distance 0")
	var jogger_npc = npc_table.pick_random(50.0)
	assert(jogger_npc != null, "Should pick valid NPCData at distance 50")
	var item_table = load("res://resources/spawns/item_table_default.tres")
	assert(item_table != null, "Default Item SpawnTable should load")
	assert(item_table.rules.size() == 2, "Item table should contain only coin and super coin (energy drink removed)")
	print("  -> SpawnTable weighted sampling & Item Table PASSED!")
	
	# 4. Test ChunkManager & BaseChunk
	print("[TEST 4] ChunkManager & BaseChunk:")
	var chunk_mgr = ChunkManagerClass.new()
	add_child(chunk_mgr)
	chunk_mgr.setup(player)
	assert(chunk_mgr.active_chunks.size() == 5, "ChunkManager should maintain 5 active chunks")
	assert(chunk_mgr.active_chunks[2].has_shop == true, "Chunk 2 should have enterable shop")
	print("  -> ChunkManager ring buffer setup PASSED!")
	
	# 5. Test Shop Scenery Preservation & Infinite Runner Scoring
	print("[TEST 5] Shop Building Scenery & Infinite Scoring:")
	var shop = chunk_mgr.active_chunks[2].enterable_building_instance
	assert(shop != null, "Shop building asset should be preserved in Chunk 2 as street scenery")
	assert(not shop.is_active, "Street doorway trigger must be disabled as requested")
	
	# Verify door does not register target or disrupt running
	shop._on_door_body_entered(player)
	assert(player.get("current_door_target") == null, "Player must not register street door target")
	assert(GameManager.current_state == GameManager.GameState.PLAYING, "Player continues running uninterrupted")
	
	# Test Infinite Runner Score Calculation
	GameManager.current_distance = 250.0
	GameManager.run_coins = 12
	GameManager.run_near_misses = 5
	var score := GameManager.calculate_score()
	# 250 * 10 = 2500, 12 * 50 = 600, 5 * 100 = 500 => 3600
	assert(score == 3600, "Score calculation must match formula: dist*10 + coins*50 + near_miss*100")
	
	var is_new := SaveManager.update_best_run(250.0, score)
	assert(is_new, "First score must be a new best record")
	assert(SaveManager.best_distance == 250.0, "Best distance should be saved as 250.0")
	assert(SaveManager.best_score == 3600, "Best score should be saved as 3600")
	
	# Verify 3D Voxel ShopInterior scene and speech bubble interaction assets are preserved intact
	var interior_scene: PackedScene = load("res://scenes/buildings/shop_interior.tscn")
	assert(interior_scene != null, "ShopInterior scene asset must remain intact")
	var interior: ShopInterior = interior_scene.instantiate()
	add_child(interior)
	interior.start_interior(player)
	assert(interior.is_active, "ShopInterior remains functional for future redesign")
	interior.queue_free()
	print("  -> Shop Scenery & Infinite Scoring PASSED!")
	
	# Clean up save data so user starts fresh
	SaveManager.coins = 0
	SaveManager.base_speed_level = 0
	SaveManager.save_data()
	
	# 6. Test Crosswalk, TrafficLight & CrossCar mechanics
	print("[TEST 6] Crosswalk & Multi-Tier Traffic:")
	var cw_scene: PackedScene = load("res://scenes/chunks/crosswalk_chunk.tscn")
	assert(cw_scene != null, "Crosswalk chunk scene must load")
	
	var cw_t1 = cw_scene.instantiate()
	add_child(cw_t1)
	cw_t1.setup_crosswalk(3, 1)
	assert(cw_t1.cross_lanes.size() == 1, "Tier 1 must have 1 cross lane")
	assert(cw_t1.traffic_light != null, "TrafficLight must be created")
	assert(cw_t1.traffic_light.is_safe_to_cross(), "Initial traffic light must be safe (GREEN)")
	
	# Test Car lethal collision on player
	var car_scene: PackedScene = load("res://scenes/environment/car.tscn")
	assert(car_scene != null, "Car scene must load")
	var car = car_scene.instantiate()
	add_child(car)
	car.setup(25.0, 1.0)
	
	# Reset player state
	GameManager.current_state = GameManager.GameState.PLAYING
	GameManager.current_hp = 3
	player.is_invincible = false
	
	# Direct hit by car
	car._on_body_entered(player)
	assert(GameManager.current_state == GameManager.GameState.GAME_OVER, "Car collision must cause lethal GAME_OVER")
	assert(Engine.time_scale < 0.5, "Death must trigger slow-motion (time_scale < 0.5)")
	assert(player.is_dead, "Player must be flagged dead")
	player.reset_state()
	assert(Engine.time_scale == 1.0, "Resetting state must restore normal time_scale 1.0")
	
	# 7. Test Pedestrian Near Miss Area and Grazing Mechanics
	print("[TEST 7] Pedestrian Near Miss & Collision Detection:")
	GameManager.start_game()
	var ped_scene: PackedScene = load("res://scenes/obstacles/pedestrian.tscn")
	var ped: Pedestrian = ped_scene.instantiate()
	add_child(ped)
	ped.global_position = Vector3(1.0, 0.0, 10.0) # Lane 1, Z = 10.0
	player.global_position = Vector3(0.0, 0.0, 8.0) # Lane 0 (Adjacent lane!), Z = 8.0
	player.current_speed = player.base_speed
	player.boost_hold_timer = 0.0
	player.near_miss_combo = 0
	
	# Player enters Near Miss Area
	ped._on_near_miss_body_entered(player)
	assert(ped.tracked_player == player, "Pedestrian should track player in near miss area")
	
	# Player safely passes pedestrian's Z position without direct hit
	player.global_position.z = 11.0 # passed Z = 10.0
	var spd_before := player.current_speed
	ped._physics_process(0.016)
	assert(ped.has_near_missed, "Pedestrian must flag near miss when player safely passes")
	assert(player.current_speed == spd_before + player.NEAR_MISS_BOOST, "Passing pedestrian safely in near miss zone must boost player speed")
	assert(player.boost_hold_timer == player.BOOST_HOLD_DURATION, "Passing pedestrian safely must set boost hold timer")
	ped.queue_free()
	print("  -> Pedestrian Near Miss area & speed boost PASSED!")
	
	# 8. Test Vibrant Comic Arcade + Neo-Brutalism HUD
	print("[TEST 8] Vibrant Comic Arcade + Neo-Brutalism HUD:")
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	var hud = hud_scene.instantiate()
	add_child(hud)
	
	assert(hud.traffic_alert_banner != null, "HUD must have TrafficAlertBanner")
	assert(hud.boost_comic_pop != null, "HUD must have BoostComicPop")
	
	# Test traffic wait alert banner integration
	GameManager.traffic_wait_updated.emit(true, 4.0, false)
	assert(hud.traffic_alert_banner.visible, "Traffic alert banner must be visible during wait")
	assert(hud.alert_title.text == "WAIT!", "Alert title must say WAIT!")
	
	GameManager.traffic_wait_updated.emit(false, 0.0, true)
	assert(hud.alert_title.text == "GO!", "Alert title must transition to GO!")
	
	# Test HP heart loss
	GameManager.hp_updated.emit(2)
	assert(hud.heart_nodes[2].modulate == hud.HEART_DEPLETED_COLOR, "3rd heart must become depleted on damage")
	
	# Test Boost Comic Pop
	hud.show_boost_comic_popup("CLOSE CALL!")
	assert(hud.boost_comic_pop.visible, "Boost comic pop must appear on near miss")
	assert(hud.boost_pop_label.text == "CLOSE CALL!", "Boost comic pop label must match text")
	
	hud.queue_free()
	print("  -> Neo-Brutalism Comic HUD & Traffic Alert Banner PASSED!")
	
	# Clean up test nodes
	cw_t1.queue_free()
	car.queue_free()
	player.queue_free()
	
	print("--- ALL VERIFICATION TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit()
