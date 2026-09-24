class_name Pedestrian
extends Area3D

const SPEED: float = 3.0
var current_speed: float = SPEED
var is_dead: bool = false
var bob_time: float = 0.0

@onready var visual_root: Node3D = $Visuals
@onready var body_mesh: MeshInstance3D = $Visuals/Body

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
	body_entered.connect(_on_body_entered)
	if not body_mesh.material_override:
		_apply_cached_material()

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
	if is_dead:
		return
	
	# Synchronized with physics tick
	global_position.z -= current_speed * delta
	
	# Walking bob
	bob_time += delta * 8.0
	if visual_root:
		visual_root.position.y = absf(sin(bob_time)) * 0.12

func _on_body_entered(body: Node3D) -> void:
	if is_dead:
		return
	
	if body is Player:
		if body.is_sliding:
			knockback_and_destroy()
		else:
			body.hit_by_obstacle()
			destroy_pedestrian()

func knockback_and_destroy() -> void:
	is_dead = true
	set_deferred(&"monitoring", false)
	set_deferred(&"monitorable", false)
	set_physics_process(false)
	
	# Dramatic launch upwards and backwards
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y + 2.5, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:z", global_position.z + 3.0, 0.4)
	tween.tween_property(visual_root, "rotation:x", 10.0, 0.4)
	tween.tween_property(visual_root, "scale", Vector3.ZERO, 0.4)
	tween.chain().tween_callback(queue_free)

func destroy_pedestrian() -> void:
	is_dead = true
	set_deferred(&"monitoring", false)
	set_deferred(&"monitorable", false)
	set_physics_process(false)
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual_root, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
