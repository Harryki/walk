extends Node

const SAVE_PATH: String = "user://save_data.cfg"

var coins: int = 0
var base_speed_level: int = 0   # 0: 4.0, 1: 6.5, 2: 9.0
var best_distance: float = 0.0
var best_score: int = 0

const SPEED_VALUES: Array[float] = [4.0, 6.5, 9.0]
const SPEED_COSTS: Array[int] = [80, 160]

signal stats_changed

func _ready() -> void:
	load_data()

func get_base_speed() -> float:
	return SPEED_VALUES[clampi(base_speed_level, 0, SPEED_VALUES.size() - 1)]

func can_upgrade_speed() -> bool:
	return base_speed_level < 2 and coins >= SPEED_COSTS[base_speed_level]

func get_speed_upgrade_cost() -> int:
	if base_speed_level >= 2:
		return -1
	return SPEED_COSTS[base_speed_level]

func upgrade_speed() -> bool:
	if not can_upgrade_speed():
		return false
	coins -= SPEED_COSTS[base_speed_level]
	base_speed_level += 1
	save_data()
	stats_changed.emit()
	return true

func add_coins(amount: int) -> void:
	coins += amount
	save_data()
	stats_changed.emit()

func update_best_run(distance: float, score: int) -> bool:
	var is_new_record := false
	if distance > best_distance:
		best_distance = distance
		is_new_record = true
	if score > best_score:
		best_score = score
		is_new_record = true
	
	if is_new_record:
		save_data()
		stats_changed.emit()
	return is_new_record

func save_data() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "coins", coins)
	config.set_value("player", "base_speed_level", base_speed_level)
	config.set_value("player", "best_distance", best_distance)
	config.set_value("player", "best_score", best_score)
	config.save(SAVE_PATH)

func load_data() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err == OK:
		coins = config.get_value("player", "coins", 0)
		base_speed_level = config.get_value("player", "base_speed_level", 0)
		best_distance = config.get_value("player", "best_distance", 0.0)
		best_score = config.get_value("player", "best_score", 0)
