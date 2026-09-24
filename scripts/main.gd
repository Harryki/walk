class_name Main
extends Node3D

@onready var player: Player = $Player
@onready var camera: Camera3D = $Camera3D
@onready var spawner: Spawner = $Spawner

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
	
	# Frame-rate independent smooth tracking
	var target_pos := Vector3(
		camera_offset.x + player.global_position.x * 0.3,
		camera_offset.y,
		player.global_position.z + camera_offset.z
	)
	var weight: float = 1.0 - exp(-8.0 * delta)
	camera.global_position = camera.global_position.lerp(target_pos, weight)
