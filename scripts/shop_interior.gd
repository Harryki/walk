class_name ShopInterior
extends Node3D

signal interior_exit_requested

# Layout matched to Runner Isometric Camera (North +Z is screen top, East -X is screen right):
const STATION_POSITIONS: Array[Vector3] = [
	Vector3(1.8, 0.0, -0.5),  # Station 0: Item 1 (Stamina, Screen Left)
	Vector3(0.0, 0.0, -0.5),  # Station 1: Item 2 (Speed, Screen Center)
	Vector3(-1.8, 0.0, -0.5), # Station 2: Item 3 (Slide, Screen Right)
	Vector3(-2.2, 0.0, -1.8)  # Station 3: Exit Mat (Screen Bottom Right)
]

const BUBBLE_POSITIONS: Array[Vector3] = [
	Vector3(1.8, 2.4, 1.2),   # Above Item 1
	Vector3(0.0, 2.4, 1.2),   # Above Item 2
	Vector3(-1.8, 2.4, 1.2),  # Above Item 3
	Vector3(-2.2, 1.8, -1.8)  # Above Exit Mat
]

@onready var camera_spot: Marker3D = $CameraTargetSpot
@onready var bubble_root: Node3D = $SpeechBubble
@onready var bubble_title: Label3D = $SpeechBubble/Title
@onready var bubble_desc: Label3D = $SpeechBubble/Desc
@onready var bubble_cost: Label3D = $SpeechBubble/Cost
@onready var bubble_panel: MeshInstance3D = $SpeechBubble/Panel
@onready var bubble_tail: MeshInstance3D = $SpeechBubble/Tail
@onready var exit_label: Label3D = $ExitMat/ExitLabel

@onready var item1_mesh: Node3D = $Counter/Item1_Stamina/Visual
@onready var item2_mesh: Node3D = $Counter/Item2_Speed/Visual
@onready var item3_mesh: Node3D = $Counter/Item3_Slide/Visual

var current_station: int = 1 # Start at center (Item 2)
var active_player: CharacterBody3D = null
var move_tween: Tween
var bubble_tween: Tween
var is_active: bool = false

# Touch / gesture detection inside shop
var touch_start_pos: Vector2 = Vector2.ZERO
var touch_start_time: float = 0.0
var is_touching: bool = false
const SWIPE_THRESHOLD: float = 30.0

func _ready() -> void:
	if bubble_root:
		bubble_root.visible = false
	_start_item_idle_bob()

func _process(delta: float) -> void:
	if not is_active:
		return
	
	# Rotate item visuals gently
	if item1_mesh:
		item1_mesh.rotate_y(1.2 * delta)
	if item2_mesh:
		item2_mesh.rotate_y(1.5 * delta)
	if item3_mesh:
		item3_mesh.rotate_y(1.0 * delta)

func start_interior(player: CharacterBody3D) -> void:
	is_active = true
	active_player = player
	current_station = 1
	
	if active_player:
		active_player.global_position = global_position + STATION_POSITIONS[current_station]
		active_player.velocity = Vector3.ZERO
		# Face towards the counter (North = +Z)
		if active_player.visual_root:
			active_player.visual_root.rotation.y = 0.0
	
	_update_speech_bubble(true)

