class_name EnergyDrink
extends Area3D

var is_collected: bool = false
var float_time: float = 0.0
const ROTATION_SPEED: float = 3.5

@onready var visual_root: Node3D = $Visuals
@onready var halo_mesh: MeshInstance3D = get_node_or_null("Visuals/EnergyHalo")

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return
	
	# Rotation and gentle bobbing float
	if visual_root:
		visual_root.rotate_y(ROTATION_SPEED * delta)
		float_time += delta * 3.5
		visual_root.position.y = sin(float_time) * 0.08
	if halo_mesh:
		halo_mesh.scale = Vector3.ONE * (1.0 + sin(float_time * 2.0) * 0.12)

func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return
	
	if body is Player:
		collect(body)

func apply_data(_data: Resource) -> void:
	pass

func collect(player: Player) -> void:
	is_collected = true
	set_deferred(&"monitoring", false)
	set_deferred(&"monitorable", false)
	
	# Instantly fill stamina to 100% and clear exhaustion
	if player and player.has_method(&"restore_full_stamina"):
		player.restore_full_stamina()
	
	# Show comic pop on HUD
	var hud := get_tree().get_first_node_in_group(&"hud")
	if not hud:
		hud = get_viewport().get_node_or_null("Main/UI/HUD")
	if hud and hud.has_method(&"show_boost_comic_popup"):
		hud.show_boost_comic_popup("⚡ FULL STAMINA! ⚡")
	
	# Ascending pop tween
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y + 1.3, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if visual_root:
		tween.tween_property(visual_root, "scale", Vector3(1.6, 1.6, 1.6), 0.15)
		tween.chain().tween_property(visual_root, "scale", Vector3.ZERO, 0.1)
	tween.chain().tween_callback(queue_free)
