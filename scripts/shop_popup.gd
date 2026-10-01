class_name ShopPopup
extends Control

@onready var coins_label: Label = %CoinsLabel
@onready var heal_btn: Button = %HealBtn
@onready var exit_btn: Button = %ExitBtn

const COST_HEAL: int = 30

func _ready() -> void:
	visible = false
	InteriorManager.shop_opened.connect(_on_shop_opened)
	InteriorManager.shop_closed.connect(_on_shop_closed)
	
	heal_btn.pressed.connect(_on_heal_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)

func _on_shop_opened(_shop: Node3D) -> void:
	if InteriorManager.shop_interior != null:
		visible = false
		return
	visible = true
	_update_ui()

func _on_shop_closed() -> void:
	visible = false

func _update_ui() -> void:
	coins_label.text = "보유 코인: %d" % SaveManager.coins
	
	# Heal button: only if player HP < MAX_HP
	var can_heal: bool = (GameManager.current_hp < GameManager.MAX_HP) and (SaveManager.coins >= COST_HEAL)
	heal_btn.disabled = not can_heal
	heal_btn.text = "체력 회복 (+1 HP) [%d 코인]" % COST_HEAL

func _on_heal_pressed() -> void:
	if SaveManager.coins >= COST_HEAL and GameManager.current_hp < GameManager.MAX_HP:
		SaveManager.coins -= COST_HEAL
		SaveManager.save_data()
		GameManager.current_hp = mini(GameManager.current_hp + 1, GameManager.MAX_HP)
		GameManager.hp_updated.emit(GameManager.current_hp)
		_update_ui()

func _on_exit_pressed() -> void:
	InteriorManager.exit_shop()
