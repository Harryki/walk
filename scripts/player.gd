class_name Player
extends CharacterBody3D

signal lane_changed(new_lane: int)

const LANES: Array[float] = [2.0, 1.0, 0.0, -1.0, -2.0]
const MIN_LANE: int = -2
const MAX_LANE: int = 2

# Speed & Boost parameters
var base_speed: float = 1.0
const TAP_BOOST: float = 0.4
const MAX_SPEED: float = 5.0
const SPEED_DECAY_DELAY: float = 0.2
const SPEED_DECAY_RATE: float = 4.0 # m/s^2 decay rate

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

# Touch input detection
var touch_start_pos: Vector2 = Vector2.ZERO
var touch_start_time: float = 0.0
var is_touch_active: bool = false
const SWIPE_THRESHOLD: float = 30.0 # pixels

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
	
	# 1. Discrete keyboard events (preventing duplicate triggers when mouse emulation is active)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.is_action_pressed(&"move_left"):
			change_lane(-1)
			return
		elif event.is_action_pressed(&"move_right"):
			change_lane(1)
			return
		elif event.is_action_pressed(&"slide"):
			try_slide()
			return
		elif event.is_action_pressed(&"tap_boost"):
			try_tap_boost()
			return
	
	# 2. Touch / Mouse gestures
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start_pos = event.position
			touch_start_time = Time.get_ticks_msec() / 1000.0
			is_touch_active = true
		else:
			if is_touch_active:
				is_touch_active = false
				var swipe_vec: Vector2 = event.position - touch_start_pos
				var duration: float = (Time.get_ticks_msec() / 1000.0) - touch_start_time
				
				if swipe_vec.length() < SWIPE_THRESHOLD and duration < 0.35:
					# Tap boost
					try_tap_boost()
				else:
					# Swipe gesture
					if absf(swipe_vec.x) > absf(swipe_vec.y):
						if swipe_vec.x < -SWIPE_THRESHOLD:
							change_lane(-1)
						elif swipe_vec.x > SWIPE_THRESHOLD:
							change_lane(1)
					else:
						if swipe_vec.y < -SWIPE_THRESHOLD:
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
	
	var hop_speed: float = current_speed * 12.0
	hop_time += delta * hop_speed
	var hop_height: float = absf(sin(hop_time)) * 0.18
	visual_root.position.y = hop_height

func _punch_visual_scale() -> void:
	if not visual_root:
		return
	visual_root.scale = Vector3(1.15, 0.85, 1.15)
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(visual_root, "scale", Vector3.ONE, 0.15)

func _emit_stamina() -> void:
	GameManager.stamina_updated.emit(current_stamina, max_stamina, is_exhausted)
