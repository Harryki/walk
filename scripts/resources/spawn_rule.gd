class_name SpawnRule
extends Resource

@export var data: Resource # NPCData or ItemData
@export_range(1, 100, 1) var weight: int = 10
@export var min_distance: float = 0.0
@export var max_distance: float = 9999.0
