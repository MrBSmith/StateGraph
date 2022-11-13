extends Resource
class_name StateEvent

@export var conditions : Array[StateCondition]
@export var trigger : Signal

func _init(_trigger: Signal, _conditions: Array[StateCondition]) -> void:
	trigger = _trigger
	conditions = _conditions


func are_all_conditions_verified(from_state: State) -> bool:
	for condition in conditions:
		if !condition.is_verified(from_state):
			return false
	return true


func add_condition(cond_expression: String, target_path: NodePath) -> void:
	var cond = StateCondition.new(cond_expression, target_path)
	conditions.append(cond)



func find_condition_index(str_condition : String, target_path: NodePath) -> int:
	for i in range(conditions.size()):
		var cond = conditions[i]
		if cond.condition == str_condition && cond.target_path == target_path:
			return i
	return -1
