# =============================================================================
# Transition Texture Mask (Super Mario Style Iris Wipe)
# Adapted from Roadside Games godot-guides / guide_transition_texture_mask
# =============================================================================
class_name TransitionTextureMask
extends ColorRect

signal transition_in_completed
signal transition_out_completed

@export_category("Zoom Settings")
@export var zoom_open: float = 2.5
@export var zoom_closed: float = 0.0
@export var zoom_tween_type: Tween.TransitionType = Tween.TransitionType.TRANS_CUBIC
@export var zoom_ease_type: Tween.EaseType = Tween.EaseType.EASE_IN_OUT

@export_category("Duration Settings")
@export var default_duration: float = 0.85

var _tween: Tween
var is_transitioning: bool = false

func _ready() -> void:
	z_index = 1000
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchors_preset = Control.PRESET_FULL_RECT
	visible = true
	# Initialize to fully open (screen clear)
	_set_shader_values(zoom_open, Vector2(0.5, 0.5))

func _set_shader_values(zoom_val: float, center_val: Vector2) -> void:
	if material is ShaderMaterial:
		material.set_shader_parameter("zoom", zoom_val)
		material.set_shader_parameter("center", center_val)

func _shader_value_zoom(val: float) -> void:
	if material is ShaderMaterial:
		material.set_shader_parameter("zoom", val)

func _shader_value_center(val: Vector2) -> void:
	if material is ShaderMaterial:
		material.set_shader_parameter("center", val)

## Closes iris to black onto target_center (Mario Iris Out)
func fade_in(target_center: Vector2 = Vector2(0.5, 0.5), duration: float = -1.0) -> Signal:
	if duration <= 0.0:
		duration = default_duration
	
	is_transitioning = true
	visible = true
	_set_shader_values(zoom_open, target_center)
	
	if _tween and _tween.is_valid():
		_tween.kill()
	
	_tween = create_tween().set_trans(zoom_tween_type).set_ease(Tween.EASE_IN)
	_tween.tween_method(_shader_value_zoom, zoom_open, zoom_closed, duration)
	_tween.tween_callback(func():
		is_transitioning = false
		transition_in_completed.emit()
	)
	
	return transition_in_completed

## Opens iris from black starting at target_center (Mario Iris In)
func fade_out(target_center: Vector2 = Vector2(0.5, 0.5), duration: float = -1.0) -> Signal:
	if duration <= 0.0:
		duration = default_duration
	
	is_transitioning = true
	visible = true
	_set_shader_values(zoom_closed, target_center)
	
	if _tween and _tween.is_valid():
		_tween.kill()
	
	_tween = create_tween().set_trans(zoom_tween_type).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_shader_value_zoom, zoom_closed, zoom_open, duration)
	_tween.tween_callback(func():
		is_transitioning = false
		transition_out_completed.emit()
	)
	
	return transition_out_completed

## Plays full Mario iris transition: closes -> runs midpoint callback -> opens
func play_transition(target_center: Vector2, on_midpoint: Callable, duration_in: float = 0.4, duration_out: float = 0.4) -> void:
	await fade_in(target_center, duration_in)
	if on_midpoint.is_valid():
		on_midpoint.call()
	await fade_out(target_center, duration_out)
