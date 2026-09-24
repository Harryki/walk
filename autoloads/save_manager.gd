extends Node

const SAVE_PATH: String = "user://save_data.cfg"

var coins: int = 0
var max_stamina_level: int = 0  # 0: 100, 1: 120, 2: 140
var base_speed_level: int = 0   # 0: 1.0, 1: 1.3, 2: 1.6
var slide_unlocked: bool = false # cost: 150

const STAMINA_VALUES: Array[float] = [100.0, 120.0, 140.0]
const STAMINA_COSTS: Array[int] = [50, 100]

const SPEED_VALUES: Array[float] = [4.0, 6.5, 9.0]
const SPEED_COSTS: Array[int] = [80, 160]

const SLIDE_COST: int = 150

signal stats_changed

func _ready() -> void:
	load_data()

func get_max_stamina() -> float:
	return STAMINA_VALUES[clampi(max_stamina_level, 0, STAMINA_VALUES.size() - 1)]

func get_base_speed() -> float:
	return SPEED_VALUES[clampi(base_speed_level, 0, SPEED_VALUES.size() - 1)]

func is_slide_unlocked() -> bool:
	return slide_unlocked

func can_upgrade_stamina() -> bool:
	return max_stamina_level < 2 and coins >= STAMINA_COSTS[max_stamina_level]

func get_stamina_upgrade_cost() -> int:
	if max_stamina_level >= 2:
		return -1
	return STAMINA_COSTS[max_stamina_level]

func upgrade_stamina() -> bool:
	if not can_upgrade_stamina():
		return false
	coins -= STAMINA_COSTS[max_stamina_level]
	max_stamina_level += 1
	save_data()
	stats_changed.emit()
	return true

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

func can_unlock_slide() -> bool:
	return not slide_unlocked and coins >= SLIDE_COST

func unlock_slide() -> bool:
	if not can_unlock_slide():
		return false
	coins -= SLIDE_COST
	slide_unlocked = true
	save_data()
	stats_changed.emit()
	return true

func add_coins(amount: int) -> void:
	coins += amount
	save_data()
	stats_changed.emit()

func save_data() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "coins", coins)
	config.set_value("player", "max_stamina_level", max_stamina_level)
	config.set_value("player", "base_speed_level", base_speed_level)
	config.set_value("player", "slide_unlocked", slide_unlocked)
	config.save(SAVE_PATH)

func load_data() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err == OK:
		coins = config.get_value("player", "coins", 0)
		max_stamina_level = config.get_value("player", "max_stamina_level", 0)
		base_speed_level = config.get_value("player", "base_speed_level", 0)
		slide_unlocked = config.get_value("player", "slide_unlocked", false)
