class_name TrafficLight
extends Node3D

signal state_changed(new_state: int)

enum LightState {
	GREEN,   # Safe to cross (walk icon)
	WARNING, # Green blinking (hurry up!)
	RED      # Danger! Stop! Cross-traffic cars rushing through
}

@export var green_duration: float = 4.5
@export var warning_duration: float = 1.8
@export var red_duration: float = 4.0

var current_state: LightState = LightState.GREEN
var state_timer: float = 0.0
var blink_timer: float = 0.0
var is_blink_on: bool = true

@onready var red_light_mesh: MeshInstance3D = $Housing/RedLight
@onready var green_light_mesh: MeshInstance3D = $Housing/GreenLight
@onready var countdown_label: Label3D = $Housing/CountdownLabel

# Materials for lights
var mat_red_active: StandardMaterial3D
var mat_red_dim: StandardMaterial3D
var mat_green_active: StandardMaterial3D
var mat_green_dim: StandardMaterial3D

func _ready() -> void:
	_init_materials()
	_set_state(LightState.GREEN)

func _init_materials() -> void:
	mat_red_active = StandardMaterial3D.new()
	mat_red_active.albedo_color = Color(1.0, 0.15, 0.15)
	mat_red_active.emission_enabled = true
	mat_red_active.emission = Color(1.0, 0.1, 0.1)
	mat_red_active.emission_energy_multiplier = 2.5
	
	mat_red_dim = StandardMaterial3D.new()
	mat_red_dim.albedo_color = Color(0.25, 0.05, 0.05)
	mat_red_dim.roughness = 0.8
	
	mat_green_active = StandardMaterial3D.new()
	mat_green_active.albedo_color = Color(0.15, 1.0, 0.35)
	mat_green_active.emission_enabled = true
	mat_green_active.emission = Color(0.1, 0.9, 0.25)
	mat_green_active.emission_energy_multiplier = 2.5
	
	mat_green_dim = StandardMaterial3D.new()
	mat_green_dim.albedo_color = Color(0.05, 0.25, 0.1)
	mat_green_dim.roughness = 0.8

func _process(delta: float) -> void:
	state_timer -= delta
	
	# Handle blinking in WARNING state
	if current_state == LightState.WARNING:
		blink_timer += delta * 6.0 # 3 Hz blink
		var should_be_on: bool = int(blink_timer) % 2 == 0
		if should_be_on != is_blink_on:
			is_blink_on = should_be_on
			if green_light_mesh:
				green_light_mesh.material_override = mat_green_active if is_blink_on else mat_green_dim
	
	# Update countdown label
	if countdown_label:
		countdown_label.text = "%d" % int(ceilf(maxf(state_timer, 0.0)))
		match current_state:
			LightState.GREEN:
				countdown_label.modulate = Color(0.2, 1.0, 0.4)
			LightState.WARNING:
				countdown_label.modulate = Color(1.0, 0.85, 0.2)
			LightState.RED:
				countdown_label.modulate = Color(1.0, 0.25, 0.25)
	
	# State transition
	if state_timer <= 0.0:
		match current_state:
			LightState.GREEN:
				_set_state(LightState.WARNING)
			LightState.WARNING:
				_set_state(LightState.RED)
			LightState.RED:
				_set_state(LightState.GREEN)

func _set_state(new_state: LightState) -> void:
	current_state = new_state
	match current_state:
		LightState.GREEN:
			state_timer = green_duration
			if red_light_mesh:
				red_light_mesh.material_override = mat_red_dim
			if green_light_mesh:
				green_light_mesh.material_override = mat_green_active
		LightState.WARNING:
			state_timer = warning_duration
			blink_timer = 0.0
			is_blink_on = true
			if red_light_mesh:
				red_light_mesh.material_override = mat_red_dim
			if green_light_mesh:
				green_light_mesh.material_override = mat_green_active
		LightState.RED:
			state_timer = red_duration
			if red_light_mesh:
				red_light_mesh.material_override = mat_red_active
			if green_light_mesh:
				green_light_mesh.material_override = mat_green_dim
	
	state_changed.emit(current_state)

func is_safe_to_cross() -> bool:
	return current_state == LightState.GREEN or current_state == LightState.WARNING

func is_red() -> bool:
	return current_state == LightState.RED
