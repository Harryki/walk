extends Control

@onready var title_label: Label = $CenterContainer/Panel/VBoxContainer/TitleLabel
@onready var reason_label: Label = $CenterContainer/Panel/VBoxContainer/ReasonLabel
@onready var distance_label: Label = $CenterContainer/Panel/VBoxContainer/DistanceLabel
@onready var coins_label: Label = $CenterContainer/Panel/VBoxContainer/CoinsLabel

# Upgrades
@onready var stamina_btn: Button = $CenterContainer/Panel/VBoxContainer/ShopContainer/StaminaUpgradeBtn
@onready var speed_btn: Button = $CenterContainer/Panel/VBoxContainer/ShopContainer/SpeedUpgradeBtn
@onready var slide_btn: Button = $CenterContainer/Panel/VBoxContainer/ShopContainer/SlideUpgradeBtn

@onready var retry_btn: Button = $CenterContainer/Panel/VBoxContainer/RetryBtn

var _last_coins_earned: int = 0

func _ready() -> void:
	visible = false
	GameManager.game_won.connect(_on_game_won)
	GameManager.game_lost.connect(_on_game_lost)
	
	stamina_btn.pressed.connect(_on_stamina_upgrade_pressed)
	speed_btn.pressed.connect(_on_speed_upgrade_pressed)
	slide_btn.pressed.connect(_on_slide_upgrade_pressed)
	retry_btn.pressed.connect(_on_retry_pressed)

func _on_game_won(distance: float, coins_earned: int) -> void:
	visible = true
	_last_coins_earned = coins_earned
	title_label.text = "🎉 STAGE CLEAR! 🎉"
	title_label.modulate = Color(1.0, 0.85, 0.2)
	reason_label.text = "100m 결승선 돌파 성공!"
	_update_stats_display(distance, coins_earned)
	_update_shop_buttons()

func _on_game_lost(reason: String, distance: float, coins_earned: int) -> void:
	visible = true
	_last_coins_earned = coins_earned
	title_label.text = "💀 GAME OVER"
	title_label.modulate = Color(1.0, 0.3, 0.3)
	reason_label.text = reason
	_update_stats_display(distance, coins_earned)
	_update_shop_buttons()

func _update_stats_display(distance: float, coins_earned: int) -> void:
	distance_label.text = "최종 도달 거리: %.1fm / 100m" % distance
	_render_coins_label(coins_earned)

func _render_coins_label(earned: int) -> void:
	if earned > 0:
		coins_label.text = "획득 코인: +%d 🪙  |  보유 코인: %d 🪙" % [earned, SaveManager.coins]
	else:
		coins_label.text = "보유 코인: %d 🪙" % SaveManager.coins

func _update_shop_buttons() -> void:
	_render_coins_label(_last_coins_earned)
	
	# Stamina Button
	var stam_cost := SaveManager.get_stamina_upgrade_cost()
	if stam_cost == -1:
		stamina_btn.text = "최대 스태미너 (MAX: 140)"
		stamina_btn.disabled = true
	else:
		var next_val: float = SaveManager.STAMINA_VALUES[SaveManager.max_stamina_level + 1]
		stamina_btn.text = "스태미너 강화 (%d ➜ %d) [%d 코인]" % [
			int(SaveManager.get_max_stamina()),
			int(next_val),
			stam_cost
		]
		stamina_btn.disabled = not SaveManager.can_upgrade_stamina()
	
	# Speed Button
	var spd_cost := SaveManager.get_speed_upgrade_cost()
	if spd_cost == -1:
		speed_btn.text = "기본 걷기 속도 (MAX: 1.6m/s)"
		speed_btn.disabled = true
	else:
		var next_spd: float = SaveManager.SPEED_VALUES[SaveManager.base_speed_level + 1]
		speed_btn.text = "기본 속도 강화 (%.1f ➜ %.1f m/s) [%d 코인]" % [
			SaveManager.get_base_speed(),
			next_spd,
			spd_cost
		]
		speed_btn.disabled = not SaveManager.can_upgrade_speed()
	
	# Slide Button
	if SaveManager.slide_unlocked:
		slide_btn.text = "슬라이드 돌파 (해금 완료 ✅)"
		slide_btn.disabled = true
	else:
		slide_btn.text = "슬라이드 돌파 해금 [%d 코인]" % SaveManager.SLIDE_COST
		slide_btn.disabled = not SaveManager.can_unlock_slide()

func _on_stamina_upgrade_pressed() -> void:
	if SaveManager.upgrade_stamina():
		_update_shop_buttons()

func _on_speed_upgrade_pressed() -> void:
	if SaveManager.upgrade_speed():
		_update_shop_buttons()

func _on_slide_upgrade_pressed() -> void:
	if SaveManager.unlock_slide():
		_update_shop_buttons()

func _on_retry_pressed() -> void:
	visible = false
	GameManager.restart_game()
