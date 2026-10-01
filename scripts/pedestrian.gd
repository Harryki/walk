@tool
class_name Pedestrian
extends Area3D

@export_range(0.5, 2.5, 0.05) var character_scale: float = 1.0:
	set(val):
		character_scale = val
		_apply_character_scale()

const SPEED: float = 3.0
var current_speed: float = SPEED
var is_dead: bool = false
var is_waiting: bool = false
var waiting_traffic_light: TrafficLight = null
var waiting_stop_z: float = 0.0
var bob_time: float = 0.0

# Near Miss tracking
var tracked_player: Player = null
var has_near_missed: bool = false

@onready var visual_root: Node3D = $Visuals
@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var near_miss_area: Area3D = get_node_or_null("NearMissArea")
@onready var near_miss_collision: CollisionShape3D = get_node_or_null("NearMissArea/NearMissCollisionShape")

const THUD_SOUND: AudioStream = preload("res://assets/audio/sfx/thud.mp3")

func start_waiting(light: TrafficLight) -> void:
	if is_dead or is_waiting:
		return
	is_waiting = true
	waiting_traffic_light = light
	waiting_stop_z = global_position.z

func stop_waiting() -> void:
	is_waiting = false
	waiting_traffic_light = null

func apply_data(data: Resource) -> void:
	if not data:
		return
	if data.has_method(&"get_random_speed"):
		current_speed = data.get_random_speed()
	var col = data.get(&"body_color")
	if col != null and col != Color.WHITE and body_mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = 0.8
		body_mesh.material_override = mat

# Static material cache to prevent redundant material creation and batch draw calls
static var _cached_materials: Array[StandardMaterial3D] = []

const SHIRT_COLORS: Array[Color] = [
	Color(0.2, 0.5, 0.9),  # Blue
	Color(0.9, 0.3, 0.3),  # Red
	Color(0.2, 0.8, 0.4),  # Green
	Color(0.95, 0.65, 0.2), # Orange
	Color(0.7, 0.4, 0.9),  # Purple
	Color(0.3, 0.3, 0.35)  # Charcoal suit
]

func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_character_scale()
		return
	
	body_entered.connect(_on_body_entered)
	if near_miss_area:
		near_miss_area.body_entered.connect(_on_near_miss_body_entered)
		near_miss_area.body_exited.connect(_on_near_miss_body_exited)
		
	if not body_mesh.material_override:
		_apply_cached_material()
	_apply_character_scale()

func _apply_character_scale() -> void:
	var v := visual_root if visual_root else (get_node_or_null("Visuals") as Node3D)
	if v:
		v.scale = Vector3.ONE * character_scale
	var col := collision_shape if collision_shape else (get_node_or_null("CollisionShape3D") as CollisionShape3D)
	if col and col.shape is BoxShape3D:
		col.shape.size = Vector3(0.65, 1.0, 0.65) * character_scale
		col.position.y = 0.5 * character_scale
	var nm_col := near_miss_collision if near_miss_collision else (get_node_or_null("NearMissArea/NearMissCollisionShape") as CollisionShape3D)
	if nm_col and nm_col.shape is BoxShape3D:
		nm_col.shape.size = Vector3(2.4, 1.5, 1.2) * character_scale
		nm_col.position.y = 0.5 * character_scale

func _apply_cached_material() -> void:
	if _cached_materials.is_empty():
		for col in SHIRT_COLORS:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = col
			mat.roughness = 0.8
			_cached_materials.append(mat)
	
	if body_mesh and not _cached_materials.is_empty():
		body_mesh.material_override = _cached_materials.pick_random()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_dead:
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	# Stop at crosswalk when traffic light is RED
	if is_waiting:
		if waiting_traffic_light and waiting_traffic_light.is_safe_to_cross():
			stop_waiting()
		else:
			global_position.z = waiting_stop_z
			if visual_root:
				visual_root.position.y = move_toward(visual_root.position.y, 0.0, delta * 2.0)
			return
	
	# Synchronized with physics tick
	global_position.z -= current_speed * delta
	
	# Near miss check: If player is within near miss zone and safely passes our Z position without direct hit
	if tracked_player and is_instance_valid(tracked_player) and not is_dead and not has_near_missed:
		if tracked_player.global_position.z >= global_position.z:
			has_near_missed = true
			tracked_player.trigger_near_miss(self)
			tracked_player = null
	
	# Walking bob
	bob_time += delta * 8.0
	if visual_root:
		visual_root.position.y = absf(sin(bob_time)) * 0.12

func _on_near_miss_body_entered(body: Node3D) -> void:
	if is_dead or has_near_missed:
		return
	if body is Player:
		tracked_player = body

func _on_near_miss_body_exited(body: Node3D) -> void:
	if body == tracked_player:
		tracked_player = null

func _on_body_entered(body: Node3D) -> void:
	if is_dead:
		return
	
	if body is Player:
		# Direct hit invalidates any near miss
		has_near_missed = true
		tracked_player = null
		body.hit_by_obstacle()
		destroy_pedestrian()

func destroy_pedestrian() -> void:
	if is_dead:
		return
	is_dead = true
	_play_thud_sound()
	set_deferred(&"monitoring", false)
	set_deferred(&"monitorable", false)
	if near_miss_area:
		near_miss_area.set_deferred(&"monitoring", false)
		near_miss_area.set_deferred(&"monitorable", false)
	set_physics_process(false)
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual_root, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)

func knockback_and_destroy() -> void:
	if is_dead:
		return
	is_dead = true
	_play_thud_sound()
	set_deferred(&"monitoring", false)
	set_deferred(&"monitorable", false)
	if near_miss_area:
		near_miss_area.set_deferred(&"monitoring", false)
		near_miss_area.set_deferred(&"monitorable", false)
	set_physics_process(false)
	
	# Launch upwards and backwards when hit by speeding cross car
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y + 2.5, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:z", global_position.z + 3.0, 0.4)
	if visual_root:
		tween.tween_property(visual_root, "rotation:x", 10.0, 0.4)
		tween.tween_property(visual_root, "scale", Vector3.ZERO, 0.4)
	tween.chain().tween_callback(queue_free)

func _play_thud_sound() -> void:
	if Engine.is_editor_hint():
		return
	if AudioManager:
		AudioManager.play_spatial_sfx(THUD_SOUND, global_position, &"SFX", randf_range(0.94, 1.06))
