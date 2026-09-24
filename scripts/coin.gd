class_name Coin
extends Area3D

var is_collected: bool = false
var float_time: float = 0.0
const ROTATION_SPEED: float = 3.5

@onready var visual_root: Node3D = $Visuals

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return
	
	# Rotation and gentle float
	if visual_root:
		visual_root.rotate_y(ROTATION_SPEED * delta)
		float_time += delta * 4.0
		visual_root.position.y = sin(float_time) * 0.1

func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return
	
	if body is Player:
		collect()

func collect() -> void:
	is_collected = true
	set_deferred(&"monitoring", false)
	set_deferred(&"monitorable", false)
	
	GameManager.collect_coin(10)
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y + 1.2, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual_root, "scale", Vector3(1.5, 1.5, 1.5), 0.15)
	tween.chain().tween_property(visual_root, "scale", Vector3.ZERO, 0.1)
	tween.chain().tween_callback(queue_free)
