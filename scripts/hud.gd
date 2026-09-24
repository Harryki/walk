extends Control

@onready var time_label: Label = $TopBar/TimeContainer/TimeLabel
@onready var distance_bar: ProgressBar = $TopBar/DistanceContainer/DistanceProgressBar
@onready var distance_label: Label = $TopBar/DistanceContainer/DistanceLabel

@onready var hp_container: HBoxContainer = $StatsContainer/HPContainer
@onready var stamina_bar: ProgressBar = $StatsContainer/StaminaBar
@onready var stamina_label: Label = $StatsContainer/StaminaBar/StaminaLabel

@onready var slide_panel: PanelContainer = $StatsContainer/SlidePanel
@onready var slide_label: Label = $StatsContainer/SlidePanel/SlideLabel

@onready var coin_label: Label = $CoinContainer/CoinLabel

var heart_nodes: Array[Label] = []

func _ready() -> void:
	# Store heart labels
	for child in hp_container.get_children():
		if child is Label:
			heart_nodes.append(child)
	
	GameManager.time_updated.connect(_on_time_updated)
	GameManager.distance_updated.connect(_on_distance_updated)
	GameManager.hp_updated.connect(_on_hp_updated)
	GameManager.stamina_updated.connect(_on_stamina_updated)
	GameManager.slide_cooldown_updated.connect(_on_slide_cooldown_updated)
	GameManager.coin_collected.connect(_on_coin_collected)
	
	# Initial UI state
	_update_coins(SaveManager.coins, 0)
	_update_slide_indicator(0.0, 5.0)

func _on_time_updated(time_left: float) -> void:
	var minutes := int(time_left) / 60
	var seconds := int(time_left) % 60
	var centiseconds := int((time_left - int(time_left)) * 100)
	time_label.text = "%02d:%02d.%02d" % [minutes, seconds, centiseconds]
	
	if time_left < 10.0:
		time_label.modulate = Color(1.0, 0.3, 0.3)
	else:
		time_label.modulate = Color.WHITE

func _on_distance_updated(current_dist: float, max_dist: float) -> void:
	distance_bar.max_value = max_dist
	distance_bar.value = current_dist
	distance_label.text = "%.1fm / %.0fm" % [current_dist, max_dist]

func _on_hp_updated(hp: int) -> void:
	for i in range(heart_nodes.size()):
		if i < hp:
			heart_nodes[i].modulate = Color(1.0, 0.2, 0.2) # Active Red Heart
			heart_nodes[i].text = "❤️"
		else:
			heart_nodes[i].modulate = Color(0.4, 0.4, 0.4) # Lost Heart
			heart_nodes[i].text = "🖤"

func _on_stamina_updated(current: float, max_val: float, is_exhausted: bool) -> void:
	stamina_bar.max_value = max_val
	stamina_bar.value = current
	
	if is_exhausted:
		stamina_label.text = "⚡ 탈진! (2초 대기)"
		stamina_bar.modulate = Color(1.0, 0.4, 0.4)
	else:
		stamina_label.text = "⚡ %d / %d" % [int(current), int(max_val)]
		stamina_bar.modulate = Color(0.2, 0.8, 1.0)

func _on_slide_cooldown_updated(time_left: float, max_time: float) -> void:
	_update_slide_indicator(time_left, max_time)

func _update_slide_indicator(time_left: float, _max_time: float) -> void:
	if not SaveManager.is_slide_unlocked():
		slide_label.text = "💨 슬라이드: 잠김 (상점 해금)"
		slide_panel.modulate = Color(0.6, 0.6, 0.6, 0.7)
		return
	
	if time_left > 0.0:
		slide_label.text = "💨 슬라이드 쿨: %.1fs" % time_left
		slide_panel.modulate = Color(0.7, 0.7, 0.7)
	else:
		slide_label.text = "💨 슬라이드 [W/Swipe]: 준비 완료!"
		slide_panel.modulate = Color(0.3, 1.0, 0.4)

func _on_coin_collected(total_coins: int, run_coins: int) -> void:
	_update_coins(total_coins, run_coins)

func _update_coins(total_coins: int, _run_coins: int) -> void:
	coin_label.text = "🪙 %d" % total_coins
