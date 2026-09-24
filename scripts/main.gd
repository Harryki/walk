extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Camera3D
@onready var spawner: Node3D = $Spawner

# Camera offset for Crossy Road isometric view
var camera_offset: Vector3

func _ready() -> void:
	if camera and player:
		camera_offset = camera.global_position - player.global_position
	
	if spawner and player:
		spawner.setup(player)
	
	GameManager.start_game()

func _physics_process(delta: float) -> void:
	if not camera or not player:
		return
	
	# Smoothly track player along Z axis and gentle follow on X
	var target_pos := Vector3(
		camera_offset.x + player.global_position.x * 0.3,
		camera_offset.y,
		player.global_position.z + camera_offset.z
	)
	camera.global_position = camera.global_position.lerp(target_pos, delta * 8.0)
