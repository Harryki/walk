@tool
class_name Player
extends CharacterBody3D

signal lane_changed(new_lane: int)

const LANES: Array[float] = [2.0, 1.0, 0.0, -1.0, -2.0]
const MIN_LANE: int = -2
const MAX_LANE: int = 2

@export_range(0.5, 2.5, 0.05) var character_scale: float = 1.0:
	set(val):
		character_scale = val
		_apply_character_scale()

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
const SWIPE_THRESHOLD: float = 32.0 # pixels
const TAP_MAX_DURATION: float = 0.35 # seconds for tap vs hold
var last_swipe_time: float = 0.0
const SWIPE_CHAIN_COOLDOWN: float = 0.12 # matches lane_tween duration
var current_door_target: Node3D = null

# Screen-aligned directions
const SCREEN_RIGHT := Vector2(1.0, 0.0)
const SCREEN_LEFT := Vector2(-1.0, 0.0)
const SCREEN_UP := Vector2(0.0, -1.0)
const SCREEN_DOWN := Vector2(0.0, 1.0)

# Default fallback isometric axes matching the camera projection (approx. 22-degree skew)
const DEFAULT_ISO_RIGHT := Vector2(0.9275, 0.3739)
const DEFAULT_ISO_LEFT := Vector2(-0.9275, -0.3739)
const DEFAULT_ISO_UP := Vector2(0.6134, -0.7898)
const DEFAULT_ISO_DOWN := Vector2(-0.6134, 0.7898)

# Traffic light / Crosswalk waiting state
var is_waiting_at_signal: bool = false
var waiting_traffic_light: TrafficLight = null
var waiting_stop_z: float = 0.0
var wait_label: Label3D = null

# Visual nodes
@onready var visual_root: Node3D = $Visuals
@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var head_mesh: MeshInstance3D = $Visuals/Head
@onready var aura_mesh: MeshInstance3D = $Visuals/SlideAura
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var footstep_audio: AudioStreamPlayer = get_node_or_null("FootstepAudio")

# Footstep Audio (Footstep 1, 2, 3)
const FOOTSTEP_SOUNDS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/footstep1.mp3"),
	preload("res://assets/audio/sfx/footstep2.mp3"),
	preload("res://assets/audio/sfx/footstep3.mp3")
]
var _last_footstep_idx: int = -1

# Hit / Damage Sound
const OOF_SOUND: AudioStream = preload("res://assets/audio/sfx/oof.mp3")

# Hopping animation
var hop_time: float = 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_character_scale()
		return
	
	base_speed = SaveManager.get_base_speed()
	max_stamina = SaveManager.get_max_stamina()
	current_stamina = max_stamina
	current_speed = base_speed
	target_x = LANES[current_lane + 2]
	position = Vector3(target_x, 0.0, 0.0)
	
	if aura_mesh:
		aura_mesh.visible = false
	
	# Create wait status label above player head
	wait_label = Label3D.new()
	wait_label.text = "🛑 대기중"
	wait_label.position = Vector3(0.0, 1.8, 0.0)
	wait_label.font_size = 28
	wait_label.outline_size = 6
	wait_label.modulate = Color(1.0, 0.3, 0.3)
	wait_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	wait_label.visible = false
	add_child(wait_label)
	
	_apply_character_scale()
	_emit_stamina()

