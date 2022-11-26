extends Resource
class_name StateCondition

@export var condition : String = ""
@export var target_path : NodePath


func is_verified(from_state: State) -> bool:
	var target = from_state.get_node(target_path)
	
	var expression = Expression.new()
	var error = expression.parse(condition)
	
	if error != OK:
		push_error("the expression couldn't be parsed: %s | condition: %s" % [expression.get_error_text(), condition])
		return false
	
	var result = expression.execute([], target)
	
	if expression.has_execute_failed():
		push_error("Condition execution failed, check if its expression is valid | condition: %s" % condition)
		return false
		
	elif not result is bool:
		push_error("Condition expression didn't retruned a bool value, condition aborted (retruned false)| condition: %s" % condition)
		return false
	
	else:
		return result

