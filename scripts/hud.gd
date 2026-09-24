extends Control

@onready var safe_margin: MarginContainer = %SafeMargin
@onready var time_label: Label = %TimeLabel
@onready var distance_bar: ProgressBar = %DistanceProgressBar
@onready var distance_label: Label = %DistanceLabel

@onready var hp_container: HBoxContainer = %HPContainer
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var stamina_label: Label = %StaminaLabel

@onready var slide_panel: PanelContainer = get_node_or_null("%SlidePanel")
@onready var slide_label: Label = get_node_or_null("%SlideLabel")

@onready var coin_label: Label = %CoinLabel

# Mobile on-screen buttons
@onready var btn_left: Button = %BtnLeft
@onready var btn_right: Button = %BtnRight
@onready var btn_boost: Button = %BtnBoost
@onready var btn_slide: Button = %BtnSlide

var heart_nodes: Array[Label] = []

func _ready() -> void:
	# Safe area handling for notch / dynamic island / navigation bar
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	
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
	
	# Mobile button connections
	if btn_left:
		btn_left.pressed.connect(_on_btn_left_pressed)
	if btn_right:
		btn_right.pressed.connect(_on_btn_right_pressed)
	if btn_boost:
		btn_boost.pressed.connect(_on_btn_boost_pressed)
	if btn_slide:
		btn_slide.pressed.connect(_on_btn_slide_pressed)
	
	# Initial UI state
	_update_coins(SaveManager.coins, 0)
	_update_slide_indicator(0.0, 5.0)

func _apply_safe_area() -> void:
	if not safe_margin:
		return
	
	var base_top: int = 24
	var base_bottom: int = 20
	var base_left: int = 16
	var base_right: int = 16
	
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	
	if screen_size.x > 0 and screen_size.y > 0 and safe_area.size.y < screen_size.y:
		var scale_y: float = float(get_viewport().get_visible_rect().size.y) / float(screen_size.y)
		var scale_x: float = float(get_viewport().get_visible_rect().size.x) / float(screen_size.x)
		
		var safe_top := int(safe_area.position.y * scale_y)
		var safe_bottom := int((screen_size.y - (safe_area.position.y + safe_area.size.y)) * scale_y)
		var safe_left := int(safe_area.position.x * scale_x)
		var safe_right := int((screen_size.x - (safe_area.position.x + safe_area.size.x)) * scale_x)
		
		safe_margin.add_theme_constant_override("margin_top", maxi(base_top, safe_top + 8))
		safe_margin.add_theme_constant_override("margin_bottom", maxi(base_bottom, safe_bottom + 8))
		safe_margin.add_theme_constant_override("margin_left", maxi(base_left, safe_left))
		safe_margin.add_theme_constant_override("margin_right", maxi(base_right, safe_right))
	else:
		safe_margin.add_theme_constant_override("margin_top", base_top)
		safe_margin.add_theme_constant_override("margin_bottom", base_bottom)
		safe_margin.add_theme_constant_override("margin_left", base_left)
		safe_margin.add_theme_constant_override("margin_right", base_right)

func _trigger_action(action_name: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	Input.parse_input_event(event)

func _on_btn_left_pressed() -> void:
	_trigger_action(&"move_left")

func _on_btn_right_pressed() -> void:
	_trigger_action(&"move_right")

func _on_btn_boost_pressed() -> void:
	_trigger_action(&"tap_boost")

func _on_btn_slide_pressed() -> void:
	_trigger_action(&"slide")

func _on_time_updated(time_left: float) -> void:
	var minutes := int(time_left / 60.0)
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
		if btn_boost:
			btn_boost.text = "⚡ 탈진 중..."
			btn_boost.modulate = Color(1.0, 0.5, 0.5)
	else:
		stamina_label.text = "⚡ %d / %d" % [int(current), int(max_val)]
		stamina_bar.modulate = Color(0.2, 0.8, 1.0)
		if btn_boost:
			btn_boost.text = "⚡ 대시 (TAP)"
			btn_boost.modulate = Color.WHITE

func _on_slide_cooldown_updated(time_left: float, max_time: float) -> void:
	_update_slide_indicator(time_left, max_time)

func _update_slide_indicator(time_left: float, _max_time: float) -> void:
	if not SaveManager.is_slide_unlocked():
		if slide_label and slide_panel:
			slide_label.text = "💨 잠김 (상점)"
			slide_panel.modulate = Color(0.6, 0.6, 0.6, 0.7)
		if btn_slide:
			btn_slide.disabled = true
			btn_slide.text = "🔒 슬라이드"
			btn_slide.modulate = Color(0.5, 0.5, 0.5, 0.7)
		return
	
	if time_left > 0.0:
		if slide_label and slide_panel:
			slide_label.text = "💨 쿨: %.1fs" % time_left
			slide_panel.modulate = Color(0.7, 0.7, 0.7)
		if btn_slide:
			btn_slide.disabled = true
			btn_slide.text = "💨 %.1fs" % time_left
			btn_slide.modulate = Color(0.6, 0.6, 0.6, 0.8)
	else:
		if slide_label and slide_panel:
			slide_label.text = "💨 준비 완료!"
			slide_panel.modulate = Color(0.3, 1.0, 0.4)
		if btn_slide:
			btn_slide.disabled = false
			btn_slide.text = "💨 돌파"
			btn_slide.modulate = Color.WHITE

func _on_coin_collected(total_coins: int, run_coins: int) -> void:
	_update_coins(total_coins, run_coins)

func _update_coins(total_coins: int, _run_coins: int) -> void:
	coin_label.text = "🪙 %d" % total_coins
