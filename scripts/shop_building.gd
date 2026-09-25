class_name ShopBuilding
extends Node3D

signal player_entering_shop(shop: ShopBuilding, player: CharacterBody3D)
signal player_entered_shop(shop: ShopBuilding)

@export var door_sound: AudioStream = null

@onready var door_area: Area3D = $EntranceDoor
@onready var camera_spot: Marker3D = $CameraTargetSpot
@onready var player_spot: Marker3D = $PlayerStopSpot
@onready var swipe_prompt: Label3D = $SwipePrompt
@onready var door_audio: AudioStreamPlayer3D = get_node_or_null("DoorAudio")

var is_active: bool = true
var player_in_zone: CharacterBody3D = null
var prompt_tween: Tween

func _ready() -> void:
	if door_area:
		door_area.body_entered.connect(_on_door_body_entered)
		door_area.body_exited.connect(_on_door_body_exited)
	_hide_prompt()

func _on_door_body_entered(body: Node3D) -> void:
	if not is_active:
		return
	if body is Player:
		player_in_zone = body
		body.current_door_target = self
		_show_prompt()

func _on_door_body_exited(body: Node3D) -> void:
	if body == player_in_zone:
		if is_instance_valid(player_in_zone) and player_in_zone.get("current_door_target") == self:
			player_in_zone.set("current_door_target", null)
		player_in_zone = null
		_hide_prompt()

## Called when player swipes left while in front of the door
func enter_shop(player: CharacterBody3D) -> void:
	if not is_active:
		return
	is_active = false
	_hide_prompt()
	if player_in_zone == player:
		player_in_zone = null
	
	player_entering_shop.emit(self, player)
	player_entered_shop.emit(self)
	
	if door_audio and door_sound:
		door_audio.stream = door_sound
		door_audio.play()
	
	InteriorManager.handle_player_entered_shop(self, player)

func _show_prompt() -> void:
	if swipe_prompt:
		swipe_prompt.visible = true
		if prompt_tween and prompt_tween.is_valid():
			prompt_tween.kill()
		prompt_tween = create_tween().set_loops()
		prompt_tween.tween_property(swipe_prompt, "position:y", 2.85, 0.45).set_trans(Tween.TRANS_SINE)
		prompt_tween.tween_property(swipe_prompt, "position:y", 2.65, 0.45).set_trans(Tween.TRANS_SINE)

func _hide_prompt() -> void:
	if swipe_prompt:
		swipe_prompt.visible = false
	if prompt_tween and prompt_tween.is_valid():
		prompt_tween.kill()

func close_shop() -> void:
	is_active = false
	_hide_prompt()
	get_tree().create_timer(3.0).timeout.connect(func(): is_active = true)
