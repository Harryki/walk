extends Node

signal game_started
signal game_won(distance: float, coins_collected: int)
signal game_lost(reason: String, distance: float, coins_collected: int)
signal coin_collected(current_total: int, run_total: int)
signal distance_updated(current_dist: float, max_dist: float)
signal time_updated(time_left: float)
signal hp_updated(hp: int)

signal stamina_updated(stamina: float, max_stamina: float, is_exhausted: bool)
signal slide_cooldown_updated(time_left: float, max_time: float)
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

const TARGET_DISTANCE: float = 300.0
const TIME_LIMIT: float = 90.0
const MAX_HP: int = 3 

var current_state: GameState = GameState.READY
var time_left: float = TIME_LIMIT
var current_distance: float = 0.0
var run_coins: int = 0 
var current_hp: int = MAX_HP

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_game() -> void:
	current_state = GameState.PLAYING
	time_left = TIME_LIMIT
	current_distance = 0.0
	run_coins = 0
	current_hp = MAX_HP
	game_started.emit()
	hp_updated.emit(current_hp)
	distance_updated.emit(0.0, TARGET_DISTANCE)
	time_updated.emit(time_left)

func _process(delta: float) -> void:
	if current_state != GameState.PLAYING:
		return
	
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		time_updated.emit(time_left)
		trigger_game_over("시간 초과!")
	else:
		time_updated.emit(time_left)

func update_distance(dist: float) -> void:
	if current_state != GameState.PLAYING:
		return
	current_distance = clampf(dist, 0.0, TARGET_DISTANCE)
	distance_updated.emit(current_distance, TARGET_DISTANCE)
	
	if current_distance >= TARGET_DISTANCE:
		trigger_victory()

func take_damage(amount: int = 1) -> void:
	if current_state != GameState.PLAYING:
		return
	current_hp = clampi(current_hp - amount, 0, MAX_HP)
	hp_updated.emit(current_hp)
	
	if current_hp <= 0:
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
	game_lost.emit(reason, current_distance, run_coins)

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
	# Main._ready() will initialize and start game
	get_tree().reload_current_scene()
