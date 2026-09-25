extends Control

# Top Header Nodes
@onready var safe_margin: MarginContainer = %SafeMargin
@onready var time_label: Label = %TimeLabel
@onready var time_badge: PanelContainer = %TimeBadge
@onready var distance_bar: ProgressBar = %DistanceProgressBar
@onready var distance_label: Label = %DistanceLabel
@onready var distance_sticker: PanelContainer = %DistanceSticker
@onready var coin_label: Label = %CoinLabel
@onready var coin_badge: PanelContainer = %CoinBadge
@onready var hp_container: HBoxContainer = %HPContainer
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var stamina_label: Label = %StaminaLabel

# Center Notification Nodes
@onready var traffic_alert_banner: PanelContainer = %TrafficAlertBanner
@onready var alert_icon: Label = %AlertIcon
@onready var alert_title: Label = %AlertTitle
@onready var alert_countdown: Label = %AlertCountdown
@onready var boost_comic_pop: PanelContainer = %BoostComicPop
@onready var boost_pop_label: Label = %BoostPopLabel

# Bottom Control Buttons
@onready var btn_boost: Button = %BtnBoost
@onready var btn_slide: Button = %BtnSlide
@onready var slide_timer_label: Label = %SlideTimerLabel

var heart_nodes: Array[Label] = []
var _boost_tween: Tween
var _exhausted_tween: Tween
var _coin_tween: Tween
var _time_tween: Tween
var _rapid_tap_count: int = 0
var _last_tap_time: float = 0.0

func _ready() -> void:
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	
	# Cache and setup pivot offsets for centered pop/squash animations
	for child in hp_container.get_children():
		if child is Label:
			child.pivot_offset = Vector2(12.0, 12.0)
			heart_nodes.append(child)
	
	if time_badge:
		time_badge.pivot_offset = time_badge.size / 2.0
	if coin_badge:
		coin_badge.pivot_offset = coin_badge.size / 2.0
	if distance_sticker:
		distance_sticker.pivot_offset = distance_sticker.size / 2.0
	if btn_boost:
		btn_boost.pivot_offset = Vector2(120.0, 38.0)
	if btn_slide:
		btn_slide.pivot_offset = Vector2(80.0, 38.0)
	if traffic_alert_banner:
		traffic_alert_banner.pivot_offset = Vector2(120.0, 60.0)
	if boost_comic_pop:
		boost_comic_pop.pivot_offset = Vector2(110.0, 35.0)

	_bind_signals()
	_update_coins(SaveManager.coins, 0)
	_update_slide_cooldown(0.0, 5.0)

func _bind_signals() -> void:
	GameManager.time_updated.connect(_on_time_updated)
	GameManager.distance_updated.connect(_on_distance_updated)
	GameManager.hp_updated.connect(_on_hp_updated)
	GameManager.stamina_updated.connect(_on_stamina_updated)
	GameManager.slide_cooldown_updated.connect(_on_slide_cooldown_updated)
	GameManager.coin_collected.connect(_on_coin_collected)
	if GameManager.has_signal("traffic_wait_updated"):
		GameManager.traffic_wait_updated.connect(_on_traffic_wait_updated)

	if btn_boost:
		btn_boost.pressed.connect(_on_boost_pressed)
	if btn_slide:
		btn_slide.pressed.connect(func():
			_trigger_action(&"slide")
			_punch_button(btn_slide)
		)

func _trigger_action(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)

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

func _on_boost_pressed() -> void:
	_trigger_action(&"tap_boost")
	_punch_button(btn_boost)
	
	# Track rapid tapping for comic boost badge burst
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_tap_time < 0.35:
		_rapid_tap_count += 1
		if _rapid_tap_count >= 3:
			show_boost_comic_popup()
			_rapid_tap_count = 0
	else:
		_rapid_tap_count = 1
	_last_tap_time = now

func _punch_button(btn: Control) -> void:
	if not btn:
		return
	btn.pivot_offset = btn.size / 2.0
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.05)
	tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.08)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.06)

