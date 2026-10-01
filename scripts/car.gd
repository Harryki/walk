class_name Car
extends Area3D

enum DriveMode {
	CROSS_TRAFFIC, # Moves along X across crosswalks, stops on signals, lethal collision
	AMBIENT        # Moves along Z on background highway lanes, harmless ambience
}

@export var drive_mode: DriveMode = DriveMode.CROSS_TRAFFIC
@export var speed: float = 22.0
@export var direction: float = 1.0 # CROSS: 1.0=+X, -1.0=-X | AMBIENT: 1.0=+Z, -1.0=-Z

var current_speed: float = 22.0
var must_stop: bool = false
var stop_x: float = 0.0
var is_stopped: bool = false

@onready var visuals: Node3D = $Visuals
@onready var body_mesh: MeshInstance3D = get_node_or_null("Visuals/Body") as MeshInstance3D
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D

static var _car_materials: Array[StandardMaterial3D] = []

const CAR_COLORS: Array[Color] = [
	Color(0.85, 0.2, 0.2),  # Red sports car
	Color(0.2, 0.5, 0.85), # Blue sedan
	Color(0.95, 0.8, 0.15), # Yellow taxi
	Color(0.2, 0.75, 0.35), # Green compact
	Color(0.85, 0.45, 0.15),# Orange coupe
	Color(0.9, 0.9, 0.95)   # White van
]

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	if drive_mode == DriveMode.AMBIENT:
		monitoring = false
		monitorable = false
		if collision_shape:
			collision_shape.set_deferred(&"disabled", true)
	
	_setup_visuals()

func setup(p_speed: float, p_direction: float, p_stop_x: float = 0.0) -> void:
	drive_mode = DriveMode.CROSS_TRAFFIC
	speed = p_speed
	current_speed = p_speed
	direction = p_direction
	stop_x = p_stop_x
	monitoring = true
	monitorable = true
	if collision_shape:
		collision_shape.set_deferred(&"disabled", false)
	_setup_visuals()

func setup_ambient(p_speed: float, p_direction: float) -> void:
	drive_mode = DriveMode.AMBIENT
	speed = p_speed
	current_speed = p_speed
	direction = p_direction
	monitoring = false
	monitorable = false
	if collision_shape:
		collision_shape.set_deferred(&"disabled", true)
	_setup_visuals()

func set_signal_stop(stop: bool) -> void:
	must_stop = stop
	if not stop:
		is_stopped = false

func _setup_visuals() -> void:
	if not is_inside_tree() or not visuals:
		return
	
	if drive_mode == DriveMode.CROSS_TRAFFIC:
		# Rotate car to face along X axis (-Z local faces direction of motion)
		visuals.rotation.y = -PI / 2.0 if direction > 0.0 else PI / 2.0
	else:
		# Ambient background cars move along Z (+Z = south, -Z = north)
		visuals.rotation.y = PI if direction > 0.0 else 0.0
	
	# Cached material pooling to prevent redundant shader allocations
	if _car_materials.is_empty():
		for col in CAR_COLORS:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = col
			mat.roughness = 0.4
			_car_materials.append(mat)
	
	if body_mesh and not _car_materials.is_empty():
		body_mesh.material_override = _car_materials.pick_random()

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	if drive_mode == DriveMode.CROSS_TRAFFIC:
		_process_cross_traffic(delta)
	else:
		_process_ambient(delta)

func _process_cross_traffic(delta: float) -> void:
	if must_stop and not is_stopped:
		# Distance to stop line before crosswalk
		var dist_to_stop: float = (stop_x - global_position.x) if direction > 0.0 else (global_position.x - stop_x)
		
		if dist_to_stop > 0.0:
			var target_spd := clampf(dist_to_stop * 6.5, 1.5, speed)
			current_speed = move_toward(current_speed, target_spd, 40.0 * delta)
			if dist_to_stop <= 0.2:
				current_speed = 0.0
				global_position.x = stop_x
				is_stopped = true
		elif dist_to_stop > -1.0 and current_speed <= 2.0:
			current_speed = 0.0
			global_position.x = stop_x
			is_stopped = true
		else:
			# Past stop line in intersection: clear rapidly
			current_speed = move_toward(current_speed, speed, 25.0 * delta)
	elif not must_stop:
		is_stopped = false
		current_speed = move_toward(current_speed, speed, 30.0 * delta)
	
	global_position.x += direction * current_speed * delta
	
	if absf(global_position.x) > 38.0:
		queue_free()

func _process_ambient(delta: float) -> void:
	global_position.z += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if drive_mode != DriveMode.CROSS_TRAFFIC:
		return
	if not body.is_in_group(&"player") and not (body is CharacterBody3D and body.name == "Player"):
		return
	
	# Check if player is invincible
	var is_invincible: bool = body.get(&"is_invincible") == true
	if is_invincible:
		return
	
	# Stopped cars do not inflict lethal damage
	if is_stopped or current_speed < 2.5:
		return
	
	# Instant lethal hit!
	var car_hit_dir := Vector3(direction * 1.5, 0.8, 0.2).normalized()
	if body.has_method(&"die"):
		body.die("교통사고! 신호를 위반하여 차에 치였습니다.", car_hit_dir)
	else:
		if body.has_method(&"play_oof_sound"):
			body.play_oof_sound()
		if GameManager:
			GameManager.take_damage(999)
			if GameManager.current_state != GameManager.GameState.GAME_OVER:
				GameManager.trigger_game_over("교통사고! 신호를 위반하여 차에 치였습니다.")

func _on_area_entered(area: Area3D) -> void:
	if drive_mode != DriveMode.CROSS_TRAFFIC:
		return
	if is_stopped or current_speed < 2.5:
		return
	if area is Pedestrian and not area.is_dead:
		if area.has_method(&"knockback_and_destroy"):
			area.knockback_and_destroy()
		elif area.has_method(&"destroy_pedestrian"):
			area.destroy_pedestrian()
