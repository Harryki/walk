extends Control

# Top Header Nodes
@onready var safe_margin: MarginContainer = %SafeMargin
@onready var score_label: Label = %ScoreLabel
@onready var score_badge: PanelContainer = %ScoreBadge
@onready var distance_bar: ProgressBar = %DistanceProgressBar
@onready var distance_label: Label = %DistanceLabel
@onready var distance_sticker: PanelContainer = %DistanceSticker
@onready var coin_label: Label = %CoinLabel
@onready var coin_badge: PanelContainer = %CoinBadge
@onready var hp_container: HBoxContainer = %HPContainer

# Center Notification Nodes
@onready var traffic_alert_banner: PanelContainer = %TrafficAlertBanner
@onready var alert_icon: Label = %AlertIcon
@onready var alert_title: Label = %AlertTitle
@onready var alert_countdown: Label = %AlertCountdown
@onready var boost_comic_pop: PanelContainer = %BoostComicPop
@onready var boost_pop_label: Label = %BoostPopLabel

var heart_nodes: Array[TextureRect] = []
var _boost_tween: Tween
var _coin_tween: Tween

const HEART_ACTIVE_COLOR := Color.WHITE
const HEART_DEPLETED_COLOR := Color(0.25, 0.26, 0.32, 0.45)

func _ready() -> void:
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	
	# Cache and setup pivot offsets for centered pop/squash animations
	for child in hp_container.get_children():
		if child is TextureRect:
			child.pivot_offset = Vector2(14.0, 14.0)
			heart_nodes.append(child)
	
	if score_badge:
		score_badge.pivot_offset = score_badge.size / 2.0
		score_label.text = "BEST %.0fm" % SaveManager.best_distance
	if coin_badge:
		coin_badge.pivot_offset = coin_badge.size / 2.0
	if distance_sticker:
		distance_sticker.pivot_offset = distance_sticker.size / 2.0
	if traffic_alert_banner:
		traffic_alert_banner.pivot_offset = Vector2(120.0, 60.0)
	if boost_comic_pop:
		boost_comic_pop.pivot_offset = Vector2(110.0, 35.0)

	_bind_signals()
	_update_coins(SaveManager.coins, 0)
	_on_distance_updated(0.0, SaveManager.best_distance)

func _bind_signals() -> void:
	GameManager.distance_updated.connect(_on_distance_updated)
	GameManager.hp_updated.connect(_on_hp_updated)
	GameManager.coin_collected.connect(_on_coin_collected)
	if GameManager.has_signal("traffic_wait_updated"):
		GameManager.traffic_wait_updated.connect(_on_traffic_wait_updated)

func _apply_safe_area() -> void:
	if not safe_margin:
		return
	var safe_area := DisplayServer.get_display_safe_area()
	var screen_size := DisplayServer.screen_get_size()
	
	var base_top := 24
	var base_bottom := 20
	var base_lr := 16
	
	if screen_size.x > 0 and screen_size.y > 0 and safe_area.size.y < screen_size.y:
		var scale_y := float(get_viewport().get_visible_rect().size.y) / float(screen_size.y)
		var scale_x := float(get_viewport().get_visible_rect().size.x) / float(screen_size.x)
		safe_margin.add_theme_constant_override("margin_top", maxi(base_top, int(safe_area.position.y * scale_y) + 6))
		safe_margin.add_theme_constant_override("margin_bottom", maxi(base_bottom, int((screen_size.y - (safe_area.position.y + safe_area.size.y)) * scale_y) + 8))
		safe_margin.add_theme_constant_override("margin_left", maxi(base_lr, int(safe_area.position.x * scale_x)))
		safe_margin.add_theme_constant_override("margin_right", maxi(base_lr, int((screen_size.x - (safe_area.position.x + safe_area.size.x)) * scale_x)))
	else:
		safe_margin.add_theme_constant_override("margin_top", base_top)
		safe_margin.add_theme_constant_override("margin_bottom", base_bottom)
		safe_margin.add_theme_constant_override("margin_left", base_lr)
		safe_margin.add_theme_constant_override("margin_right", base_lr)

