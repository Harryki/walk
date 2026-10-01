extends Control

@onready var title_label: Label = $CenterContainer/Panel/VBoxContainer/TitleLabel
@onready var reason_label: Label = $CenterContainer/Panel/VBoxContainer/ReasonLabel
@onready var distance_label: Label = $CenterContainer/Panel/VBoxContainer/DistanceLabel
@onready var score_label: Label = $CenterContainer/Panel/VBoxContainer/ScoreLabel
@onready var coins_label: Label = $CenterContainer/Panel/VBoxContainer/CoinsLabel
@onready var retry_btn: Button = $CenterContainer/Panel/VBoxContainer/RetryBtn

func _ready() -> void:
	visible = false
	GameManager.game_won.connect(_on_game_won)
	GameManager.game_lost.connect(_on_game_lost)
	retry_btn.pressed.connect(_on_retry_pressed)

func _on_game_won(distance: float, coins_earned: int) -> void:
	# Fallback if triggered
	visible = true
	title_label.text = "STAGE CLEAR!"
	title_label.modulate = Color(1.0, 0.85, 0.2)
	reason_label.text = "기록 달성 완료!"
	_update_stats_display(distance, coins_earned, int(distance * 10.0))

func _on_game_lost(reason: String, distance: float, coins_earned: int, score: int = 0, is_new_record: bool = false) -> void:
	if is_new_record:
		title_label.text = "NEW BEST RECORD!"
		title_label.modulate = Color(1.0, 0.85, 0.2)
	else:
		title_label.text = "RUN FINISHED"
		title_label.modulate = Color(1.0, 0.35, 0.35)
	
	reason_label.text = reason
	_update_stats_display(distance, coins_earned, score)
	
	# Wait for slow-motion ragdoll sequence (1.4s real time)
	await get_tree().create_timer(1.4, true, false, true).timeout
	Engine.time_scale = 1.0
	visible = true

func _update_stats_display(distance: float, coins_earned: int, score: int) -> void:
	distance_label.text = "최종 거리: %.1fm  (최고: %.1fm)" % [distance, SaveManager.best_distance]
	score_label.text = "최종 스코어: %d점  (최고: %d점)" % [score, SaveManager.best_score]
	_render_coins_label(coins_earned)

func _render_coins_label(earned: int) -> void:
	if earned > 0:
		coins_label.text = "획득 코인: +%d  |  보유 코인: %d" % [earned, SaveManager.coins]
	else:
		coins_label.text = "보유 코인: %d" % SaveManager.coins

func _on_retry_pressed() -> void:
	visible = false
	Engine.time_scale = 1.0
	GameManager.restart_game()