func _apply_character_scale() -> void:
	var v := visual_root if visual_root else (get_node_or_null("Visuals") as Node3D)
	if v:
		v.scale = Vector3.ONE * character_scale
	var col := collision_shape if collision_shape else (get_node_or_null("CollisionShape3D") as CollisionShape3D)
	if col and col.shape is BoxShape3D:
		col.shape.size = Vector3(0.6, 1.0, 0.6) * character_scale
		col.position.y = 0.5 * character_scale

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	_handle_invincibility(delta)
	_update_visual_hop(delta)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	_handle_stamina(delta)
	_handle_speed_decay(delta)
	_handle_slide_timers(delta)
	
	# Handle Crosswalk Red Light Waiting
	if is_waiting_at_signal:
		# When traffic light turns green or warning, immediately unblock all waiting characters
		if waiting_traffic_light == null or waiting_traffic_light.is_safe_to_cross():
			end_crosswalk_wait()
		else:
			global_position.z = waiting_stop_z
			velocity.z = 0.0
			
			# Update wait label dynamically based on traffic light remaining red duration
			var remaining := waiting_traffic_light.get_remaining_time()
			if wait_label:
				wait_label.text = "🛑 대기중 (%d초)" % int(ceilf(remaining))
			GameManager.traffic_wait_updated.emit(true, remaining, false)
			
			move_and_slide()
			GameManager.update_distance(global_position.z)
			return
	
	# Forward velocity (physics-based slide bonus ensures clean collision and zero tunneling)
	var forward_speed := current_speed
	if is_sliding:
		forward_speed += SLIDE_SPEED_BONUS
	
	velocity.z = forward_speed
	velocity.y = 0.0
	velocity.x = 0.0
	
	move_and_slide()
	
	GameManager.update_distance(global_position.z)

func start_crosswalk_wait(light: TrafficLight) -> void:
	if is_waiting_at_signal:
		return
	is_waiting_at_signal = true
	waiting_traffic_light = light
	waiting_stop_z = global_position.z # Pause exactly where player was standing
	velocity.z = 0.0
	
	if is_sliding:
		is_sliding = false
		if aura_mesh:
			aura_mesh.visible = false
	
	var remaining := light.get_remaining_time() if light else 3.0
	if wait_label:
		wait_label.visible = true
		wait_label.modulate = Color(1.0, 0.3, 0.3)
		wait_label.text = "🛑 대기중 (%d초)" % int(ceilf(remaining))
	GameManager.traffic_wait_updated.emit(true, remaining, false)

func end_crosswalk_wait() -> void:
	is_waiting_at_signal = false
	waiting_traffic_light = null
	current_speed = base_speed
	GameManager.traffic_wait_updated.emit(false, 0.0, true)
	if wait_label:
		wait_label.text = "GO! 🟢"
		wait_label.modulate = Color(0.2, 1.0, 0.4)
		var t := create_tween()
		t.tween_property(wait_label, "scale", Vector3(1.3, 1.3, 1.3), 0.15)
		t.tween_property(wait_label, "scale", Vector3.ONE, 0.15)
		t.tween_callback(func(): if not is_waiting_at_signal: wait_label.visible = false).set_delay(0.4)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
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
	if not is_touch_active:
		return
	
	var current_time := Time.get_ticks_msec() / 1000.0
	var drag_vec: Vector2 = pos - touch_start_pos
	
	if drag_vec.length() >= SWIPE_THRESHOLD:
		if not has_swiped:
			has_swiped = true
			last_swipe_time = current_time
			touch_start_pos = pos
			_execute_swipe_gesture(drag_vec)
		elif current_time - last_swipe_time >= SWIPE_CHAIN_COOLDOWN:
			# Allows smooth chained swipes without having to lift finger
			last_swipe_time = current_time
			touch_start_pos = pos
			_execute_swipe_gesture(drag_vec)

func _get_projected_axes() -> Dictionary:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		var p0 := cam.unproject_position(global_position)
		var p_left := cam.unproject_position(global_position + Vector3(1.0, 0.0, 0.0))
		var p_fwd := cam.unproject_position(global_position + Vector3(0.0, 0.0, 1.0))
		var iso_l := (p_left - p0).normalized()
		var iso_u := (p_fwd - p0).normalized()
		return {
			"right": -iso_l,
			"left": iso_l,
			"up": iso_u,
			"down": -iso_u
		}
	return {
		"right": DEFAULT_ISO_RIGHT,
		"left": DEFAULT_ISO_LEFT,
		"up": DEFAULT_ISO_UP,
		"down": DEFAULT_ISO_DOWN
	}

