extends Node3D

@export var speed: float = 8.0
@export var direction: float = -1.0 # -1 means moving opposite to player, 1 means with player

const CAR_COLORS: Array[Color] = [
	Color(0.85, 0.2, 0.2), # Red sports car
	Color(0.2, 0.45, 0.85), # Blue sedan
	Color(0.95, 0.85, 0.2), # Yellow taxi
	Color(0.9, 0.9, 0.9),   # White van
	Color(0.2, 0.7, 0.4)    # Green compact
]

@onready var body_mesh: MeshInstance3D = $Visuals/Body

func _ready() -> void:
	if body_mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = CAR_COLORS.pick_random()
		mat.roughness = 0.4
		body_mesh.material_override = mat

func _process(delta: float) -> void:
	global_position.z += direction * speed * delta
