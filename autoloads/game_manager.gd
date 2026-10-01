extends Node

signal game_started
signal game_won(distance: float, coins_collected: int)
signal game_lost(reason: String, distance: float, coins_collected: int, score: int, is_new_record: bool)
signal coin_collected(current_total: int, run_total: int)
signal distance_updated(current_dist: float, best_dist: float)
signal hp_updated(hp: int)

signal near_miss_triggered(combo: int, current_speed: float)
signal traffic_wait_updated(is_waiting: bool, time_left: float, is_go: bool)
signal interior_entering(shop: Node3D)
signal interior_entered
signal interior_exiting(shop: Node3D)
signal interior_exited
signal game_paused(is_paused: bool)

enum GameState {
	READY,
	PLAYING,
	PAUSED,
	ENTERING_INTERIOR,
	IN_INTERIOR,
	EXITING_INTERIOR,
	GAME_OVER,
	VICTORY
}     

const MAX_HP: int = 3 

var current_state: GameState = GameState.READY
var current_distance: float = 0.0
var run_coins: int = 0 
var run_near_misses: int = 0
var current_hp: int = MAX_HP

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	near_miss_triggered.connect(func(_combo, _spd): run_near_misses += 1)

func start_game() -> void:
	Engine.time_scale = 1.0
	current_state = GameState.PLAYING
	current_distance = 0.0
	run_coins = 0
	run_near_misses = 0
	current_hp = MAX_HP
	game_started.emit()
	hp_updated.emit(current_hp)
	distance_updated.emit(0.0, SaveManager.best_distance)

func update_distance(dist: float) -> void:
	if current_state != GameState.PLAYING:
		return
	if dist > current_distance:
		current_distance = dist
		distance_updated.emit(current_distance, SaveManager.best_distance)

func calculate_score() -> int:
	return int(current_distance * 10.0) + (run_coins * 50) + (run_near_misses * 100)

func take_damage(amount: int = 1) -> void:
	if current_state != GameState.PLAYING:
		return
	current_hp = clampi(current_hp - amount, 0, MAX_HP)
	hp_updated.emit(current_hp)
	
	if current_hp <= 0:
		var p := get_tree().get_first_node_in_group(&"player")
		if p and p.has_method(&"die") and not p.get(&"is_dead"):
			p.die("체력 소진!", Vector3(0.0, 1.2, -0.6))
		else:
			trigger_game_over("체력 소진!")

func collect_coin(amount: int = 10) -> void:
	if current_state != GameState.PLAYING:
		return
	run_coins += amount
	SaveManager.add_coins(amount)
	coin_collected.emit(SaveManager.coins, run_coins)

func trigger_victory() -> void:
	if current_state != GameState.PLAYING:
		return
	current_state = GameState.VICTORY
	game_won.emit(current_distance, run_coins)

func trigger_game_over(reason: String) -> void:
	if current_state != GameState.PLAYING:
		return
	current_state = GameState.GAME_OVER
	var final_score := calculate_score()
	var is_new := SaveManager.update_best_run(current_distance, final_score)
	game_lost.emit(reason, current_distance, run_coins, final_score, is_new)

func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		game_paused.emit(true)

func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		game_paused.emit(false)

func is_playing() -> bool:
	return current_state == GameState.PLAYING

func restart_game() -> void:
	get_tree().reload_current_scene()
