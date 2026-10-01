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

# Speed & Near-Miss Boost parameters
var base_speed: float = 4.0
const NEAR_MISS_BOOST: float = 2.0
const MAX_SPEED: float = 16.0
const BOOST_HOLD_DURATION: float = 2.0 # Keep top speed for 2 seconds after near miss
const SPEED_DECAY_RATE: float = 3.0   # Smoothly decay towards base_speed after hold duration
const COMBO_TIMEOUT: float = 3.5

var current_speed: float = 4.0
var boost_hold_timer: float = 0.0
var near_miss_combo: int = 0
var combo_reset_timer: float = 0.0

# Lane change tween
var current_lane: int = 0
var target_x: float = 0.0
var lane_tween: Tween

# Health & Invincibility
var is_invincible: bool = false
var invincibility_timer: float = 0.0
const INVINCIBILITY_DURATION: float = 1.0


# Signal wait state
var is_waiting_at_signal: bool = false
var waiting_traffic_light: TrafficLight = null
var waiting_stop_z: float = 0.0
var wait_label: Label3D = null

# Death & Ragdoll state
var is_dead: bool = false
static var _ragdoll_nodes: Array[Node3D] = []
var active_ragdoll_body: RigidBody3D = null

func get_focus_position() -> Vector3:
	if is_dead and is_instance_valid(active_ragdoll_body):
		return active_ragdoll_body.global_position
	return global_position

# Visual nodes
@onready var visual_root: Node3D = $Visuals
@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var head_mesh: MeshInstance3D = $Visuals/Head
@onready var cap_mesh: MeshInstance3D = get_node_or_null("Visuals/Cap")
@onready var cap_bill_mesh: MeshInstance3D = get_node_or_null("Visuals/CapBill")
@onready var eye_l_mesh: MeshInstance3D = get_node_or_null("Visuals/EyeL")
@onready var eye_r_mesh: MeshInstance3D = get_node_or_null("Visuals/EyeR")
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
	current_speed = base_speed
	target_x = LANES[current_lane + 2]
	position = Vector3(target_x, 0.0, 0.0)
	
	# Create wait status label above player head
	wait_label = Label3D.new()
	wait_label.font = preload("res://assets/fonts/Galmuri11.ttf")
	wait_label.text = "대기중"
	wait_label.position = Vector3(0.0, 1.8, 0.0)
	wait_label.font_size = 28
	wait_label.outline_size = 6
	wait_label.modulate = Color(1.0, 0.3, 0.3)
	wait_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	wait_label.visible = false
	add_child(wait_label)
	
	_apply_character_scale()
	
	GameManager.game_started.connect(reset_state)
	GameManager.game_lost.connect(_on_game_lost)

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
	
	_handle_speed_and_combo(delta)
	
	# Handle Crosswalk Red Light Waiting
	if is_waiting_at_signal:
		if waiting_traffic_light == null or waiting_traffic_light.is_safe_to_cross():
			end_crosswalk_wait()
		else:
			global_position.z = waiting_stop_z
			velocity.z = 0.0
			
			var remaining := waiting_traffic_light.get_remaining_time()
			if wait_label:
				wait_label.text = "대기중 (%d초)" % int(ceilf(remaining))
			GameManager.traffic_wait_updated.emit(true, remaining, false)
			
			move_and_slide()
			GameManager.update_distance(global_position.z)
			return
	
	velocity.z = current_speed
	velocity.y = 0.0
	velocity.x = 0.0
	
	move_and_slide()
	
	GameManager.update_distance(global_position.z)

func _handle_speed_and_combo(delta: float) -> void:
	# Combo expiration
	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0:
			near_miss_combo = 0
	
	# Speed hold and gradual decay
	if boost_hold_timer > 0.0:
		boost_hold_timer -= delta
		if boost_hold_timer < 0.0:
			var remaining_delta := -boost_hold_timer
			boost_hold_timer = 0.0
			if current_speed > base_speed:
				current_speed = move_toward(current_speed, base_speed, SPEED_DECAY_RATE * remaining_delta)
	elif current_speed > base_speed:
		current_speed = move_toward(current_speed, base_speed, SPEED_DECAY_RATE * delta)

func trigger_near_miss(_source: Node3D = null) -> void:
	if is_dead or is_waiting_at_signal:
		return
	
	# Boost speed and refresh hold duration
	boost_hold_timer = BOOST_HOLD_DURATION
	near_miss_combo += 1
	combo_reset_timer = COMBO_TIMEOUT
	current_speed = minf(current_speed + NEAR_MISS_BOOST, MAX_SPEED)
	
	_punch_visual_scale()
	
	# Show comic popup on HUD
	var hud := get_tree().get_first_node_in_group(&"hud")
	if not hud:
		hud = get_viewport().get_node_or_null("Main/UI/HUD")
	if hud and hud.has_method(&"show_boost_comic_popup"):
		if near_miss_combo > 1:
			hud.show_boost_comic_popup("COMBO x%d!" % near_miss_combo)
		else:
			hud.show_boost_comic_popup("CLOSE CALL!")
	
	GameManager.near_miss_triggered.emit(near_miss_combo, current_speed)
	
	# Light dynamic audio pop
	if AudioManager:
		AudioManager.play_sfx(FOOTSTEP_SOUNDS[0], &"PlayerSFX", randf_range(1.4, 1.6), 1.0)

