class_name Player
extends CharacterBody3D

signal lane_changed(new_lane: int)

const LANES: Array[float] = [2.0, 1.0, 0.0, -1.0, -2.0]
const MIN_LANE: int = -2
const MAX_LANE: int = 2

# Speed & Boost parameters
var base_speed: float = 1.0
const TAP_BOOST: float = 0.5
const MAX_SPEED: float = 16.0
const SPEED_DECAY_DELAY: float = 0.25
const SPEED_DECAY_RATE: float = 2.0 # Smoother, more satisfying decay

var current_speed: float = 1.0
var time_since_last_tap: float = 0.0

# Stamina parameters
var max_stamina: float = 100.0
var current_stamina: float = 100.0
const TAP_STAMINA_COST: float = 5.0
const STAMINA_RECOVERY_RATE: float = 15.0 # per second
var is_exhausted: bool = false
var exhausted_timer: float = 0.0
const EXHAUSTED_DURATION: float = 2.0

# Lane change tween
var current_lane: int = 0
var target_x: float = 0.0
var lane_tween: Tween

# Slide parameters
const SLIDE_DURATION: float = 0.4
const SLIDE_COOLDOWN: float = 5.0
const SLIDE_STAMINA_COST: float = 25.0
const SLIDE_SPEED_BONUS: float = 10.0 # 4.0m / 0.4s
var is_sliding: bool = false
var slide_timer: float = 0.0
var slide_cooldown_timer: float = 0.0

# Health & Invincibility
var is_invincible: bool = false
var invincibility_timer: float = 0.0
const INVINCIBILITY_DURATION: float = 1.0

# Pointer & touch input detection
var touch_start_pos: Vector2 = Vector2.ZERO
var touch_start_time: float = 0.0
var is_touch_active: bool = false
var has_swiped: bool = false
const SWIPE_THRESHOLD: float = 30.0 # pixels
const TAP_MAX_DURATION: float = 0.35 # seconds for tap vs hold
var current_door_target: Node3D = null

# Visual nodes
@onready var visual_root: Node3D = $Visuals
@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var head_mesh: MeshInstance3D = $Visuals/Head
@onready var aura_mesh: MeshInstance3D = $Visuals/SlideAura
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# Hopping animation
var hop_time: float = 0.0

