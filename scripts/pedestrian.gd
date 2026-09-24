extends Area3D

const SPEED: float = 1.0
var is_dead: bool = false
var bob_time: float = 0.0

@onready var visual_root: Node3D = $Visuals
@onready var body_mesh: MeshInstance3D = $Visuals/Body

# Random palette for pedestrians
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
	_randomize_appearance()

func _randomize_appearance() -> void:
	if body_mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = SHIRT_COLORS.pick_random()
		mat.roughness = 0.8
		body_mesh.material_override = mat

func _process(delta: float) -> void:
	if is_dead:
		return
	
	# Move towards -Z (counter to player)
	global_position.z -= SPEED * delta
	
	# Walking bob
	bob_time += delta * 8.0
	if visual_root:
		visual_root.position.y = absf(sin(bob_time)) * 0.12

func _on_body_entered(body: Node3D) -> void:
	if is_dead:
		return
	
	if body.has_method("hit_by_obstacle"):
		if body.is_sliding:
			# Player slid through obstacle!
			knockback_and_destroy()
		else:
			body.hit_by_obstacle()
			destroy_pedestrian()

func knockback_and_destroy() -> void:
	is_dead = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Dramatic launch upwards and backwards
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y + 2.5, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:z", global_position.z + 3.0, 0.4)
	tween.tween_property(visual_root, "rotation:x", 10.0, 0.4)
	tween.tween_property(visual_root, "scale", Vector3.ZERO, 0.4)
	tween.chain().tween_callback(queue_free)

func destroy_pedestrian() -> void:
	is_dead = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual_root, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
