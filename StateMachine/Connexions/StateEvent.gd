extends Resource
class_name StateEvent

@export var conditions : Array[StateCondition]
@export var trigger : String
@export var emitter_path : NodePath


func are_all_conditions_verified(from_state: State) -> bool:
	for condition in conditions:
		if !condition.is_verified(from_state):
			return false
	return true


func add_condition(cond_expression: String, target_path: NodePath) -> void:
	var cond = StateCondition.new()
	cond.condition = cond_expression
	cond.target_path = target_path
	conditions.append(cond)



func find_condition_index(str_condition : String, target_path: NodePath) -> int:
	for i in range(conditions.size()):
		var cond = conditions[i]
		if cond.condition == str_condition && cond.target_path == target_path:
			return i
	return -1