func _ready() -> void:
	base_speed = SaveManager.get_base_speed()
	max_stamina = SaveManager.get_max_stamina()
	current_stamina = max_stamina
	current_speed = base_speed
	target_x = LANES[current_lane + 2]
	position = Vector3(target_x, 0.0, 0.0)
	
	if aura_mesh:
		aura_mesh.visible = false
	
	_emit_stamina()

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	_handle_invincibility(delta)
	_update_visual_hop(delta)

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	_handle_stamina(delta)
	_handle_speed_decay(delta)
	_handle_slide_timers(delta)
	
	# Forward velocity (physics-based slide bonus ensures clean collision and zero tunneling)
	var forward_speed := current_speed
	if is_sliding:
		forward_speed += SLIDE_SPEED_BONUS
	
	velocity.z = forward_speed
	velocity.y = 0.0
	velocity.x = 0.0
	
	move_and_slide()
	
	GameManager.update_distance(global_position.z)

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	# 1. Action-based keyboard/button inputs
	if event.is_action_pressed(&"tap_boost"):
		try_tap_boost()
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed(&"move_left"):
		change_lane(-1)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed(&"move_right"):
		change_lane(1)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed(&"slide"):
		try_slide()
		get_viewport().set_input_as_handled()
		return
	
	# 2. Pointer gestures (Touch & Mouse Drag/Swipe & Tap)
	if event is InputEventScreenTouch:
		_process_pointer_touch(event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_process_pointer_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_process_pointer_touch(event.position, event.pressed)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_process_pointer_drag(event.position)

func _process_pointer_touch(pos: Vector2, pressed: bool) -> void:
	if pressed:
		touch_start_pos = pos
		touch_start_time = Time.get_ticks_msec() / 1000.0
		is_touch_active = true
		has_swiped = false
	else:
		if not is_touch_active:
			return
		is_touch_active = false
		
		# If user didn't swipe yet, check if release motion counts as swipe or tap
		if not has_swiped:
			var swipe_vec: Vector2 = pos - touch_start_pos
			if swipe_vec.length() >= SWIPE_THRESHOLD:
				has_swiped = true
				_execute_swipe_gesture(swipe_vec)
			else:
				var elapsed: float = (Time.get_ticks_msec() / 1000.0) - touch_start_time
				if elapsed <= TAP_MAX_DURATION:
					try_tap_boost()

func _process_pointer_drag(pos: Vector2) -> void:
	if not is_touch_active or has_swiped:
		return
	
	var drag_vec: Vector2 = pos - touch_start_pos
	if drag_vec.length() >= SWIPE_THRESHOLD:
		has_swiped = true
		_execute_swipe_gesture(drag_vec)

func _execute_swipe_gesture(vec: Vector2) -> void:
	if absf(vec.x) > absf(vec.y):
		if vec.x < -SWIPE_THRESHOLD:
			change_lane(-1)
		elif vec.x > SWIPE_THRESHOLD:
			change_lane(1)
	else:
		if vec.y < -SWIPE_THRESHOLD:
			try_slide()

func try_tap_boost() -> void:
	if is_exhausted:
		return
	
	if current_stamina < TAP_STAMINA_COST:
		_trigger_exhaustion()
		return
	
	current_stamina -= TAP_STAMINA_COST
	current_speed = minf(current_speed + TAP_BOOST, MAX_SPEED)
	time_since_last_tap = 0.0
	
	_punch_visual_scale()
	
	if current_stamina <= 0.0:
		current_stamina = 0.0
		_trigger_exhaustion()
	
	_emit_stamina()

func _trigger_exhaustion() -> void:
	is_exhausted = true
	exhausted_timer = EXHAUSTED_DURATION
	current_speed = base_speed
	_emit_stamina()

func _handle_stamina(delta: float) -> void:
	if is_exhausted:
		exhausted_timer -= delta
		if exhausted_timer <= 0.0:
			is_exhausted = false
			current_stamina = 1.0
			_emit_stamina()
	else:
		if time_since_last_tap > SPEED_DECAY_DELAY and current_stamina < max_stamina:
			current_stamina = minf(current_stamina + STAMINA_RECOVERY_RATE * delta, max_stamina)
			_emit_stamina()

func _handle_speed_decay(delta: float) -> void:
	if is_sliding:
		return
		
	time_since_last_tap += delta
	if time_since_last_tap >= SPEED_DECAY_DELAY and current_speed > base_speed:
		current_speed = move_toward(current_speed, base_speed, SPEED_DECAY_RATE * delta)

func try_slide() -> void:
	if not SaveManager.is_slide_unlocked():
		return
	if is_sliding or slide_cooldown_timer > 0.0:
		return
	if current_stamina < SLIDE_STAMINA_COST:
		return
	
	current_stamina -= SLIDE_STAMINA_COST
	_emit_stamina()
	
	is_sliding = true
	slide_timer = SLIDE_DURATION
	slide_cooldown_timer = SLIDE_COOLDOWN
	
	if aura_mesh:
		aura_mesh.visible = true
	
	GameManager.slide_cooldown_updated.emit(SLIDE_COOLDOWN, SLIDE_COOLDOWN)

func _handle_slide_timers(delta: float) -> void:
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			is_sliding = false
			if aura_mesh:
				aura_mesh.visible = false
	
	if slide_cooldown_timer > 0.0:
		slide_cooldown_timer = maxf(slide_cooldown_timer - delta, 0.0)
		GameManager.slide_cooldown_updated.emit(slide_cooldown_timer, SLIDE_COOLDOWN)

func change_lane(direction: int) -> void:
	# If player is in front of an enterable shop door and swipes left on the door lane
	if direction < 0 and current_door_target != null and is_instance_valid(current_door_target):
		if current_lane == MIN_LANE:
			try_enter_shop()
			return
	
	var next_lane := clampi(current_lane + direction, MIN_LANE, MAX_LANE)
	if next_lane == current_lane:
		return
	
	current_lane = next_lane
	target_x = LANES[current_lane + 2]
	
	if lane_tween and lane_tween.is_valid():
		lane_tween.kill()
	
	lane_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	lane_tween.tween_property(self, "position:x", target_x, 0.12)
	
	# Tilt body slightly towards move direction
	var tilt_angle := 0.2 if direction < 0 else -0.2
	if visual_root:
		visual_root.rotation.z = tilt_angle
		lane_tween.parallel().tween_property(visual_root, "rotation:z", 0.0, 0.12)
	
	lane_changed.emit(current_lane)

func try_enter_shop() -> void:
	if current_door_target and is_instance_valid(current_door_target):
		var target_shop = current_door_target
		current_door_target = null
		if target_shop.has_method(&"enter_shop"):
			target_shop.enter_shop(self)

func hit_by_obstacle() -> void:
	if is_invincible or is_sliding:
		return
	
	is_invincible = true
	invincibility_timer = INVINCIBILITY_DURATION
	GameManager.take_damage(1)

func _handle_invincibility(delta: float) -> void:
	if not is_invincible:
		return
	
	invincibility_timer -= delta
	if visual_root:
		visual_root.visible = fmod(invincibility_timer, 0.15) > 0.075
	
	if invincibility_timer <= 0.0:
		is_invincible = false
		if visual_root:
			visual_root.visible = true

func _update_visual_hop(delta: float) -> void:
	if not visual_root or is_sliding:
		return
	
	var hop_speed: float = current_speed * 2.2 + 5.0
	hop_time += delta * hop_speed
	var hop_height: float = absf(sin(hop_time)) * 0.06
	visual_root.position.y = hop_height
	visual_root.rotation.x = deg_to_rad(5.0)

func _punch_visual_scale() -> void:
	if not visual_root:
		return
	visual_root.scale = Vector3(1.15, 0.85, 1.15)
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(visual_root, "scale", Vector3.ONE, 0.15)

func _emit_stamina() -> void:
	GameManager.stamina_updated.emit(current_stamina, max_stamina, is_exhausted)
