class_name ItemData
extends Resource

enum ItemType { COIN, SUPER_COIN, MAGNET, SHIELD }

@export_category("Basic")
@export var id: StringName = &"coin_normal"
@export var display_name: String = "골드 코인"
@export var item_type: ItemType = ItemType.COIN
@export var scene: PackedScene

@export_category("Attributes")
@export var value: int = 1
@export var duration: float = 0.0 # For buffs
@export var attraction_speed: float = 12.0