func start_crosswalk_wait(light: TrafficLight) -> void:
	if is_waiting_at_signal:
		return
	is_waiting_at_signal = true
	waiting_traffic_light = light
	waiting_stop_z = global_position.z
	velocity.z = 0.0
	
	var remaining := light.get_remaining_time() if light else 3.0
	if wait_label:
		wait_label.visible = true
		wait_label.modulate = Color(1.0, 0.3, 0.3)
		wait_label.text = "대기중 (%d초)" % int(ceilf(remaining))
	GameManager.traffic_wait_updated.emit(true, remaining, false)

func end_crosswalk_wait() -> void:
	is_waiting_at_signal = false
	waiting_traffic_light = null
	current_speed = base_speed
	GameManager.traffic_wait_updated.emit(false, 0.0, true)
	if wait_label:
		wait_label.text = "GO!"
		wait_label.modulate = Color(0.2, 1.0, 0.4)
		var t := create_tween()
		t.tween_property(wait_label, "scale", Vector3(1.3, 1.3, 1.3), 0.15)
		t.tween_property(wait_label, "scale", Vector3.ONE, 0.15)
		t.tween_callback(func(): if not is_waiting_at_signal: wait_label.visible = false).set_delay(0.4)

var last_touch_msec: int = 0
const TOUCH_DEBOUNCE_MS: int = 80

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	# 1. Action-based keyboard/gamepad inputs (allow_echo = false)
	if event.is_action_pressed(&"move_left", false):
		change_lane(-1)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed(&"move_right", false):
		change_lane(1)
		get_viewport().set_input_as_handled()
		return
	
	# 2. 5:5 Left/Right Screen Touch & Click Control (Debounced against duplicate mouse/touch emulation)
	if event is InputEventScreenTouch and event.pressed:
		_handle_screen_touch(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_screen_touch(event.position)
		get_viewport().set_input_as_handled()

func _handle_screen_touch(pos: Vector2) -> void:
	var now := Time.get_ticks_msec()
	if now - last_touch_msec < TOUCH_DEBOUNCE_MS:
		return
	last_touch_msec = now
	
	var screen_width := get_viewport().get_visible_rect().size.x
	if pos.x < screen_width * 0.5:
		change_lane(-1)
	else:
		change_lane(1)

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
	if is_invincible:
		return
	
	# Reset speed to base_speed immediately upon collision!
	current_speed = base_speed
	boost_hold_timer = 0.0
	near_miss_combo = 0
	
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
	if not visual_root or is_waiting_at_signal:
		if is_waiting_at_signal and visual_root:
			visual_root.position.y = 0.0
		return
	
	var hop_speed: float = current_speed * 2.2 + 5.0
	var prev_hop := hop_time
	hop_time += delta * hop_speed
	var hop_height: float = absf(sin(hop_time)) * 0.08 * character_scale
	visual_root.position.y = hop_height
	visual_root.rotation.x = deg_to_rad(5.0)
	
	if int(hop_time / PI) > int(prev_hop / PI):
		_play_footstep()

func _play_footstep() -> void:
	if Engine.is_editor_hint():
		return
	if is_waiting_at_signal:
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
	
	var idx := randi() % FOOTSTEP_SOUNDS.size()
	if idx == _last_footstep_idx and FOOTSTEP_SOUNDS.size() > 1:
		idx = (idx + 1 + randi() % (FOOTSTEP_SOUNDS.size() - 1)) % FOOTSTEP_SOUNDS.size()
	_last_footstep_idx = idx
	
	audio.stream = FOOTSTEP_SOUNDS[idx]
	audio.pitch_scale = randf_range(0.94, 1.06)
	var speed_ratio := clampf((current_speed - base_speed) / (MAX_SPEED - base_speed), 0.0, 1.0)
	audio.volume_db = lerpf(-4.0, 0.5, speed_ratio)
	audio.play()

func _punch_visual_scale() -> void:
	if not visual_root:
		return
	visual_root.scale = Vector3(1.15, 0.85, 1.15) * character_scale
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(visual_root, "scale", Vector3.ONE * character_scale, 0.15)

func reset_state() -> void:
	is_dead = false
	active_ragdoll_body = null
	base_speed = SaveManager.get_base_speed()
	current_speed = base_speed
	boost_hold_timer = 0.0
	near_miss_combo = 0
	combo_reset_timer = 0.0
	set_physics_process(true)
	set_process_input(true)
	if visual_root:
		visual_root.visible = true
	if collision_shape:
		collision_shape.set_deferred(&"disabled", false)
	Engine.time_scale = 1.0
	for piece in _ragdoll_nodes:
		if is_instance_valid(piece):
			piece.queue_free()
	_ragdoll_nodes.clear()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam and cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		cam.size = 15.0

func _on_game_lost(reason: String, _dist: float = 0.0, _coins: int = 0, _score: int = 0, _is_new: bool = false) -> void:
	if not is_inside_tree() or is_dead:
		return
	die(reason, Vector3(0.0, 0.15, 1.0))

func die(reason: String = "사망!", hit_direction: Vector3 = Vector3.ZERO) -> void:
	if not is_inside_tree() or is_dead:
		return
	is_dead = true
	
	current_speed = 0.0
	velocity = Vector3.ZERO
	set_physics_process(false)
	set_process_input(false)
	if collision_shape:
		collision_shape.set_deferred(&"disabled", true)
	
	play_oof_sound()
	
	if AudioManager:
		AudioManager.play_sfx(preload("res://assets/audio/sfx/thud.mp3"), &"PlayerSFX", 0.65, 3.0)
	
	Engine.time_scale = 0.18
	_zoom_camera_on_death()
	_spawn_ragdoll_blocks(hit_direction)
	
	if visual_root:
		visual_root.visible = false
	
	if GameManager and GameManager.current_state == GameManager.GameState.PLAYING:
		GameManager.trigger_game_over(reason)

func _zoom_camera_on_death() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam and cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		var cam_tw := create_tween()
		cam_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		cam_tw.tween_property(cam, "size", 10.5, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _spawn_ragdoll_blocks(hit_direction: Vector3) -> void:
	if not is_inside_tree():
		return
	var p_parent = get_parent()
	if not p_parent or not p_parent.is_inside_tree():
		return
	
	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(60.0, 1.0, 60.0)
	floor_col.shape = floor_box
	floor_body.position = Vector3(0.0, -0.5, global_position.z)
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.add_child(floor_col)
	p_parent.add_child(floor_body)
	_ragdoll_nodes.append(floor_body)
	
	var ragdoll := RigidBody3D.new()
	ragdoll.position = global_position + Vector3(0.0, 0.4 * character_scale, 0.0)
	ragdoll.mass = 12.0
	ragdoll.collision_layer = 0
	ragdoll.collision_mask = 1
	
	var r_mat := PhysicsMaterial.new()
	r_mat.friction = 0.35
	r_mat.bounce = 0.25
	ragdoll.physics_material_override = r_mat
	ragdoll.continuous_cd = true
	
	var r_shape := CollisionShape3D.new()
	var r_box := BoxShape3D.new()
	r_box.size = Vector3(0.7, 0.9, 0.7) * character_scale
	r_shape.shape = r_box
	ragdoll.add_child(r_shape)
	
	var r_vis := Node3D.new()
	r_vis.scale = Vector3.ONE * character_scale
	
	if body_mesh:
		var dup_body := body_mesh.duplicate() as MeshInstance3D
		r_vis.add_child(dup_body)
	if head_mesh:
		var dup_head := head_mesh.duplicate() as MeshInstance3D
		r_vis.add_child(dup_head)
	if eye_l_mesh:
		r_vis.add_child(eye_l_mesh.duplicate())
	if eye_r_mesh:
		r_vis.add_child(eye_r_mesh.duplicate())
	
	ragdoll.add_child(r_vis)
	p_parent.add_child(ragdoll)
	_ragdoll_nodes.append(ragdoll)
	active_ragdoll_body = ragdoll
	
	var hit_impulse := hit_direction.normalized() * randf_range(16.0, 24.0)
	hit_impulse.y = randf_range(10.0, 16.0)
	hit_impulse.x += randf_range(-6.0, 6.0)
	ragdoll.apply_central_impulse(hit_impulse)
	ragdoll.apply_torque_impulse(Vector3(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0), randf_range(-14.0, 14.0)))
	
	if cap_mesh:
		var cap_rigid := RigidBody3D.new()
		cap_rigid.position = global_position + Vector3(0.0, 1.25 * character_scale, 0.0)
		cap_rigid.mass = 0.8
		cap_rigid.collision_layer = 0
		cap_rigid.collision_mask = 1
		
		var cap_cshape := CollisionShape3D.new()
		var cap_cbox := BoxShape3D.new()
		cap_cbox.size = Vector3(0.5, 0.25, 0.5) * character_scale
		cap_cshape.shape = cap_cbox
		cap_rigid.add_child(cap_cshape)
		
		var cap_vis := Node3D.new()
		cap_vis.scale = Vector3.ONE * character_scale
		cap_vis.position = Vector3(0.0, -0.94, 0.0)
		cap_vis.add_child(cap_mesh.duplicate())
		if cap_bill_mesh:
			cap_vis.add_child(cap_bill_mesh.duplicate())
		
		cap_rigid.add_child(cap_vis)
		p_parent.add_child(cap_rigid)
		_ragdoll_nodes.append(cap_rigid)
		
		var cap_impulse := Vector3(randf_range(-5.0, 5.0), randf_range(16.0, 22.0), randf_range(-4.0, 8.0))
		cap_rigid.apply_central_impulse(cap_impulse)
		cap_rigid.apply_torque_impulse(Vector3(randf_range(-25.0, 25.0), randf_range(-15.0, 15.0), randf_range(-25.0, 25.0)))