func _execute_swipe_gesture(vec: Vector2) -> void:
	if vec.length_squared() < 0.001:
		return
	
	var dir := vec.normalized()
	var iso_axes := _get_projected_axes()
	
	# Score against both screen-aligned and isometric axes:
	# Crossy Road-style dual basis matching ensures intuitive controls whether swiping
	# flat across the screen or diagonally along the isometric road perspective.
	var score_right: float = maxf(dir.dot(SCREEN_RIGHT), dir.dot(iso_axes["right"]))
	var score_left: float = maxf(dir.dot(SCREEN_LEFT), dir.dot(iso_axes["left"]))
	var score_up: float = maxf(dir.dot(SCREEN_UP), dir.dot(iso_axes["up"]))
	var score_down: float = maxf(dir.dot(SCREEN_DOWN), dir.dot(iso_axes["down"]))
	
	var max_score := maxf(maxf(score_right, score_left), maxf(score_up, score_down))
	
	if max_score == score_left:
		change_lane(-1)
	elif max_score == score_right:
		change_lane(1)
	elif max_score == score_up:
		try_slide()
	elif max_score == score_down:
		# Downward swipe provides gentle deceleration if running above base speed
		if current_speed > base_speed:
			current_speed = maxf(current_speed - 2.0, base_speed)

func try_tap_boost() -> void:
	if is_exhausted or is_waiting_at_signal:
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
	if not SaveManager.is_slide_unlocked() or is_waiting_at_signal:
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
	play_oof_sound()
	GameManager.take_damage(1)

func play_oof_sound() -> void:
	if Engine.is_editor_hint():
		return
	if AudioManager:
		AudioManager.play_sfx(OOF_SOUND, &"PlayerSFX", randf_range(0.96, 1.04))

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
	if not visual_root or is_sliding or is_waiting_at_signal:
		if is_waiting_at_signal and visual_root:
			visual_root.position.y = 0.0
		return
	
	var hop_speed: float = current_speed * 2.2 + 5.0
	var prev_hop := hop_time
	hop_time += delta * hop_speed
	var hop_height: float = absf(sin(hop_time)) * 0.08 * character_scale
	visual_root.position.y = hop_height
	visual_root.rotation.x = deg_to_rad(5.0)
	
	# Play footstep synchronized with ground landing (every PI radians)
	if int(hop_time / PI) > int(prev_hop / PI):
		_play_footstep()

func _play_footstep() -> void:
	if Engine.is_editor_hint():
		return
	if is_sliding or is_waiting_at_signal:
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if FOOTSTEP_SOUNDS.is_empty():
		return
	
	var audio := footstep_audio if footstep_audio else get_node_or_null("FootstepAudio") as AudioStreamPlayer
	if not audio:
		audio = AudioStreamPlayer.new()
		audio.name = "FootstepAudio"
		audio.bus = &"PlayerSFX"
		audio.max_polyphony = 3
		add_child(audio)
		footstep_audio = audio
	
	# Randomly play footstep 1, 2, or 3 avoiding consecutive repeats
	var idx := randi() % FOOTSTEP_SOUNDS.size()
	if idx == _last_footstep_idx and FOOTSTEP_SOUNDS.size() > 1:
		idx = (idx + 1 + randi() % (FOOTSTEP_SOUNDS.size() - 1)) % FOOTSTEP_SOUNDS.size()
	_last_footstep_idx = idx
	
	audio.stream = FOOTSTEP_SOUNDS[idx]
	# Subtle natural pitch jitter (0.94 ~ 1.06)
	audio.pitch_scale = randf_range(0.94, 1.06)
	# Volume dynamically scales with running speed
	var speed_ratio := clampf((current_speed - base_speed) / (MAX_SPEED - base_speed), 0.0, 1.0)
	audio.volume_db = lerpf(-4.0, 0.5, speed_ratio)
	audio.play()

func _punch_visual_scale() -> void:
	if not visual_root:
		return
	visual_root.scale = Vector3(1.15, 0.85, 1.15) * character_scale
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(visual_root, "scale", Vector3.ONE * character_scale, 0.15)

func _emit_stamina() -> void:
	GameManager.stamina_updated.emit(current_stamina, max_stamina, is_exhausted)
