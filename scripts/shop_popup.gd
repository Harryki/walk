class_name ShopPopup
extends Control

@onready var coins_label: Label = %CoinsLabel
@onready var heal_btn: Button = %HealBtn
@onready var stamina_btn: Button = %StaminaBtn
@onready var slide_reset_btn: Button = %SlideResetBtn
@onready var exit_btn: Button = %ExitBtn

const COST_HEAL: int = 30
const COST_STAMINA: int = 20
const COST_SLIDE_RESET: int = 40

func _ready() -> void:
	visible = false
	InteriorManager.shop_opened.connect(_on_shop_opened)
	InteriorManager.shop_closed.connect(_on_shop_closed)
	
	heal_btn.pressed.connect(_on_heal_pressed)
	stamina_btn.pressed.connect(_on_stamina_pressed)
	slide_reset_btn.pressed.connect(_on_slide_reset_pressed)
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
	coins_label.text = "보유 코인: %d 🪙" % SaveManager.coins
	
	# Heal button: only if player HP < MAX_HP
	var can_heal: bool = (GameManager.current_hp < GameManager.MAX_HP) and (SaveManager.coins >= COST_HEAL)
	heal_btn.disabled = not can_heal
	heal_btn.text = "❤️ 체력 회복 (+1 HP) [%d 코인]" % COST_HEAL
	
	# Stamina refill button
	var can_stamina: bool = (SaveManager.coins >= COST_STAMINA)
	stamina_btn.disabled = not can_stamina
	stamina_btn.text = "⚡ 스태미너 완충 (100%%) [%d 코인]" % COST_STAMINA
	
	# Slide reset
	var can_slide: bool = SaveManager.is_slide_unlocked() and (SaveManager.coins >= COST_SLIDE_RESET)
	slide_reset_btn.disabled = not can_slide
	slide_reset_btn.text = "💨 슬라이드 쿨타임 초기화 [%d 코인]" % COST_SLIDE_RESET

func _on_heal_pressed() -> void:
	if SaveManager.coins >= COST_HEAL and GameManager.current_hp < GameManager.MAX_HP:
		SaveManager.coins -= COST_HEAL
		SaveManager.save_data()
		GameManager.current_hp = mini(GameManager.current_hp + 1, GameManager.MAX_HP)
		GameManager.hp_updated.emit(GameManager.current_hp)
		_update_ui()

func _on_stamina_pressed() -> void:
	if SaveManager.coins >= COST_STAMINA:
		SaveManager.coins -= COST_STAMINA
		SaveManager.save_data()
		var player: Player = InteriorManager.current_player
		if player:
			player.current_stamina = player.max_stamina
			player.is_exhausted = false
			player._emit_stamina()
		_update_ui()

func _on_slide_reset_pressed() -> void:
	if SaveManager.coins >= COST_SLIDE_RESET:
		SaveManager.coins -= COST_SLIDE_RESET
		SaveManager.save_data()
		var player: Player = InteriorManager.current_player
		if player:
			player.slide_cooldown_timer = 0.0
			GameManager.slide_cooldown_updated.emit(0.0, player.SLIDE_COOLDOWN)
		_update_ui()

func _on_exit_pressed() -> void:
	InteriorManager.exit_shop()