func _start_item_idle_bob() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property($Counter/Item1_Stamina, "position:y", 1.15, 0.7).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property($Counter/Item2_Speed, "position:y", 1.18, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property($Counter/Item3_Slide, "position:y", 1.12, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property($Counter/Item1_Stamina, "position:y", 1.05, 0.7).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property($Counter/Item2_Speed, "position:y", 1.08, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property($Counter/Item3_Slide, "position:y", 1.02, 0.8).set_trans(Tween.TRANS_SINE)

func _unhandled_input(event: InputEvent) -> void:
	if not is_active or GameManager.current_state != GameManager.GameState.IN_INTERIOR:
		return
	
	# Keyboard navigation (Left/Right moves between stations)
	if event.is_action_pressed(&"move_left") or (event is InputEventKey and event.pressed and event.keycode == KEY_A):
		move_station(-1)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed(&"move_right") or (event is InputEventKey and event.pressed and event.keycode == KEY_D):
		move_station(1)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed(&"tap_boost") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
		_interact_current_station()
		get_viewport().set_input_as_handled()
		return
	
	# Touch & mouse gesture navigation
	if event is InputEventScreenTouch:
		_handle_pointer_press(event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_handle_pointer_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer_press(event.position, event.pressed)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_handle_pointer_drag(event.position)

func _handle_pointer_press(pos: Vector2, pressed: bool) -> void:
	if pressed:
		touch_start_pos = pos
		touch_start_time = Time.get_ticks_msec() / 1000.0
		is_touching = true
	else:
		if not is_touching:
			return
		is_touching = false
		var diff := pos - touch_start_pos
		var elapsed := (Time.get_ticks_msec() / 1000.0) - touch_start_time
		if diff.length() < SWIPE_THRESHOLD and elapsed < 0.35:
			# Short tap = interact with current station (Buy or Exit)
			_interact_current_station()

func _handle_pointer_drag(pos: Vector2) -> void:
	if not is_touching:
		return
	var diff := pos - touch_start_pos
	if diff.length() >= SWIPE_THRESHOLD:
		is_touching = false
		if absf(diff.x) > absf(diff.y):
			if diff.x < 0:
				move_station(-1) # Swipe left moves to screen-left station
			else:
				move_station(1)  # Swipe right moves to screen-right station
		else:
			if diff.y > 0:
				# Swipe down -> move to exit
				go_to_station(3)
			elif diff.y < 0:
				# Swipe up -> move back to counter
				if current_station == 3:
					go_to_station(1)

func move_station(delta_dir: int) -> void:
	var next_idx := clampi(current_station + delta_dir, 0, STATION_POSITIONS.size() - 1)
	if next_idx == current_station:
		return
	go_to_station(next_idx)

func go_to_station(idx: int) -> void:
	current_station = clampi(idx, 0, STATION_POSITIONS.size() - 1)
	
	if active_player:
		var target_world_pos := global_position + STATION_POSITIONS[current_station]
		if move_tween and move_tween.is_valid():
			move_tween.kill()
		
		move_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		move_tween.tween_property(active_player, "global_position", target_world_pos, 0.22)
		
		# Cute Crossy Road hop
		if active_player.visual_root:
			var hop_tw := create_tween()
			hop_tw.tween_property(active_player.visual_root, "position:y", 0.3, 0.11).set_trans(Tween.TRANS_SINE)
			hop_tw.tween_property(active_player.visual_root, "position:y", 0.0, 0.11).set_trans(Tween.TRANS_SINE)
			
			# Face counter if at items, face exit if at exit
			var target_rot_y: float = 0.0 if current_station < 3 else -PI * 0.25
			active_player.visual_root.rotation.y = target_rot_y
	
	_update_speech_bubble(false)

func _update_speech_bubble(immediate: bool = false) -> void:
	if not bubble_root:
		return
	
	bubble_root.visible = true
	var target_pos := global_position + BUBBLE_POSITIONS[current_station]
	
	# Align speech bubble to face isometric camera plane perfectly
	if InteriorManager.main_camera:
		bubble_root.global_basis = InteriorManager.main_camera.global_basis
	
	if immediate:
		bubble_root.global_position = target_pos
		bubble_root.scale = Vector3.ONE
	else:
		if bubble_tween and bubble_tween.is_valid():
			bubble_tween.kill()
		
		bubble_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bubble_tween.tween_property(bubble_root, "global_position", target_pos, 0.25)
		bubble_root.scale = Vector3(0.7, 0.7, 0.7)
		bubble_tween.tween_property(bubble_root, "scale", Vector3.ONE, 0.25)
	
	# Content based on current station
	match current_station:
		0: # Stamina Upgrade
			bubble_title.text = "⚡ 최대 스태미너 강화"
			var cur_lvl := SaveManager.max_stamina_level
			var max_lvl := 2
			var cur_val := SaveManager.get_max_stamina()
			var cost := SaveManager.get_stamina_upgrade_cost()
			
			if cur_lvl >= max_lvl:
				bubble_desc.text = "최대 레벨 도달! (%.0f)" % cur_val
				bubble_cost.text = "⭐ MAX UPGRADE"
				bubble_cost.modulate = Color(0.4, 0.9, 0.4)
			else:
				var next_val := SaveManager.STAMINA_VALUES[cur_lvl + 1]
				bubble_desc.text = "최대치 %.0f -> %.0f (+20)" % [cur_val, next_val]
				if SaveManager.coins >= cost:
					bubble_cost.text = "💰 %d 코인 [탭하여 구매]" % cost
					bubble_cost.modulate = Color(1.0, 0.85, 0.2)
				else:
					bubble_cost.text = "💰 %d 코인 (코인 부족)" % cost
					bubble_cost.modulate = Color(0.9, 0.35, 0.35)
		1: # Speed Upgrade
			bubble_title.text = "👟 기본 달리기 속도 강화"
			var cur_lvl := SaveManager.base_speed_level
			var max_lvl := 2
			var cur_val := SaveManager.get_base_speed()
			var cost := SaveManager.get_speed_upgrade_cost()
			
			if cur_lvl >= max_lvl:
				bubble_desc.text = "최대 레벨 도달! (%.1f m/s)" % cur_val
				bubble_cost.text = "⭐ MAX UPGRADE"
				bubble_cost.modulate = Color(0.4, 0.9, 0.4)
			else:
				var next_val := SaveManager.SPEED_VALUES[cur_lvl + 1]
				bubble_desc.text = "속도 %.1f -> %.1f m/s" % [cur_val, next_val]
				if SaveManager.coins >= cost:
					bubble_cost.text = "💰 %d 코인 [탭하여 구매]" % cost
					bubble_cost.modulate = Color(1.0, 0.85, 0.2)
				else:
					bubble_cost.text = "💰 %d 코인 (코인 부족)" % cost
					bubble_cost.modulate = Color(0.9, 0.35, 0.35)
		2: # Slide Unlock
			bubble_title.text = "💨 슬라이드 대시 해금"
			var unlocked := SaveManager.is_slide_unlocked()
			var cost := SaveManager.SLIDE_COST
			
			if unlocked:
				bubble_desc.text = "위로 스와이프하여 무적 대시 발동!"
				bubble_cost.text = "✨ 해금 완료 (보유 중)"
				bubble_cost.modulate = Color(0.4, 0.9, 0.4)
			else:
				bubble_desc.text = "보행자 무적 통과 & 초고속 돌파!"
				if SaveManager.coins >= cost:
					bubble_cost.text = "💰 %d 코인 [탭하여 구매]" % cost
					bubble_cost.modulate = Color(1.0, 0.85, 0.2)
				else:
					bubble_cost.text = "💰 %d 코인 (코인 부족)" % cost
					bubble_cost.modulate = Color(0.9, 0.35, 0.35)
		3: # Exit Mat
			bubble_title.text = "🚪 거리로 나가기"
			bubble_desc.text = "달리기를 계속 진행합니다."
			bubble_cost.text = "👉 [탭하여 나가기]"
			bubble_cost.modulate = Color(0.3, 0.85, 1.0)

func _interact_current_station() -> void:
	match current_station:
		0:
			if SaveManager.can_upgrade_stamina():
				SaveManager.upgrade_stamina()
				_pulse_item(item1_mesh)
				_update_speech_bubble(false)
		1:
			if SaveManager.can_upgrade_speed():
				SaveManager.upgrade_speed()
				_pulse_item(item2_mesh)
				_update_speech_bubble(false)
		2:
			if SaveManager.can_unlock_slide():
				SaveManager.unlock_slide()
				_pulse_item(item3_mesh)
				_update_speech_bubble(false)
		3:
			trigger_exit()

func _pulse_item(item_node: Node3D) -> void:
	if not item_node:
		return
	var tw := create_tween()
	tw.tween_property(item_node, "scale", Vector3(1.4, 1.4, 1.4), 0.12).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(item_node, "rotation:y", item_node.rotation.y + TAU, 0.3)
	tw.tween_property(item_node, "scale", Vector3.ONE, 0.15)

func trigger_exit() -> void:
	if not is_active:
		return
	is_active = false
	if bubble_root:
		bubble_root.visible = false
	interior_exit_requested.emit()
	InteriorManager.exit_shop()