func show_boost_comic_popup(custom_text: String = "") -> void:
	if not boost_comic_pop:
		return
	if custom_text != "":
		boost_pop_label.text = custom_text
	else:
		boost_pop_label.text = "CLOSE CALL!"
	boost_comic_pop.visible = true
	boost_comic_pop.pivot_offset = boost_comic_pop.size / 2.0
	boost_comic_pop.scale = Vector2(0.3, 0.3)
	boost_comic_pop.rotation_degrees = randf_range(-8.0, 8.0)
	
	if _boost_tween and _boost_tween.is_valid():
		_boost_tween.kill()
	_boost_tween = create_tween().set_parallel(false)
	_boost_tween.tween_property(boost_comic_pop, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_boost_tween.tween_property(boost_comic_pop, "scale", Vector2.ONE, 0.08)
	_boost_tween.tween_interval(0.35)
	_boost_tween.tween_property(boost_comic_pop, "scale", Vector2(0.0, 0.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_boost_tween.tween_callback(func(): boost_comic_pop.visible = false)

func _on_traffic_wait_updated(is_waiting: bool, time_left: float, is_go: bool) -> void:
	update_traffic_alert(is_waiting, time_left, is_go)

func update_traffic_alert(is_waiting: bool, time_left: float, is_go: bool = false) -> void:
	if not traffic_alert_banner:
		return
		
	if is_waiting:
		traffic_alert_banner.visible = true
		alert_icon.text = "STOP"
		alert_title.text = "WAIT!"
		alert_title.modulate = Color("#FF0055")
		alert_countdown.text = "횡단보도 대기: %d초" % int(ceilf(time_left))
		
		if not traffic_alert_banner.is_visible_in_tree() or traffic_alert_banner.scale.x < 0.5:
			traffic_alert_banner.pivot_offset = traffic_alert_banner.size / 2.0
			var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			traffic_alert_banner.scale = Vector2(0.5, 0.5)
			tw.tween_property(traffic_alert_banner, "scale", Vector2.ONE, 0.3)
	elif is_go:
		alert_icon.text = "GO"
		alert_title.text = "GO!"
		alert_title.modulate = Color("#10E760")
		alert_countdown.text = "신호 변경! 돌진하세요!"
		
		var tw := create_tween()
		tw.tween_property(traffic_alert_banner, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK)
		tw.tween_property(traffic_alert_banner, "scale", Vector2.ZERO, 0.2).set_delay(0.4)
		tw.tween_callback(func(): traffic_alert_banner.visible = false)
	else:
		traffic_alert_banner.visible = false

func _on_distance_updated(current: float, best_dist: float) -> void:
	var target_max := maxf(best_dist, 100.0)
	distance_bar.max_value = target_max
	distance_bar.value = minf(current, target_max)
	
	if current > best_dist and best_dist > 0.0:
		distance_label.text = "%.1fm (NEW BEST!)" % current
		score_label.text = "NEW! %.0fm" % current
		score_label.modulate = Color("#FF0055")
	else:
		distance_label.text = "%.1fm" % current
		score_label.text = "BEST %.0fm" % best_dist
		score_label.modulate = Color.BLACK

func _on_hp_updated(hp: int) -> void:
	for i in range(heart_nodes.size()):
		var heart := heart_nodes[i]
		if i < hp:
			heart.modulate = HEART_ACTIVE_COLOR
		else:
			if heart.modulate != HEART_DEPLETED_COLOR:
				heart.modulate = HEART_DEPLETED_COLOR
				var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(heart, "scale", Vector2(1.3, 1.3), 0.1)
				tw.tween_property(heart, "scale", Vector2.ONE, 0.1)

func _on_coin_collected(total: int, _run: int) -> void:
	_update_coins(total, _run)
	if coin_badge:
		coin_badge.pivot_offset = coin_badge.size / 2.0
		if _coin_tween and _coin_tween.is_valid():
			_coin_tween.kill()
		_coin_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_coin_tween.tween_property(coin_badge, "scale", Vector2(1.2, 1.2), 0.08)
		_coin_tween.tween_property(coin_badge, "scale", Vector2.ONE, 0.08)

func _update_coins(total: int, _run: int) -> void:
	coin_label.text = "COIN: %d" % total
