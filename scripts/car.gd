class_name Car
extends Node3D

@export var speed: float = 8.0
@export var direction: float = -1.0 # -1 means moving opposite to player, 1 means with player

static var _car_materials: Array[StandardMaterial3D] = []

const CAR_COLORS: Array[Color] = [
	Color(0.85, 0.2, 0.2), # Red sports car
	Color(0.2, 0.45, 0.85), # Blue sedan
	Color(0.95, 0.85, 0.2), # Yellow taxi
	Color(0.9, 0.9, 0.9),   # White van
	Color(0.2, 0.7, 0.4)    # Green compact
]

@onready var body_mesh: MeshInstance3D = $Visuals/Body

func _ready() -> void:
	if _car_materials.is_empty():
		for col in CAR_COLORS:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = col
			mat.roughness = 0.4
			_car_materials.append(mat)
	
	if body_mesh:
		body_mesh.material_override = _car_materials.pick_random()

func _process(delta: float) -> void:
	global_position.z += direction * speed * delta
