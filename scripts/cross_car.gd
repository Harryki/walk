class_name CrossCar
extends Area3D

@export var speed: float = 22.0
@export var direction: float = 1.0 # 1.0 = left-to-right (+X), -1.0 = right-to-left (-X)

var current_speed: float = 22.0
var must_stop: bool = false
var stop_x: float = 0.0
var is_stopped: bool = false

@onready var visuals: Node3D = $Visuals
@onready var body_mesh: MeshInstance3D = $Visuals/Body

const CAR_COLORS: Array[Color] = [
	Color(0.85, 0.2, 0.2),  # Red
	Color(0.2, 0.5, 0.85), # Blue
	Color(0.9, 0.75, 0.1), # Yellow taxi
	Color(0.2, 0.75, 0.3), # Green
	Color(0.8, 0.4, 0.1),  # Orange
	Color(0.85, 0.85, 0.9) # White
]

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_setup_visuals()

func setup(p_speed: float, p_direction: float, p_stop_x: float = 0.0) -> void:
	speed = p_speed
	current_speed = p_speed
	direction = p_direction
	stop_x = p_stop_x
	_setup_visuals()

func set_signal_stop(stop: bool) -> void:
	must_stop = stop
	if not stop:
		is_stopped = false

func _setup_visuals() -> void:
	if not is_inside_tree() or not visuals:
		return
	
	# Rotate car model to face direction of travel along X axis
	# Car front is in -Z locally, so moving +X requires rot.y = -PI/2
	if direction > 0.0:
		visuals.rotation.y = -PI / 2.0
	else:
		visuals.rotation.y = PI / 2.0
	
	if body_mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = CAR_COLORS.pick_random()
		mat.roughness = 0.4
		body_mesh.material_override = mat

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	if must_stop and not is_stopped:
		# Distance to stop line before crosswalk
		var dist_to_stop: float = (stop_x - global_position.x) if direction > 0.0 else (global_position.x - stop_x)
		
		# If approaching stop line
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
			# Car was already past stop line inside intersection, let it clear
			current_speed = move_toward(current_speed, speed, 25.0 * delta)
	elif not must_stop:
		is_stopped = false
		current_speed = move_toward(current_speed, speed, 30.0 * delta)
	
	global_position.x += direction * current_speed * delta
	
	# Despawn when far out of view
	if absf(global_position.x) > 38.0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player") and not (body is CharacterBody3D and body.name == "Player"):
		return
	
	# Check if player is sliding (invincible)
	var is_invincible: bool = body.get(&"is_invincible") == true or body.get(&"is_sliding") == true
	if is_invincible:
		return # Slipped through safely with slide dash!
	
	# If car is safely stopped at the red line, it doesn't kill pedestrians/players
	if is_stopped or current_speed < 2.5:
		return
	
	# Instant lethal hit!
	if body.has_method(&"play_oof_sound"):
		body.play_oof_sound()
	if GameManager:
		GameManager.take_damage(999)
		if GameManager.current_state != GameManager.GameState.GAME_OVER:
			GameManager.trigger_game_over("교통사고! 신호를 위반하여 차에 치였습니다.")
