class_name NPCData
extends Resource

@export_category("Basic")
@export var id: StringName = &"pedestrian_normal"
@export var display_name: String = "일반 보행자"
@export var scene: PackedScene

@export_category("Attributes")
@export var move_speed_min: float = 1.0
@export var move_speed_max: float = 1.5
@export var is_obstacle: bool = true
@export var collision_damage: int = 1
@export var body_color: Color = Color.WHITE

func get_random_speed() -> float:
	return randf_range(move_speed_min, move_speed_max)
