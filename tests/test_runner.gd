extends Node

func _ready() -> void:
	print("--- STARTING GAMEPLAY MECHANICS VERIFICATION ---")
	
	# Reset save data for testing
	SaveManager.coins = 0
	SaveManager.max_stamina_level = 0
	SaveManager.base_speed_level = 0
	SaveManager.slide_unlocked = false
	
	# 1. Test SaveManager initial state & upgrade logic
	print("[TEST 1] SaveManager stat progression:")
	assert(SaveManager.get_max_stamina() == 100.0, "Initial max stamina should be 100")
	assert(SaveManager.get_base_speed() == 1.0, "Initial base speed should be 1.0")
	assert(not SaveManager.is_slide_unlocked(), "Slide should initially be locked")
	
	# Add coins and test upgrades
	SaveManager.add_coins(500)
	assert(SaveManager.coins >= 500, "Coins should be added")
	
	var stam_upgraded := SaveManager.upgrade_stamina()
	assert(stam_upgraded, "Stamina upgrade 1 should succeed")
	assert(SaveManager.get_max_stamina() == 120.0, "Stamina should be 120 after upgrade")
	
	var speed_upgraded := SaveManager.upgrade_speed()
	assert(speed_upgraded, "Speed upgrade 1 should succeed")
	assert(SaveManager.get_base_speed() == 1.3, "Speed should be 1.3 after upgrade")
	
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
	
	# Test Mouse Click (Screen Tap) input event
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	player._unhandled_input(click_event)
	assert(player.current_stamina == initial_stam - 15.0, "Mouse click input must consume 5 stamina")
	print("  -> Mouse Click (Tap) input event PASSED!")
	
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
	
	# Clean up save data so user starts fresh
	SaveManager.coins = 0
	SaveManager.max_stamina_level = 0
	SaveManager.base_speed_level = 0
	SaveManager.slide_unlocked = false
	SaveManager.save_data()
	
	print("--- ALL VERIFICATION TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit()
