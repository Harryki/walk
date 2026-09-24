class_name ChunkData
extends Resource

enum ChunkKind { STRAIGHT, INTERSECTION, SHOP, PARK }

@export var id: StringName = &"chunk_straight"
@export var chunk_scene: PackedScene
@export var chunk_kind: ChunkKind = ChunkKind.STRAIGHT
@export var length_meters: float = 25.0
@export var weight: int = 10
@export var has_enterable_building: bool = false