func show_boost_comic_popup() -> void:
	if not boost_comic_pop:
		return
	boost_comic_pop.visible = true
	boost_comic_pop.pivot_offset = boost_comic_pop.size / 2.0
	boost_comic_pop.scale = Vector2(0.3, 0.3)
	boost_comic_pop.rotation_degrees = randf_range(-8.0, 8.0)
	
	if _boost_tween and _boost_tween.is_valid():
		_boost_tween.kill()
	_boost_tween = create_tween().set_parallel(false)
	_boost_tween.tween_property(boost_comic_pop, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_boost_tween.tween_property(boost_comic_pop, "scale", Vector2.ONE, 0.08)
	_boost_tween.tween_interval(0.3)
	_boost_tween.tween_property(boost_comic_pop, "scale", Vector2(0.0, 0.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_boost_tween.tween_callback(func(): boost_comic_pop.visible = false)

func _on_traffic_wait_updated(is_waiting: bool, time_left: float, is_go: bool) -> void:
	update_traffic_alert(is_waiting, time_left, is_go)

func update_traffic_alert(is_waiting: bool, time_left: float, is_go: bool = false) -> void:
	if not traffic_alert_banner:
		return
		
	if is_waiting:
		traffic_alert_banner.visible = true
		alert_icon.text = "🛑"
		alert_title.text = "WAIT!"
		alert_title.modulate = Color("#FF0055")
		alert_countdown.text = "횡단보도 대기: %d초" % int(ceilf(time_left))
		
		if not traffic_alert_banner.is_visible_in_tree() or traffic_alert_banner.scale.x < 0.5:
			traffic_alert_banner.pivot_offset = traffic_alert_banner.size / 2.0
			var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			traffic_alert_banner.scale = Vector2(0.5, 0.5)
			tw.tween_property(traffic_alert_banner, "scale", Vector2.ONE, 0.3)
	elif is_go:
		alert_icon.text = "🟢"
		alert_title.text = "GO!"
		alert_title.modulate = Color("#10E760")
		alert_countdown.text = "신호 변경! 돌진하세요!"
		
		var tw := create_tween()
		tw.tween_property(traffic_alert_banner, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK)
		tw.tween_property(traffic_alert_banner, "scale", Vector2.ZERO, 0.2).set_delay(0.4)
		tw.tween_callback(func(): traffic_alert_banner.visible = false)
	else:
		traffic_alert_banner.visible = false

func _on_time_updated(time_left: float) -> void:
	var minutes := int(time_left / 60.0)
	var seconds := int(time_left) % 60
	var centiseconds := int((time_left - int(time_left)) * 100)
	time_label.text = "%02d:%02d.%02d" % [minutes, seconds, centiseconds]
	
	if time_left < 10.0:
		time_label.modulate = Color("#FF0055")
		time_badge.rotation_degrees = sin(Time.get_ticks_msec() * 0.03) * 3.0
	else:
		time_label.modulate = Color.BLACK
		time_badge.rotation_degrees = 0.0

func _on_distance_updated(current: float, max_dist: float) -> void:
	distance_bar.max_value = max_dist
	distance_bar.value = current
	distance_label.text = "🏃 %.1fm / %.0fm" % [current, max_dist]

func _on_hp_updated(hp: int) -> void:
	for i in range(heart_nodes.size()):
		var heart := heart_nodes[i]
		if i < hp:
			heart.text = "❤️"
			heart.modulate = Color.WHITE
		else:
			if heart.text != "🖤":
				# Heart loss Neo-Brutalist squash pop
				heart.text = "🖤"
				heart.modulate = Color("#636674")
				var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(heart, "scale", Vector2(1.4, 1.4), 0.1)
				tw.tween_property(heart, "scale", Vector2.ONE, 0.1)

func _on_stamina_updated(current: float, max_val: float, is_exhausted: bool) -> void:
	stamina_bar.max_value = max_val
	stamina_bar.value = current
	
	if is_exhausted:
		stamina_label.text = "⚡ 탈진! (2초 대기)"
		stamina_bar.modulate = Color("#FF0055")
		if btn_boost:
			btn_boost.disabled = true
			btn_boost.modulate = Color("#FF0055")
		# Neo-Brutalism high-contrast strobe flash
		if not _exhausted_tween or not _exhausted_tween.is_valid():
			_exhausted_tween = create_tween().set_loops(4)
			_exhausted_tween.tween_property(stamina_bar, "modulate:a", 0.3, 0.1)
			_exhausted_tween.tween_property(stamina_bar, "modulate:a", 1.0, 0.1)
	else:
		stamina_label.text = "⚡ %d / %d" % [int(current), int(max_val)]
		stamina_bar.modulate = Color.WHITE
		if btn_boost:
			btn_boost.disabled = false
			btn_boost.modulate = Color.WHITE

func _on_slide_cooldown_updated(time_left: float, max_time: float) -> void:
	_update_slide_cooldown(time_left, max_time)

func _update_slide_cooldown(time_left: float, _max_time: float) -> void:
	if not SaveManager.is_slide_unlocked():
		btn_slide.disabled = true
		btn_slide.modulate = Color("#636674")
		slide_timer_label.text = "🔒 잠김"
		return
		
	if time_left > 0.0:
		btn_slide.disabled = true
		btn_slide.modulate = Color(0.75, 0.75, 0.75)
		slide_timer_label.text = "%.1fs" % time_left
	else:
		btn_slide.disabled = false
		btn_slide.modulate = Color.WHITE
		slide_timer_label.text = "READY! 💨"

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
	coin_label.text = "🪙 %d" % total
