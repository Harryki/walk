class_name SpawnTable
extends Resource

@export var table_name: String = "Default Spawns"
@export var rules: Array[Resource] = []

func pick_random(current_distance: float) -> Resource:
	var valid_rules: Array[Resource] = []
	var total_weight: int = 0
	
	for rule in rules:
		if not is_instance_valid(rule):
			continue
		var data = rule.get(&"data")
		if not is_instance_valid(data):
			continue
		
		var min_d: float = rule.get(&"min_distance") if rule.get(&"min_distance") != null else 0.0
		var max_d: float = rule.get(&"max_distance") if rule.get(&"max_distance") != null else 9999.0
		var weight: int = rule.get(&"weight") if rule.get(&"weight") != null else 10
		
		if current_distance >= min_d and current_distance <= max_d:
			valid_rules.append(rule)
			total_weight += weight
	
	if total_weight <= 0 or valid_rules.is_empty():
		return null
	
	var roll := randi_range(1, total_weight)
	var accumulated := 0
	for rule in valid_rules:
		var w: int = rule.get(&"weight") if rule.get(&"weight") != null else 10
		accumulated += w
		if roll <= accumulated:
			return rule.get(&"data")
	
	return valid_rules.back().get(&"data")
